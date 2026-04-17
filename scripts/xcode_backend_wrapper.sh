#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
export PATH="$SCRIPT_DIR:$PATH"

BACKEND_SCRIPT="${FLUTTER_ROOT}/packages/flutter_tools/bin/xcode_backend.sh"

simulator_context="${PLATFORM_NAME:-}${EFFECTIVE_PLATFORM_NAME:-}${SDKROOT:-}"
if [[ "${simulator_context}" == *simulator* ]]; then
  export CODE_SIGNING_REQUIRED=NO
  export CODE_SIGNING_ALLOWED=NO
  export EXPANDED_CODE_SIGN_IDENTITY=""
  export EXPANDED_CODE_SIGN_IDENTITY_NAME=""
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
  if [[ "${simulator_context}" == *simulator* ]]; then
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO \
    EXPANDED_CODE_SIGN_IDENTITY="" \
    EXPANDED_CODE_SIGN_IDENTITY_NAME="" \
      /bin/sh "${BACKEND_SCRIPT}" "$@" >"${attempt_log}" 2>&1
  else
    /bin/sh "${BACKEND_SCRIPT}" "$@" >"${attempt_log}" 2>&1
  fi
  status=$?
  set -e

  cat "${attempt_log}"

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
