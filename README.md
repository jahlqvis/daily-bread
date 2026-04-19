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
- `assets/` – `bible/kjv_books`, `bible/asv_books`, and `bible/web_books` contain per-book JSON for KJV, ASV, and WEB translations
- `scripts/` – helper scripts for iOS builds (`xcode_backend_wrapper.sh`, `run_ios_sim.sh`)

## Bible data & translations

- Translation selector (globe icon) lets you switch between `KJV`, `ASV`, and `WEB` anywhere you enter the reading flow. The choice persists while the app is open.
- The per-book datasets are generated via:
  - `dart run tool/generate_bible_books.dart kjv asv` – downloads Scrollmapper JSON for the KJV/ASV and writes per-book assets
  - `dart run tool/import_web_translation.dart` – downloads the WEB HTML archive from eBible.org, parses every chapter, and emits `web_books/*.json`
- Each JSON file has the shape `{ "name": "Genesis", "chapters": [ { "chapter": 1, "verses": [ { "verse": 1, "text": "..." } ] } ] }`

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

## Continuous Integration

- `.github/workflows/flutter.yml` runs on every push/PR to `master`.
- Job 1 (`Analyze, Test & Web Build`) runs on Ubuntu, executes `flutter pub get`, `flutter analyze`, `flutter test`, and `flutter build web --release` with cached pub packages.
- Job 2 (`iOS Simulator Build`) runs on `macos-14`, caches CocoaPods, installs pods, and runs `xcodebuild … CODE_SIGNING_ALLOWED=NO` to ensure the Runner target continues to build despite macOS 15/Xcode 26 codesign restrictions.

## Firebase cloud sync MVP

- The app now supports a Firebase-backed sync path with anonymous auth and Firestore upload during `Sync now`.
- If Firebase is not configured, the app automatically falls back to local backup mode.
- Configure Firebase using `--dart-define` values (core values are required):

```bash
~/flutter/bin/flutter run \
  --dart-define=FIREBASE_API_KEY=... \
  --dart-define=FIREBASE_PROJECT_ID=... \
  --dart-define=FIREBASE_MESSAGING_SENDER_ID=... \
  --dart-define=FIREBASE_ANDROID_APP_ID=... \
  --dart-define=FIREBASE_IOS_APP_ID=...
```

- Optional defines: `FIREBASE_WEB_APP_ID`, `FIREBASE_STORAGE_BUCKET`, `FIREBASE_AUTH_DOMAIN`, `FIREBASE_IOS_BUNDLE_ID`.
- Firestore rules are defined in `firestore.rules` and referenced by `firebase.json`.
- Deploy/update rules with Firebase CLI:

```bash
firebase deploy --only firestore:rules
```

## Next steps

1. Use server-side conflict resolution in Cloud Functions to remove remaining client clock skew edge cases.
2. Expand the translation selector with reading plans or translation-specific study notes.
3. Prepare Android + App Store distribution tooling once Apple resolves the macOS 15 signing bug (or after downgrading to Xcode 15).
