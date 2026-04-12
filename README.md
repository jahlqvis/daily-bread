# DailyBread

DailyBread is a Flutter-based mobile app that gamifies Bible reading with streaks, XP, levels, and badges. The project currently targets iOS simulator and Web, with Android and production deployments planned later.

## Prerequisites

- Flutter SDK cloned to `~/flutter` (stable channel)
- Xcode 26.4 with command-line tools selected (`sudo xcode-select -s /Applications/Xcode.app/Contents/Developer`)
- CocoaPods (`sudo gem install cocoapods` if missing)

After cloning/moving the repo, run:

```bash
~/flutter/bin/flutter pub get
(cd ios && pod install)
```

## Project layout

- `lib/` – app code (Providers for user/Bible state, screens for dashboard, reading, badges, etc.)
- `assets/` – placeholder Bible passages (expand with full content later)
- `scripts/` – helper scripts for iOS builds (`xcode_backend_wrapper.sh`, `run_ios_sim.sh`)

## Running on iOS Simulator

Xcode 26.x on macOS 15 refuses to sign artifacts that contain Finder metadata. Flutter's default `flutter run` still triggers that signing step, so we use a wrapper flow:

1. Ensure the simulator you want to target is created/booted (`xcrun simctl list devices`).
2. Execute the helper script with the simulator UDID (or name):
   ```bash
   scripts/run_ios_sim.sh DED5E049-5053-48EA-ACD8-842C1C8C81B5
   ```
   - The script runs `xcodebuild` with `CODE_SIGNING_ALLOWED=NO`, writes build logs to `/tmp/run_ios_sim_build.log`, and places artifacts in `build/flutter-ios`.
   - After a successful build it installs the resulting `Runner.app` onto the simulator and launches `com.dailybread.dailyBread` via `xcrun simctl launch`.
3. Attach Flutter DevTools if desired: `~/flutter/bin/flutter attach -d <SIM-UDID>`.

If the build fails, inspect `/tmp/run_ios_sim_build.log`. Common fixes:

- Delete stale caches (`rm -rf .dart_tool build/flutter-ios ios/Flutter/ephemeral`) and rerun `flutter pub get` + `pod install`.
- Ensure `ios/Flutter/Generated.xcconfig` points `FLUTTER_APPLICATION_PATH` and `PACKAGE_CONFIG` to this repo (`/Users/<you>/Documents/Repos/ProjectX`). If the project is moved, rerun `flutter pub get` to regenerate.

## Web build

```bash
~/flutter/bin/flutter build web
```

The output lives in `build/web/` and has been verified locally.

## Next steps

1. Expand Bible content beyond the current sample passages.
2. Add push notifications and Firebase/cloud sync for streaks.
3. Prepare Android + App Store distribution tooling once Apple resolves the macOS 15 signing bug (or after downgrading to Xcode 15).
