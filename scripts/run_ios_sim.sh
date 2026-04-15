#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IOS_DIR="$ROOT_DIR/ios"
APP_PATH="$ROOT_DIR/build/ios/iphonesimulator/Runner.app"
DERIVED_DATA="$ROOT_DIR/build/flutter-ios"
APP_PATH="$DERIVED_DATA/Build/Products/Debug-iphonesimulator/Runner.app"

SIM_DEVICE="${1:-${SIM_DEVICE_ID:-}}"

if [[ -z "$SIM_DEVICE" ]]; then
  cat <<'EOF'
Usage: scripts/run_ios_sim.sh <SIMULATOR-UDID|NAME>

Provide the simulator UDID (recommended) or name, e.g.
  scripts/run_ios_sim.sh DED5E049-5053-48EA-ACD8-842C1C8C81B5

Set SIM_DEVICE_ID env var to avoid passing it each time.
EOF
  exit 1
fi

echo "[iOS] Building Runner for simulator..."
rm -rf "$DERIVED_DATA"
xcodebuild \
  -workspace "$IOS_DIR/Runner.xcworkspace" \
  -scheme Runner \
  -configuration Debug \
  -destination "platform=iOS Simulator,id=$SIM_DEVICE" \
  -derivedDataPath "$DERIVED_DATA" \
  build CODE_SIGNING_ALLOWED=NO >/tmp/run_ios_sim_build.log && BUILD_OK=1 || BUILD_OK=0

if [[ "$BUILD_OK" -ne 1 ]]; then
  echo "Build failed. See /tmp/run_ios_sim_build.log"
  exit 1
fi

if [[ ! -d "$APP_PATH" ]]; then
  echo "Runner.app not found at $APP_PATH"
  exit 1
fi

if [[ ! -f "$APP_PATH/Frameworks/Flutter.framework/Flutter" ]]; then
  echo "Flutter.framework missing in app bundle. See /tmp/run_ios_sim_build.log"
  exit 1
fi

echo "[iOS] Booting simulator $SIM_DEVICE (if needed)..."
xcrun simctl bootstatus "$SIM_DEVICE" >/dev/null 2>&1 || xcrun simctl boot "$SIM_DEVICE"

echo "[iOS] Installing Runner.app on $SIM_DEVICE"
xcrun simctl install "$SIM_DEVICE" "$APP_PATH"

echo "[iOS] Launching com.dailybread.dailyBread"
xcrun simctl launch "$SIM_DEVICE" com.dailybread.dailyBread

echo "[iOS] App launched. Attach with 'flutter attach -d $SIM_DEVICE' if needed."
