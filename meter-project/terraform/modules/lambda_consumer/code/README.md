# Lambda consumer shared library

This package contains the refactored building blocks for the primary consumer and DLQ Lambda functions. Terraform still points to the legacy single-file handlers; this directory is a staging area for the eventual migration.

Components:

- `models.py` – dataclasses for SQS messages plus helpers to build Lambda responses.
- `idempotency.py` – pluggable interface with a DynamoDB-backed implementation and an in-memory/no-op variant for tests.
- `repository.py` – Aurora repository that manages connection reuse and exposes a `save_reading` method, plus a simple in-memory stub for tests.
- `processor.py` – domain-level processor that parses payloads, optionally simulates random validation failures, and persists readings.
- `batch_handler.py` – `run_batch` function drives the reserve → process → mark lifecycle, collects failures, and emits structured telemetry via a simple `BatchBehavior`.
- `config.py` – strongly typed loaders for both the main consumer and DLQ Lambda environment variables.
- `lambda_consumer.py` and `lambda_dlq.py` – new Lambda entrypoints that wire the above pieces together.

Next steps to adopt this refactor:

1. Update the Lambda packaging scripts/terraform to include `code/` and point to the new handlers.
2. Port any remaining business logic differences (for example, DLQ-specific validation) into dedicated strategies.
3. Add unit tests under `terraform/modules/lambda_consumer/tests/` that instantiate the `BatchProcessor` with the in-memory repository and idempotency stubs.
