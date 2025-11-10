#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

python3 "$SCRIPT_DIR/lambda_dlq_test.py"
python3 "$SCRIPT_DIR/replay_recent_messages.py" "$@"
