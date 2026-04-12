#!/bin/bash

set -euo pipefail

BACKEND_SCRIPT="${FLUTTER_ROOT}/packages/flutter_tools/bin/xcode_backend.sh"

clean_xattrs() {
  local paths=(
    "${PROJECT_DIR}/../build"
    "${PROJECT_DIR}/../build/ios"
    "${PROJECT_DIR}/../build/native_assets"
  )

  for target in "${paths[@]}"; do
    if [ -d "${target}" ]; then
      /usr/bin/xattr -cr "${target}" >/dev/null 2>&1 || true
    fi
  done
}

attempt=1
max_attempts=2

while [ "${attempt}" -le "${max_attempts}" ]; do
  if /bin/sh "${BACKEND_SCRIPT}" "$@"; then
    exit 0
  fi

  status=$?
  if [ "${attempt}" -ge "${max_attempts}" ]; then
    exit "${status}"
  fi

  echo "xcode_backend.sh failed (attempt ${attempt}). Cleaning extended attributes and retrying..."
  clean_xattrs
  attempt=$((attempt + 1))
  sleep 1
  echo "Retrying xcode_backend.sh (attempt ${attempt})"
done

exit 1
