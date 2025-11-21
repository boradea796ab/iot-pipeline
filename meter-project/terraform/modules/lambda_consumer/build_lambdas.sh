#!/usr/bin/env bash
set -euo pipefail

MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$MODULE_DIR/build"
REQUIREMENTS="$MODULE_DIR/requirements.txt"

function build_package() {
  local name="$1"
  local handler_file="$2"
  local target_dir="$BUILD_DIR/$name"

  echo "[build] Preparing package: $name"
  rm -rf "$target_dir"
  mkdir -p "$target_dir"

  if [[ -f "$REQUIREMENTS" ]]; then
    python3 -m pip install -r "$REQUIREMENTS" -t "$target_dir"
  fi

  cp "$MODULE_DIR/$handler_file" "$target_dir/"
}

build_package "iot_consumer" "lambda_function.py"
build_package "dlq_processor" "lambda_dlq_processor.py"

echo "[build] Lambda build folders are ready in $BUILD_DIR"
echo "[build] Run 'terraform apply' to package them via archive_file."
