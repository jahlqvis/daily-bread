## DailyBread – Product & Technical Spec

### Vision & Goals

- Help users build a daily Bible-reading habit through streaks, XP, levels, and badges.
- Support offline-first reading and progress with public-domain translations (KJV, ASV, WEB).
- Provide a mobile-first Flutter app with optional account-linked sync across devices.

Desired measures of success include reading frequency, chapter and plan completion, and badge unlocks. These are product goals, not a claim that analytics reporting is deployed.

### Release MVP Decisions

- **Audience and platforms:** General audience, not specifically marketed to children; English interface; iPhone is the required release platform. Android and web builds remain supported by existing CI, but are not release blockers for this milestone.
- **Business and privacy:** Free, no ads or purchases, and no behavioral analytics. Operational diagnostics stay local unless the user explicitly shares them. Review privacy, security, accessibility, and applicable App Store requirements before release.
- **Scope:** Polish and harden the existing reading, progress, plans, bookmarks, notes, reminders, account, and sync features. Review plan names and descriptions against their actual content. Defer major social features, standalone journaling, and expansion of the plan catalog.
- **Onboarding:** Ask the reader to choose KJV, ASV, or WEB on first launch. Persist the choice and allow changing it later. Reading and local progress must work offline without an account or Firebase configuration.
- **Accounts:** Optional email/password accounts enable cross-device sync. Signing up, signing in, resetting the password, and signing out must be understandable and usable without risking local data.
- **Sync scope:** Sync user progress, bookmarks and notes, active plan and its start date, and claimed plan rewards. Merge progress and rewards; the most recently changed active-plan selection wins, including clearing the selection. Reminder settings remain device-local. Translation preference stays device-local unless a later decision changes this.
- **Data separation and consent:** Before combining an existing local profile with an account, explain the merge and obtain consent. If declined, preserve the local profile separately, use the account profile, and offer an explicit import later. Never silently mix data belonging to different accounts. Existing installations must migrate without losing data.
- **Sign-out:** Ask whether to remove the local account copy or keep a local copy for offline use. Explain that removing the local copy does not delete cloud data and keeping it can expose it to the next device user. Do not silently import a retained copy into another account.
- **Account deletion:** Offer in-app account and cloud-data deletion with confirmation and a clear local-data choice. Require connectivity; do not claim success until the server confirms deletion. Handle partial failures and reauthentication without implying that data has been deleted when it has not.

### Release Acceptance Criteria

- Fresh and existing installations can start offline, choose/change a translation, read, and retain local progress across restarts. Existing data is not overwritten by onboarding or migration.
- Account creation, sign-in, sign-out, password reset, account switching, local import, and deletion have clear success and failure states. A declined merge preserves both profiles and allows a later explicit import.
- Two signed-in devices converge on reading progress, bookmarks, bookmark deletions and notes, active plan, and claimed rewards. Offline edits, reconnect, retries, conflicting changes, legacy snapshots, and account changes are covered by tests; no cloud success is reported for a local-only fallback.
- Reminders behave correctly with permission granted or denied, and remain device-local. Core reading and navigation are usable with accessibility features and reasonable text scaling.
- Automated analysis, Flutter and Cloud Functions tests, and relevant builds pass. Record real-iPhone smoke-test results for onboarding, offline reading, accounts, sync, deletion, reminders, accessibility, and privacy flows. CI and simulator builds are not substitutes for device tests.
- Prepare the release checklist, privacy and support information, signing/archive instructions, and App Store submission materials as far as possible. Verify actual Firebase deployment and App Store requirements before release; obtain user approval before external deployment or publication.

### Current Status

The app implements the core reading experience, local persistence, reminders, authentication, and cloud-sync infrastructure. **Account sign-in, sign-up, and sync are temporarily paused** in the app because existing local data is not profile-isolated; see `docs/account-data-safety.md`. Existing signed-in users can sign out after a warning that local data remains. CI covers analysis, tests, and web, Android debug, and iOS simulator builds. Release readiness and real-device validation are not established by those builds alone; see `docs/release-checklist.md` and `docs/device-smoke-test.md`.

The current working tree also contains uncommitted account-menu and iOS configuration changes. These should be reviewed and tested separately from the last committed CI results.

### Implemented User Flows

1. **Home and progress:** View reading progress, streaks, XP, levels, badges, and sync status. Marking a new chapter read updates progress and rewards once; streak milestones are awarded once when reached. Calendar-day streaks account for daylight-saving transitions. Streak freezes can automatically preserve a streak after a missed day; the Bookworm badge requires a complete book.
2. **Read the Bible:** Choose a translation on first launch, and change it later; choose a testament, book, and chapter, navigate chapters, and mark them read.
3. **Reading plans:** Select from three built-in plans (Matthew and the beginning of Mark, John, and Wisdom), track progress, resume reading, and claim completion rewards. Plan progress is derived from completed chapters.
4. **Search and bookmarks:** Search verses, bookmark them, and add or edit bookmark notes.
5. **Reminders:** Configure daily local notifications on supported iOS and Android devices, subject to notification permission. Web notifications are not supported by this implementation.
6. **Accounts and sync:** Email/password authentication and sync infrastructure exist, but account changes and sync are paused as described above. Password reset and signing out of an existing session remain available. Safe profile isolation and consent must be implemented before resuming account and sync flows.
7. **Diagnostics:** Inspect sync status and details, copy or share redacted diagnostics, and reset diagnostic counters.

### Architecture

- **App:** Flutter with Material UI and Provider. `lib/main.dart` wires the data sources, repositories, providers, and services.
- **State:** `UserProvider`, `BibleProvider`, `ReadingPlanProvider`, and `BookmarksProvider` manage reading state. `AuthProvider` manages authentication; `AppServicesProvider` coordinates sync, connectivity, retries, reminder state, and diagnostics.
- **Content:** `BibleDataSource` lazily loads and caches per-book JSON from `assets/bible/<translation>_books/`. Content tooling is in `tool/`.
- **Typography:** Noto Sans is bundled with its license; app startup and reading do not fetch fonts from a third party.
- **Local data:** `LocalDataSource` uses SharedPreferences for user progress, active-plan state and reward claims, bookmarks and deletion tombstones, reminder settings, local sync snapshots, and sync diagnostics. Actual keys are defined in `lib/data/datasources/local_data_source.dart`.
- **Business logic:** `UserRepository` applies streak, XP, level, and badge rules. Constants and built-in plans are in `lib/core/constants/`.
- **Screens:** Home, book/chapter selection, reading, reading plans, progress, badges, search, bookmarks, sign-in, and account creation live in `lib/presentation/screens/`.

### Data and Sync

`UserModel` stores current and longest streaks, total XP, level, badges, last read date, completed chapters, and streak freezes. Bookmarks include a translation, verse reference, optional note, and timestamps.

The sync snapshot contains the user model, bookmarks, and bookmark tombstones. User merging unions completed chapters and badges, takes maxima for selected progress values, and uses the latest reading date for streak-related state. Bookmark updates and deletions are resolved by timestamp; tombstones prevent older copies from resurrecting deleted bookmarks.

Firebase configuration is supplied through compile-time `--dart-define` values; see `README.md`. The Firebase service can initialize an anonymous user during sync, attempts the `syncUserState` Cloud Function, and can fall back to a client-side Firestore merge or a local backup. A local backup is not cross-device sync. Firestore rules restrict access to the owning user and validate document shapes; the callable function also validates sync payloads. The sync UI supports offline queueing, retries/backoff, lifecycle-triggered sync, and diagnostics.

Active-plan selection, start date, completion-reward claim IDs, reminder settings, and diagnostic counters are stored separately from the sync snapshot. They should not be assumed to sync between devices; completed chapters in the user model do sync.

### Platforms, Builds & Verification

- **iOS:** Simulator build is in CI with code signing disabled. A physical-device build and internal distribution require appropriate bundle ID, signing, Firebase configuration, and device validation.
- **Android:** Debug APK build is in CI. Device testing and release signing/distribution require separate verification.
- **Web:** Release build is in CI. Reminder notifications are unsupported by the current service.
- **Automated checks:** `flutter analyze`, `flutter test`, and `cd functions && npm test`. CI also builds web, Android debug, and iOS simulator targets.
- **Content checks:** Tests verify all 198 bundled book files and expected chapter counts. Sixteen intentionally blank ASV verse entries are identified in the reader rather than presented as unexplained empty text.
- **Manual checks:** Follow `docs/release-checklist.md` and `docs/device-smoke-test.md`, especially for real-device sync, offline/reconnect, reminders, sharing, and release configuration. A CI pass does not validate uncommitted changes or prove Firebase services are deployed.

See `README.md` for setup, Firebase options, commands, and project structure.

### Remaining Work / Follow-up

- Implement the MVP decisions and acceptance criteria above; in particular, profile isolation and consent, plan-state sync, and end-to-end account deletion are not yet established by the existing implementation. First-launch translation choice has been implemented but still needs verification.
- Integrate and validate the standalone profile-storage foundation, profile-scoped data-source adapter, and transition journal before relying on them for isolation. The journal records decisions only; it does not perform or prove profile operations and still needs a safe cancellation flow. Legacy copies and migration records must be handled when removing local data; Firestore's persistent cache also needs a defined privacy policy.
- Harden account deletion against concurrent sync or stale authenticated clients and integrate reauthentication, confirmation, error, and local-data flows. The unfinished callable is disabled by default; its internal deletion implementation requires recent authentication but is not an end-to-end release-ready feature.
- Validate the Firebase Admin and Functions major-version upgrade in the target environment before deployment. Local Auth, Firestore, and Functions emulator checks pass; see `docs/firebase-emulator-tests.md`. The production dependency audit currently reports no known vulnerabilities; continue checking advisories before release.
- Review and test the uncommitted account-menu and iOS project/lockfile changes; preserve them unless their owner approves otherwise.
- Verify Firebase configuration, deployed Cloud Functions and Firestore rules, and account/sync behavior in the intended environment, including local-fallback behavior.
- Complete and record the iPhone smoke matrix and release checklist; validate iOS signing and archive. Android release signing and distribution are outside this milestone.
- Consider additional reading plans and chapter context or summaries.
- Consider verse sharing and fuller journaling; bookmark notes already exist, and diagnostics can already be shared.
- Consider further gamification such as leaderboards and community challenges; basic streak-freeze behavior already exists.

### Implementation Order for Account Data Safety

1. Integrate profile-scoped storage and a restart-safe, explicitly attributed legacy migration. Pause sync and isolate in-flight and queued work during account transitions; never infer ownership of ambiguous legacy data.
2. Implement import consent, separate-profile activation, later import, and the sign-out keep/remove choice. Reload providers after profile changes and cover interruption, failure, and account-switch races.
3. Extend both client and server snapshots with timestamped plan selection (including clears) and reward claims. Handle missing fields in legacy clients without silently clearing newer data; ensure concurrent syncs cannot lose updates. Deploy compatible backend/rules before depending on new fields.
4. Complete account deletion, including reauthentication, prevention of concurrent writes and sync, clear local-data handling, and retryable partial failures. Block direct client writes and fence all privileged sync commits with a durable deletion guard; add durable recovery for interrupted deletion and a status mechanism for lost responses. Plan rollout for old clients and define whether UIDs can be reused before implementing a deletion worker. Test against Firebase emulators as well as unit tests before deployment.
5. Complete accessibility, real-device, privacy, and release validation. Local-only backup must never be presented as successful cross-device sync.

### Open Questions

- What privacy, security, data-retention, and compliance requirements apply before wider cloud-sync distribution?
- Which Firebase project, Apple developer team, bundle ID, support contact, and hosted privacy-policy URL should be used for release?
- Which specific devices and iOS versions will be used for release validation?

### Execution Boundaries

Implementation may proceed autonomously on local code, tests, documentation, and independent parallel agent work. Make and document reasonable minor decisions within this spec. Preserve existing user changes; do not discard them or commit them automatically. Ask before paid services, external deployment, publishing, or destructive actions, and when credentials or consequential product decisions are required.

Keep this document aligned with the implementation and distinguish verified results from planned work.
