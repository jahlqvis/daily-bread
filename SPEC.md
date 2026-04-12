## DailyBread – Product & Technical Spec

### Vision & Goals
- Help users establish daily Bible-reading habits through gamification (streaks, XP, levels, badges).
- Operate fully offline first (SharedPreferences persistence) using public-domain translations (KJV, ASV, WEB).
- Provide a polished, mobile-first UI (Flutter) that can later expand to Android/Web and cloud sync.

Success metrics:
1. Daily active readers (tracked via streaks).
2. Reading completion rate per plan/chapter.
3. Badge unlock counts per user (engagement).

### Target Platforms
- iOS simulator now (scripts/run_ios_sim.sh workflow).
- Flutter Web (build/web already works).
- Android + device distributions later once stable.

### User Flows
1. **Open app → Home Dashboard**
   - Sees today’s verse quote, streak count, XP progress, level, quick badges.
2. **Select Book/Chapter**
   - Book picker grouped by Testament → chapter grid with completion indicators.
3. **Read & Mark Complete**
   - Reading screen shows verses; `Mark as Read` updates streak, XP, badges.
4. **Review Progress**
   - Progress screen summarizes streak history, total chapters read, XP breakdown.
5. **Badges Gallery**
   - Shows earned/locked achievements (streak milestones, XP thresholds, first OT/NT completion, etc.).

### Architecture Overview
- **Framework:** Flutter 3 (Material 3 design), packaged via Provider for state management.
- **State Management:**
  - `UserProvider` controls streak, XP, levels, badges, persisted progress.
  - `BibleProvider` tracks selected translation/testament/book/chapter.
- **Data Layer:**
  - `LocalDataSource` (SharedPreferences) stores user progress (last read date, streak count, XP, badges, per-book progress).
  - `BibleDataSource` lazily loads per-book JSON for each translation (KJV/ASV/WEB) from `assets/bible/<translation>_books/*.json` and caches the result in-memory.
- **Repository:** `UserRepository` applies business rules (streak continuity, XP awards, badge unlocking) and proxies persistence.
- **UI Screens:**
  - `HomeScreen` → high-level stats + entry points.
  - `BookSelectionScreen`, `ChapterSelectionScreen`, `ReadingScreen` → navigation flow.
  - `ProgressScreen`, `BadgesScreen` → analytics/achievements.

### Data Model Highlights
```dart
class UserProgress {
  int currentStreak;
  int bestStreak;
  int xp;
  int level;
  List<String> badges;
  Map<String, Set<int>> readingProgress; // bookId -> completed chapters
  DateTime? lastReadDate;
}

class BibleBook {
  final String id; // e.g., "genesis"
  final String name;
  final Testament testament; // old/new
  final List<BibleChapter> chapters;
}
```
- XP progression: base XP per chapter + streak multipliers (config in `app_constants.dart`).
- Levels: defined via cumulative XP thresholds.
- Badges: unlocked at configured milestones (first read, 7-day streak, 30-day streak, level 10, etc.).

### Persistence Strategy
- **SharedPreferences keys** (namespace `dailybread_*`).
  - `dailybread_user_progress` stores JSON representation of `UserProgress`.
  - `dailybread_last_read_date`, `dailybread_badges`, etc., as supplemental keys.
- Local-only for MVP; architecture ready to swap persistence with cloud sync layer.

### Assets & Content Plan
- `assets/bible/kjv_books`, `assets/bible/asv_books`, `assets/bible/web_books` – generated per-book JSON files for each public-domain translation (via `tool/generate_bible_books.dart` and `tool/import_web_translation.dart`).
- Next steps:
  1. Add metadata for reading plans (e.g., chronological, OT/NT, Psalms/Proverbs).
  2. Provide short contextual summaries per chapter for engagement.

### Build & Run Instructions
1. `~/flutter/bin/flutter pub get` (after repo move, regenerates `.dart_tool`).
2. `~/flutter/bin/flutter analyze` and `~/flutter/bin/flutter test` (tests pending).
3. iOS simulator:
   ```bash
   scripts/run_ios_sim.sh <SIM-UDID>
   ```
   - Works around macOS 15 codesign bug by calling `xcodebuild ... CODE_SIGNING_ALLOWED=NO` and installing via `xcrun simctl`.
4. Web:
   ```bash
   ~/flutter/bin/flutter build web
   ```

### Roadmap / Future Work
1. **Reminder Notifications** – local notifications scheduling, daily reminders.
2. **Cloud Sync** – integrate Firebase Auth + Cloud Firestore for multi-device continuity.
3. **Android Build Pipeline** – configure signing, CI, device testing.
4. **Gamification Enhancements** – leaderboards, streak freezes, community challenges.
5. **Sharing & Notes** – allow sharing verses, taking notes/journal entries (stored locally first).

### Open Questions
- KJV is the initial default in the selector—is that acceptable for all markets/users?
- Are there privacy/compliance requirements (e.g., GDPR) before enabling cloud sync?
- Should reading plans be linear (book order) or curated (topic-based)?

This document should be kept up to date as architecture evolves (especially once Firebase/Android support is added).
