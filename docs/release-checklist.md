# Release Readiness Checklist

Use this checklist before merging high-impact changes or cutting a release candidate.

For real-device coverage and internal distribution prerequisites, use `docs/device-smoke-test.md` in addition to this checklist.

## 1) Environment

- Working tree is clean (or only intentional changes are present)
- Dependencies installed:
  - `flutter pub get`
  - `cd ios && pod install`

## 2) Automated Quality Gates

Run from repo root unless noted.

### Flutter static analysis

```bash
flutter analyze
```

Expected: no issues.

### Flutter tests

```bash
flutter test
```

Expected: all tests pass.

### Cloud Functions tests

```bash
cd functions && npm test
```

Expected: all functions tests pass.

### Web build

```bash
flutter build web --release
```

Expected: successful build with output under `build/web/`.

### Android debug build

```bash
flutter build apk --debug
```

Expected: successful build with APK artifact in `build/app/outputs/flutter-apk/`.

### iOS simulator build/run smoke

```bash
open -a Simulator
flutter devices
flutter run -d <SIMULATOR_UDID>
```

Expected: app boots successfully on simulator.

## 3) Sync Manual Smoke Tests

Use the app UI in `HomeScreen` for these checks.

### A. Fresh launch sync

- Start app with network online.
- Trigger `Sync now`.

Expected:
- Status transitions to syncing and returns to synced/idle.
- No crash or stuck loading state.

### B. Offline pending sync and reconnect drain

- Put device offline.
- Trigger sync (manual or auto path).
- Restore network.

Expected:
- Status shows pending while offline.
- Exactly one queued sync drains after reconnect.
- No duplicate retry/sync execution.

### C. Retry after failure

- Force or simulate a retryable sync failure.
- Confirm retry status appears.
- Trigger `Retry now`.

Expected:
- Immediate retry executes once.
- Status converges to synced/idle on success, or failed with clear message.
- Retry controls are shown only when relevant.

### D. Diagnostics copy/report flow

- Open `View details` in sync status UI.
- Run `Copy diagnostics`.
- Run `Report issue`.

Expected:
- Diagnostics text includes `Diagnostics Version`.
- Secrets are redacted in copied/shared diagnostics.
- No UI errors in dialog actions.

### E. Diagnostics reset behavior

- From sync details, run `Reset diagnostics`.

Expected:
- Counters reset to zero.
- Last outcome resets to `N/A`.
- Sync health resets to `Unknown`.
- Last successful sync timestamp/data state are not corrupted.

## 4) CI Verification

After pushing the branch/merge commit, confirm `Flutter CI` is green for the target SHA:

- `Functions Tests`
- `Analyze, Test & Web Build`
- `Android Debug Build`
- `iOS Simulator Build (codesign disabled)`

Expected: all required jobs pass.

## 5) Release Sign-off

- Changelog/release notes updated (if applicable)
- No unintended files included (for example local lockfile churn)
- Final reviewer sign-off recorded in PR
