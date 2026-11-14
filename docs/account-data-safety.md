# Account data safety: temporary pause

The application currently uses unscoped local storage. The owner of existing
local data may be ambiguous, including when a Firebase account is signed in.
The standalone `ProfileStorage`, `ProfileLocalDataSource`, and
`ProfileTransitionJournal` are not integrated profile isolation. The journal
records decisions; it does not perform or verify profile operations.

The app wiring pauses all cloud sync using `PausedCloudSyncService` and blocks
sync requests before they can be queued. It also blocks sign-in, sign-up, and
anonymous account linking. An already signed-in user can sign out after being
warned that local data remains on the device. No local data is removed or
migrated. This is a temporary fail-closed measure, not account support.

Limitations and requirements before restoring account/sync functionality:

- Local data is still shared and visible on the device, including after sign-out;
  the app cannot offer safe local-copy removal or isolated account activation.
- Add profile-scoped reads and writes, safe explicit legacy ownership resolution,
  consented import (including decline and later import), provider reloads, and
  a sign-out keep/remove choice. Preserve ambiguous legacy data and copies.
- Bind queued and in-flight work to the authenticated UID and profile, cancel or
  drain it safely during transitions, and test races and interrupted migrations.
  The existing unwrapped Firebase sync service does not provide these guarantees.
- The pause only applies to the app's current wiring. Do not bypass the adapter
  or disable either provider guard before implementing and testing those rules.
  Other clients, older app versions, and server operations already in flight
  are not stopped by this change. Firestore's persistent cache requires a privacy
  policy as well.
- Firebase authentication may restore a pre-existing signed-in session; its
  legacy local data is not attributed to that account, and sync remains paused.
