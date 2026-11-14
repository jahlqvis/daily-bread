# DailyBread

DailyBread is a Flutter app for daily Bible reading with gamification (streaks, XP, levels, badges) and local-first data storage.

**Account sign-in, sign-up, and cloud sync are temporarily paused** to prevent unsafe mixing of local and account data. Reading and local progress remain available without Firebase. An existing signed-in user can sign out after a warning that local data remains on the device. See `docs/account-data-safety.md` and `SPEC.md` for the remaining work.

## Features

- Daily reading flow with plan tracking and a first-launch translation choice (`KJV`, `ASV`, `WEB`)
- Bundled Bible text and fonts for offline reading without third-party font requests
- Gamified user progress: streaks, XP, levels, badges
- Bookmarking with tombstones for delete conflict handling
- Cloud sync infrastructure with pull/merge, retry/backoff, offline queueing, and lifecycle-triggered auto-sync (currently paused)
- Sync diagnostics in-app (`View details`, `Copy diagnostics`, `Report issue`, `Reset diagnostics`)
- Balanced diagnostics redaction for share/report workflows
- CI coverage for Flutter analyze/tests/web build, Android debug build, iOS simulator build, and Cloud Functions tests

## Tech Stack

- Flutter + Provider for app state
- SharedPreferences for local persistence
- Firebase Auth, Firestore, and Cloud Functions for cloud sync
- `connectivity_plus` for offline awareness
- `flutter_local_notifications` for reminder scheduling
- GitHub Actions for CI

## Project Structure

- `lib/main.dart` - app bootstrap and provider wiring
- `lib/presentation/providers/` - state orchestration (including sync/retry telemetry)
- `lib/presentation/screens/` - UI screens and sync UX
- `lib/services/cloud/` - local and Firebase cloud sync services + merge logic
- `lib/presentation/utils/sync_diagnostics_formatter.dart` - diagnostics formatting + redaction
- `lib/data/` - models, local data source, repositories
- `functions/` - Firebase Cloud Functions (server authority for sync)
- `.github/workflows/flutter.yml` - CI pipeline

## Getting Started

### Prerequisites

- Flutter stable
- Xcode (for iOS simulator builds)
- CocoaPods (`pod`)
- Node.js 22 (for Cloud Functions tests)

### Install dependencies

```bash
flutter pub get
cd ios && pod install
```

For Cloud Functions checks, run `npm ci` in `functions/`.

### Run locally

```bash
flutter run
```

### Run on iOS simulator

If Xcode is freshly installed, run once:

```bash
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -runFirstLaunch
```

Then:

```bash
open -a Simulator
flutter devices
flutter run -d <SIMULATOR_UDID>
```

## Firebase Configuration

The Firebase backend uses compile-time `--dart-define` values. Supplying these values does **not** enable the temporarily paused account and sync flows.

Required core values:

- `FIREBASE_API_KEY`
- `FIREBASE_PROJECT_ID`
- `FIREBASE_MESSAGING_SENDER_ID`

Platform app IDs (recommended):

- `FIREBASE_ANDROID_APP_ID`
- `FIREBASE_IOS_APP_ID`
- `FIREBASE_WEB_APP_ID`

Optional:

- `FIREBASE_STORAGE_BUCKET`
- `FIREBASE_AUTH_DOMAIN`
- `FIREBASE_IOS_BUNDLE_ID`

Example:

```bash
flutter run \
  --dart-define=FIREBASE_API_KEY=... \
  --dart-define=FIREBASE_PROJECT_ID=... \
  --dart-define=FIREBASE_MESSAGING_SENDER_ID=... \
  --dart-define=FIREBASE_ANDROID_APP_ID=... \
  --dart-define=FIREBASE_IOS_APP_ID=...
```

If these values are missing, DailyBread still supports local reading and progress. No cross-device backup occurs while sync is paused.

## Cloud Sync Notes

The following describes existing infrastructure, not currently active app behavior. The account-deletion callable is also disabled until its safety requirements are implemented.

- Snapshot model: user state + bookmarks + tombstones
- Merge strategy combines local and remote snapshots with timestamp-based conflict resolution
- Retry behavior uses backoff with max attempt limits
- Offline requests are queued and drained when connectivity returns
- Sync telemetry tracks success/failure/retry counts and last outcome for UX/diagnostics

## Testing

Run all Flutter checks:

```bash
flutter analyze
flutter test
```

Run Functions tests:

```bash
cd functions && npm test
```

For local Firebase emulator checks, see `docs/firebase-emulator-tests.md`.

## CI

`Flutter CI` runs on push/PR to `master` and includes:

- `Functions Tests` (Node)
- `Analyze, Test & Web Build` (Flutter)
- `Android Debug Build`
- `iOS Simulator Build (codesign disabled)`

Workflow file: `.github/workflows/flutter.yml`.

## Release Process

Use the release readiness checklist before high-impact merges or release candidates:

- `docs/release-checklist.md`
- `docs/device-smoke-test.md`

## Useful Commands

```bash
# Local quality gate
flutter analyze && flutter test

# Web build
flutter build web --release

# Android debug build
flutter build apk --debug
```

## Contributing

- Prefer small, focused PRs
- Keep CI green before merge
- Add/adjust tests with behavioral changes (especially sync/retry/offline logic)
