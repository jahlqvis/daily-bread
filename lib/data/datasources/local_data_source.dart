import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../models/verse_bookmark_model.dart';

class LocalDataSource {
  static const String _userKey = 'user_data';
  static const String _activePlanIdKey = 'active_plan_id';
  static const String _activePlanStartedAtKey = 'active_plan_started_at';
  static const String _completedPlanRewardsKey = 'completed_plan_reward_ids';
  static const String _bookmarksKey = 'verse_bookmarks';
  static const String _bookmarkTombstonesKey = 'verse_bookmark_tombstones';
  static const String _cloudSnapshotKey = 'cloud_sync_snapshot';
  static const String _cloudLastSyncedAtKey = 'cloud_last_synced_at';
  static const String _dailyReminderEnabledKey = 'daily_reminder_enabled';
  static const String _dailyReminderTimeKey = 'daily_reminder_time';
  static const String _syncSuccessCountKey = 'sync_success_count';
  static const String _syncFailureCountKey = 'sync_failure_count';
  static const String _syncRetryScheduledCountKey = 'sync_retry_scheduled_count';
  static const String _syncLastOutcomeKey = 'sync_last_outcome';
  static const String _syncLastOutcomeAtKey = 'sync_last_outcome_at';
  final SharedPreferences _prefs;

  LocalDataSource(this._prefs);

  Future<UserModel> getUser() async {
    final jsonString = _prefs.getString(_userKey);
    if (jsonString == null) {
      return UserModel();
    }
    return UserModel.fromJson(json.decode(jsonString));
  }

  Future<void> saveUser(UserModel user) async {
    await _prefs.setString(_userKey, json.encode(user.toJson()));
  }

  Future<void> clearUser() async {
    await _prefs.remove(_userKey);
  }

  String? getActivePlanId() {
    return _prefs.getString(_activePlanIdKey);
  }

  Future<void> saveActivePlanId(String planId) async {
    await _prefs.setString(_activePlanIdKey, planId);
  }

  Future<void> clearActivePlanId() async {
    await _prefs.remove(_activePlanIdKey);
  }

  DateTime? getActivePlanStartedAt() {
    final iso = _prefs.getString(_activePlanStartedAtKey);
    if (iso == null || iso.isEmpty) {
      return null;
    }
    return DateTime.tryParse(iso);
  }

  Future<void> saveActivePlanStartedAt(DateTime value) async {
    await _prefs.setString(_activePlanStartedAtKey, value.toIso8601String());
  }

  Future<void> clearActivePlanStartedAt() async {
    await _prefs.remove(_activePlanStartedAtKey);
  }

  Set<String> getCompletedPlanRewardIds() {
    final ids = _prefs.getStringList(_completedPlanRewardsKey);
    if (ids == null) {
      return <String>{};
    }
    return ids.toSet();
  }

  Future<void> saveCompletedPlanRewardIds(Set<String> planIds) async {
    await _prefs.setStringList(
      _completedPlanRewardsKey,
      planIds.toList(growable: false),
    );
  }

  List<VerseBookmark> getBookmarks() {
    final jsonString = _prefs.getString(_bookmarksKey);
    if (jsonString == null || jsonString.isEmpty) {
      return const [];
    }

    final decoded = jsonDecode(jsonString);
    if (decoded is! List) {
      return const [];
    }

    return decoded
        .whereType<Map<String, dynamic>>()
        .map(VerseBookmark.fromJson)
        .toList(growable: false);
  }

  Future<void> saveBookmarks(List<VerseBookmark> bookmarks) async {
    final payload = bookmarks.map((bookmark) => bookmark.toJson()).toList();
    await _prefs.setString(_bookmarksKey, jsonEncode(payload));
  }

  Future<void> clearBookmarks() async {
    await _prefs.remove(_bookmarksKey);
  }

  Map<String, DateTime> getBookmarkTombstones() {
    final jsonString = _prefs.getString(_bookmarkTombstonesKey);
    if (jsonString == null || jsonString.isEmpty) {
      return const {};
    }

    final decoded = jsonDecode(jsonString);
    if (decoded is! Map) {
      return const {};
    }

    final tombstones = <String, DateTime>{};
    decoded.forEach((key, value) {
      final parsed = DateTime.tryParse(value?.toString() ?? '');
      if (parsed != null) {
        tombstones[key.toString()] = parsed;
      }
    });
    return tombstones;
  }

  Future<void> saveBookmarkTombstones(Map<String, DateTime> tombstones) async {
    final payload = tombstones.map(
      (key, value) => MapEntry(key, value.toIso8601String()),
    );
    await _prefs.setString(_bookmarkTombstonesKey, jsonEncode(payload));
  }

  Future<void> clearBookmarkTombstones() async {
    await _prefs.remove(_bookmarkTombstonesKey);
  }

  String? getCloudSnapshot() {
    return _prefs.getString(_cloudSnapshotKey);
  }

  Future<void> saveCloudSnapshot(String snapshotJson) async {
    await _prefs.setString(_cloudSnapshotKey, snapshotJson);
  }

  DateTime? getCloudLastSyncedAt() {
    final iso = _prefs.getString(_cloudLastSyncedAtKey);
    if (iso == null || iso.isEmpty) {
      return null;
    }
    return DateTime.tryParse(iso);
  }

  Future<void> saveCloudLastSyncedAt(DateTime value) async {
    await _prefs.setString(_cloudLastSyncedAtKey, value.toIso8601String());
  }

  bool isDailyReminderEnabled() {
    return _prefs.getBool(_dailyReminderEnabledKey) ?? false;
  }

  Future<void> saveDailyReminderEnabled(bool enabled) async {
    await _prefs.setBool(_dailyReminderEnabledKey, enabled);
  }

  String getDailyReminderTime() {
    return _prefs.getString(_dailyReminderTimeKey) ?? '08:00';
  }

  Future<void> saveDailyReminderTime(String value) async {
    await _prefs.setString(_dailyReminderTimeKey, value);
  }

  int getSyncSuccessCount() {
    return _prefs.getInt(_syncSuccessCountKey) ?? 0;
  }

  Future<void> saveSyncSuccessCount(int value) async {
    await _prefs.setInt(_syncSuccessCountKey, value);
  }

  int getSyncFailureCount() {
    return _prefs.getInt(_syncFailureCountKey) ?? 0;
  }

  Future<void> saveSyncFailureCount(int value) async {
    await _prefs.setInt(_syncFailureCountKey, value);
  }

  int getSyncRetryScheduledCount() {
    return _prefs.getInt(_syncRetryScheduledCountKey) ?? 0;
  }

  Future<void> saveSyncRetryScheduledCount(int value) async {
    await _prefs.setInt(_syncRetryScheduledCountKey, value);
  }

  String? getSyncLastOutcome() {
    return _prefs.getString(_syncLastOutcomeKey);
  }

  Future<void> saveSyncLastOutcome(String? value) async {
    if (value == null || value.isEmpty) {
      await _prefs.remove(_syncLastOutcomeKey);
      return;
    }
    await _prefs.setString(_syncLastOutcomeKey, value);
  }

  DateTime? getSyncLastOutcomeAt() {
    final iso = _prefs.getString(_syncLastOutcomeAtKey);
    if (iso == null || iso.isEmpty) {
      return null;
    }
    return DateTime.tryParse(iso);
  }

  Future<void> saveSyncLastOutcomeAt(DateTime? value) async {
    if (value == null) {
      await _prefs.remove(_syncLastOutcomeAtKey);
      return;
    }
    await _prefs.setString(_syncLastOutcomeAtKey, value.toIso8601String());
  }
}
