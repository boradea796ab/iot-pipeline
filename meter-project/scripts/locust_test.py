#!/usr/bin/env python3
"""End-to-end Locust test runner driven by scripts/.env."""

from __future__ import annotations

import sys

from e2e.aurora import AuroraDataAPI
from e2e.comparator import compare_records
from e2e.config import build_log_path, load_config
from e2e.locust_runner import run_locust
from e2e.log_parser import load_request_log, summarize_failures


def main() -> None:
    config = load_config()
    log_path = build_log_path(config.log_dir)

    client = AuroraDataAPI(
        secret_arn=config.aurora_secret_arn,
        table_name=config.table_name,
        database=config.database,
        cluster_arn=config.aurora_cluster_arn,
        cluster_endpoint=config.aurora_endpoint,
        region=config.aws_region,
    )

    if not config.skip_clean:
        client.truncate_table()
    else:
        print("⏭️  Skipping table cleanup per configuration.")

    run_locust(config, log_path)

    successes, failures = load_request_log(log_path)
    failure_summary = summarize_failures(failures)
    print(f"\n📄 Request log: {log_path}")
    print(f"   Successful requests recorded: {len(successes)}")
    print(f"   Other log entries: {len(failures)} {dict(failure_summary)}")

    aurora_rows = client.fetch_rows()
    print(f"🏛️  Aurora rows fetched: {len(aurora_rows)} from table {config.table_name}")

    missing, extra, mismatched = compare_records(successes, aurora_rows)
    if missing or extra or mismatched:
        print("\n❌ Data mismatch detected.")
        if missing:
            print(f"   Rows missing in Aurora (count={len(missing)}). Sample: {missing[:5]}")
        if extra:
            print(f"   Extra rows in Aurora (count={len(extra)}). Sample: {extra[:5]}")
        if mismatched:
            print(f"   Payload mismatches (count={len(mismatched)}). Sample: {mismatched[:5]}")
        sys.exit(1)

    print("\n✅ All recorded requests are present in Aurora with matching payloads.")


if __name__ == "__main__":
    main()
