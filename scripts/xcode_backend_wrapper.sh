#!/bin/bash

set -euo pipefail

BACKEND_SCRIPT="${FLUTTER_ROOT}/packages/flutter_tools/bin/xcode_backend.sh"

if [[ "${PLATFORM_NAME:-}" == *simulator* ]]; then
  export CODE_SIGNING_REQUIRED=NO
  export EXPANDED_CODE_SIGN_IDENTITY=""
fi

clean_xattrs() {
  local paths=(
    "${PROJECT_DIR}/../build"
    "${PROJECT_DIR}/../build/ios"
    "${PROJECT_DIR}/../build/native_assets"
    "${FLUTTER_ROOT}/bin/cache/artifacts/engine"
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
  attempt_log="$(mktemp)"
  set +e
  /bin/sh "${BACKEND_SCRIPT}" "$@" >"${attempt_log}" 2>&1
  status=$?
  set -e

  cat "${attempt_log}"

  if [ "${status}" -ne 0 ] && [[ "${PLATFORM_NAME:-}" == *simulator* ]]; then
    if /usr/bin/grep -q "resource fork, Finder information, or similar detritus not allowed" "${attempt_log}"; then
      echo "Ignoring simulator codesign detritus error from xcode_backend.sh"
      status=0
    fi
  fi

  rm -f "${attempt_log}"

  if [ "${status}" -eq 0 ]; then
    exit 0
  fi

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
