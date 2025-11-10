#!/usr/bin/env python3
"""
Utility script to exercise the API Gateway usage plan throttling limits.

The script sends configurable bursts and sustained traffic against the
/ingest endpoint while reporting latency, throttling responses (HTTP 429),
and other errors.  It is intended to validate the burst and steady-state
limits defined in terraform/modules/api_gateway/key.tf.
"""

from __future__ import annotations

import argparse
import concurrent.futures
import json
import statistics
import time
from dataclasses import dataclass
from typing import Dict, Iterable, List, Optional

try:
    import requests  # type: ignore
except ImportError:  # pragma: no cover - fall back to stdlib
    requests = None  # noqa: N816 - mirror import name for readability
    import urllib.error
    import urllib.request


@dataclass
class ResponseRecord:
    status: Optional[int]
    latency: float
    ok: bool
    body: Optional[str] = None
    error: Optional[str] = None


class HttpClient:
    """Minimal HTTP client that uses requests when available, otherwise urllib."""

    def __init__(self, timeout: float) -> None:
        self.timeout = timeout

    def request(
        self,
        method: str,
        url: str,
        headers: Optional[Dict[str, str]] = None,
        body: Optional[str] = None,
    ) -> ResponseRecord:
        start = time.perf_counter()
        try:
            if requests:  # requests path
                response = requests.request(
                    method,
                    url,
                    headers=headers,
                    data=body,
                    timeout=self.timeout,
                )
                latency = time.perf_counter() - start
                return ResponseRecord(
                    status=response.status_code,
                    latency=latency,
                    ok=response.ok,
                    body=response.text,
                )

            # urllib fallback
            data_bytes = body.encode("utf-8") if body is not None else None
            request = urllib.request.Request(  # type: ignore[name-defined]
                url=url,
                data=data_bytes,
                headers=headers or {},
                method=method,
            )
            with urllib.request.urlopen(  # type: ignore[name-defined]
                request, timeout=self.timeout
            ) as resp:
                response_body = resp.read().decode("utf-8")
                latency = time.perf_counter() - start
                return ResponseRecord(
                    status=resp.status,
                    latency=latency,
                    ok=200 <= resp.status < 300,
                    body=response_body,
                )
        except Exception as exc:  # pragma: no cover - network failures
            latency = time.perf_counter() - start
            status = getattr(exc, "code", None)
            return ResponseRecord(
                status=status,
                latency=latency,
                ok=False,
                error=str(exc),
            )


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Exercise API Gateway usage plan throttling limits."
    )
    parser.add_argument(
        "--base-url",
        required=True,
        help="Invoke URL that already includes the stage name, e.g. "
        "https://abc123.execute-api.us-east-1.amazonaws.com/prod",
    )
    parser.add_argument(
        "--api-key",
        required=True,
        help="API key value attached to the usage plan.",
    )
    parser.add_argument(
        "--health-path",
        default="prod/health",
        help="Relative path for the health check endpoint.",
    )
    parser.add_argument(
        "--ingest-path",
        default="prod/ingest",
        help="Relative path for the ingest endpoint that requires the key.",
    )
    parser.add_argument(
        "--payload",
        default=json.dumps(
            {"device_id": "m1", "temperature_c": 21.5, "timestamp": "auto"}
        ),
        help="JSON payload to post to the ingest endpoint.",
    )
    parser.add_argument(
        "--burst-requests",
        type=int,
        default=10,
        help="Number of requests to fire as a burst (expect > burst_limit for 429s).",
    )
    parser.add_argument(
        "--burst-concurrency",
        type=int,
        default=5,
        help="Concurrent workers for the burst test.",
    )
    parser.add_argument(
        "--sustained-requests",
        type=int,
        default=20,
        help="Number of requests for the sustained test.",
    )
    parser.add_argument(
        "--sustained-duration",
        type=float,
        default=10.0,
        help="Duration in seconds across which to spread the sustained requests.",
    )
    parser.add_argument(
        "--sustained-concurrency",
        type=int,
        default=3,
        help="Concurrent workers for the sustained test.",
    )
    parser.add_argument(
        "--timeout",
        type=float,
        default=5.0,
        help="Per-request timeout in seconds.",
    )
    parser.add_argument(
        "--verbose",
        action="store_true",
        help="Print individual response summaries.",
    )
    return parser.parse_args()


def build_url(base: str, path: str) -> str:
    return f"{base.rstrip('/')}/{path.lstrip('/')}"


def summarize(label: str, responses: Iterable[ResponseRecord], elapsed: float) -> None:
    responses_list = list(responses)
    total = len(responses_list)
    successes = sum(1 for r in responses_list if r.ok)
    throttled = sum(1 for r in responses_list if r.status == 429)
    failures = total - successes
    latencies = [r.latency for r in responses_list if r.latency is not None]
    latency_ms = [l * 1000.0 for l in latencies]

    print(f"\n[{label}] completed {total} requests in {elapsed:.2f}s")
    print(f"  ✓ success:   {successes}")
    print(f"  ⚠ throttled: {throttled}")
    print(f"  ✗ failures:  {failures - throttled}")

    if latency_ms:
        avg = statistics.mean(latency_ms)
        p95 = statistics.quantiles(latency_ms, n=20)[18] if len(latency_ms) >= 20 else max(latency_ms)
        print(f"  Latency avg: {avg:.1f} ms | max: {max(latency_ms):.1f} ms | p95: {p95:.1f} ms")


def log_verbose(responses: Iterable[ResponseRecord]) -> None:
    for idx, response in enumerate(responses, start=1):
        status = response.status if response.status is not None else "ERR"
        latency_ms = response.latency * 1000.0
        detail = response.error if response.error else (response.body[:120] if response.body else "")
        print(f"  #{idx:03d} status={status} latency={latency_ms:.1f}ms {detail}")


def run_burst_test(
    client: HttpClient,
    url: str,
    headers: Dict[str, str],
    payload: str,
    total_requests: int,
    concurrency: int,
    verbose: bool,
) -> None:
    print(f"\nRunning burst test: {total_requests} requests @ concurrency {concurrency}")
    start = time.perf_counter()
    with concurrent.futures.ThreadPoolExecutor(max_workers=concurrency) as executor:
        futures = [
            executor.submit(client.request, "POST", url, headers, payload)
            for _ in range(total_requests)
        ]
        responses = [future.result() for future in concurrent.futures.as_completed(futures)]
    elapsed = time.perf_counter() - start
    summarize("Burst", responses, elapsed)
    if verbose:
        log_verbose(responses)


def run_sustained_test(
    client: HttpClient,
    url: str,
    headers: Dict[str, str],
    payload: str,
    total_requests: int,
    spread_seconds: float,
    concurrency: int,
    verbose: bool,
) -> None:
    print(
        f"\nRunning sustained test: {total_requests} requests over "
        f"{spread_seconds:.1f}s @ concurrency {concurrency}"
    )
    interval = spread_seconds / max(total_requests, 1)
    start = time.perf_counter()
    with concurrent.futures.ThreadPoolExecutor(max_workers=concurrency) as executor:
        futures: List[concurrent.futures.Future[ResponseRecord]] = []
        for idx in range(total_requests):
            target = start + idx * interval
            delay = target - time.perf_counter()
            if delay > 0:
                time.sleep(delay)
            futures.append(executor.submit(client.request, "POST", url, headers, payload))
        responses = [future.result() for future in futures]
    elapsed = time.perf_counter() - start
    summarize("Sustained", responses, elapsed)
    if verbose:
        log_verbose(responses)


def warmup_health_check(client: HttpClient, url: str) -> None:
    print(f"Checking health endpoint {url} ...", end=" ", flush=True)
    response = client.request("GET", url)
    if response.ok:
        print("ok")
    else:
        print("failed")
        if response.error:
            print(f"  Error: {response.error}")
        raise SystemExit("Health check failed; aborting load tests.")


def main() -> None:
    args = parse_args()
    client = HttpClient(timeout=args.timeout)

    health_url = build_url(args.base_url, args.health_path)
    ingest_url = build_url(args.base_url, args.ingest_path)
    payload = (
        json.dumps(
            {
                "device_id": "m1",
                "temperature_c": 21.5,
                "timestamp": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
            }
        )
        if args.payload == "auto"
        else args.payload
    )

    ingest_headers = {
        "Content-Type": "application/json",
        "x-api-key": args.api_key,
    }

    warmup_health_check(client, health_url)

    run_burst_test(
        client=client,
        url=ingest_url,
        headers=ingest_headers,
        payload=payload,
        total_requests=args.burst_requests,
        concurrency=args.burst_concurrency,
        verbose=args.verbose,
    )

    run_sustained_test(
        client=client,
        url=ingest_url,
        headers=ingest_headers,
        payload=payload,
        total_requests=args.sustained_requests,
        spread_seconds=args.sustained_duration,
        concurrency=args.sustained_concurrency,
        verbose=args.verbose,
    )

    print("\nDone. Compare 429 counts and latencies to the configured usage plan limits.")


if __name__ == "__main__":
    main()
