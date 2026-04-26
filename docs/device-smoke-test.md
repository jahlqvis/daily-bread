# Device Smoke Test and Distribution Readiness

Use this guide to validate behavior on real devices and confirm baseline readiness for internal distribution.

## 1) Test Matrix

Run the smoke suite on at least:

- iPhone physical device (required)
- Android physical device or emulator (required)
- iOS simulator (sanity)
- Web optional sanity check (`flutter run -d chrome`)

## 2) Build and Config Prerequisites

### 2.1 Firebase configuration

- Confirm the app is launched with intended Firebase values (`--dart-define`)
- Verify target Firebase project/environment is correct for test run
- Confirm Cloud Functions and Firestore rules are deployed for that environment

### 2.2 iOS prerequisites

- Valid bundle identifier is configured
- Signing team/profile is available locally (for real device install)
- Xcode first-launch setup completed
- CocoaPods installed (`pod` available)

### 2.3 Android prerequisites

- Android SDK and emulator/device available
- Application ID is correct for target environment
- Debug signing works for local install

## 3) Run Scenarios

Use Home sync UI and diagnostics actions for all checks.

## 3.1 App launch and baseline health

Steps:

- Launch app on target device
- Wait for initial UI load

Expected:

- No crash on startup
- Home UI renders fully
- Sync status is coherent (not stuck in `Syncing...`)

## 3.2 Manual sync while online

Steps:

- Keep network online
- Tap `Sync now`

Expected:

- Status transitions through syncing and returns to synced/idle
- No duplicate sync actions trigger from a single tap

## 3.3 Offline pending sync and reconnect drain

Steps:

- Put device offline
- Trigger sync (manual or lifecycle)
- Restore network

Expected:

- Status shows pending while offline
- Exactly one queued sync drains on reconnect
- No duplicate retry/sync execution

## 3.4 Retry behavior after retryable failure

Steps:

- Trigger/simulate a retryable failure
- Observe retry status
- Tap `Retry now`

Expected:

- One immediate retry executes
- Status converges to synced/idle on success, or failed with clear reason
- Retry controls only appear in failed state

## 3.5 Diagnostics copy/report/reset

Steps:

- Open `View details`
- Tap `Copy diagnostics`
- Tap `Report issue`
- Tap `Reset diagnostics`

Expected:

- Diagnostics include `Diagnostics Version`
- Sensitive values are redacted in copied/shared output
- Reset clears counters/outcome and resets health to `Unknown`
- Last successful sync timestamp and data integrity remain intact

## 3.6 Lifecycle/background behavior

Steps:

- Put app in background, then resume
- Repeat during/around sync activity

Expected:

- App remains stable
- Resume-triggered sync does not create duplicate concurrent executions

## 3.7 Reminder and share flows

Steps:

- Trigger reminder permission flow
- Trigger diagnostics share/report flow

Expected:

- Reminder prompt and status messaging work as expected
- Share sheet opens successfully on each platform

## 4) Distribution Readiness Checklist

### 4.1 iOS internal distribution readiness

- Bundle ID finalized for target track
- Signing team/profiles configured
- Firebase iOS app ID and environment values verified
- Device smoke suite completed and passed
- App can be archived for internal distribution process

### 4.2 Android internal distribution readiness

- Application ID confirmed
- Signing approach documented (debug vs release keystore)
- Firebase Android app ID and environment values verified
- Device smoke suite completed and passed
- Release build path validated (`flutter build apk`/AAB path as applicable)

## 5) Recording Results

For each run, capture:

- Commit SHA tested
- Device/OS version
- Scenario pass/fail
- Any regressions with reproduction notes

If failures are found, create targeted follow-up PRs and re-run impacted scenarios.
