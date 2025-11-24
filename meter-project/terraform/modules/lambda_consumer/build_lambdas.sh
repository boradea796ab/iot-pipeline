#!/usr/bin/env bash
set -euo pipefail

MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$MODULE_DIR/build"
REQUIREMENTS="$MODULE_DIR/requirements.txt"
VENDOR_DIR="$MODULE_DIR/vendor"

function build_package() {
  local name="$1"
  local target_dir="$BUILD_DIR/$name"

  echo "[build] Preparing package: $name"
  rm -rf "$target_dir"
  mkdir -p "$target_dir"

  if [[ -f "$REQUIREMENTS" ]]; then
    if python3 -m pip install -r "$REQUIREMENTS" -t "$target_dir"; then
      echo "[build] Installed dependencies via pip for $name"
    elif [[ -d "$VENDOR_DIR" ]]; then
      echo "[build] Pip install failed; falling back to vendored dependencies."
      rsync -a "$VENDOR_DIR/" "$target_dir/"
    else
      echo "[build] ERROR: unable to install requirements and no vendor directory present." >&2
      exit 1
    fi
  elif [[ -d "$VENDOR_DIR" ]]; then
    rsync -a "$VENDOR_DIR/" "$target_dir/"
  fi

  rsync -a --exclude '__pycache__' "$MODULE_DIR/code/" "$target_dir/code/"
}

build_package "iot_consumer"
build_package "dlq_processor"

echo "[build] Lambda build folders are ready in $BUILD_DIR"
echo "[build] Run 'terraform apply' to package them via archive_file."
