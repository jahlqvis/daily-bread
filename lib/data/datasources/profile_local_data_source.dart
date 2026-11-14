import 'dart:convert';

import '../models/user_model.dart';
import '../models/verse_bookmark_model.dart';
import 'local_data_source.dart';
import 'profile_storage.dart';

/// A fixed-profile LocalDataSource, not wired into the application.
///
/// Never imports legacy data or changes profiles. Reminder settings remain
/// device-local through the base class. Await writes before reading; the
/// serialization and durability limitations of ProfileStorage still apply.
/// Field clears do not remove other copies or constitute profile deletion.
class ProfileLocalDataSource extends LocalDataSource {
  ProfileLocalDataSource(super.prefs, this.profile)
    : _storage = ProfileStorage(prefs);

  final ProfileId profile;
  final ProfileStorage _storage;

  String? _string(ProfileField field) =>
      _storage.get(profile, field) as String?;
  int _int(ProfileField field) => _storage.get(profile, field) as int? ?? 0;
  DateTime? _date(ProfileField field) {
    final value = _string(field);
    return value == null || value.isEmpty ? null : DateTime.tryParse(value);
  }

  Future<void> _set(ProfileField field, Object value) =>
      _storage.set(profile, field, value);
  Future<void> _remove(ProfileField field) => _storage.remove(profile, field);
  Future<void> _saveDate(ProfileField field, DateTime value) =>
      _set(field, value.toIso8601String());

  @override
  Future<UserModel> getUser() async {
    final value = _string(ProfileField.userData);
    return value == null ? UserModel() : UserModel.fromJson(jsonDecode(value));
  }

  @override
  Future<void> saveUser(UserModel user) async {
    await _set(ProfileField.userData, jsonEncode(user.toJson()));
  }

  @override
  Future<void> clearUser() => _remove(ProfileField.userData);

  @override
  String? getActivePlanId() => _string(ProfileField.activePlanId);
  @override
  Future<void> saveActivePlanId(String planId) =>
      _set(ProfileField.activePlanId, planId);
  @override
  Future<void> clearActivePlanId() => _remove(ProfileField.activePlanId);

  @override
  DateTime? getActivePlanStartedAt() => _date(ProfileField.activePlanStartedAt);
  @override
  Future<void> saveActivePlanStartedAt(DateTime value) =>
      _saveDate(ProfileField.activePlanStartedAt, value);
  @override
  Future<void> clearActivePlanStartedAt() =>
      _remove(ProfileField.activePlanStartedAt);

  @override
  Set<String> getCompletedPlanRewardIds() {
    final ids =
        _storage.get(profile, ProfileField.completedPlanRewardIds)
            as List<String>?;
    return ids?.toSet() ?? <String>{};
  }

  @override
  Future<void> saveCompletedPlanRewardIds(Set<String> planIds) => _set(
    ProfileField.completedPlanRewardIds,
    planIds.toList(growable: false),
  );

  @override
  List<VerseBookmark> getBookmarks() {
    final value = _string(ProfileField.bookmarks);
    if (value == null || value.isEmpty) return const [];
    final decoded = jsonDecode(value);
    if (decoded is! List) return const [];
    return decoded
        .whereType<Map<String, dynamic>>()
        .map(VerseBookmark.fromJson)
        .toList(growable: false);
  }

  @override
  Future<void> saveBookmarks(List<VerseBookmark> bookmarks) async {
    await _set(
      ProfileField.bookmarks,
      jsonEncode(bookmarks.map((bookmark) => bookmark.toJson()).toList()),
    );
  }

  @override
  Future<void> clearBookmarks() => _remove(ProfileField.bookmarks);

  @override
  Map<String, DateTime> getBookmarkTombstones() {
    final value = _string(ProfileField.bookmarkTombstones);
    if (value == null || value.isEmpty) return const {};
    final decoded = jsonDecode(value);
    if (decoded is! Map) return const {};
    final tombstones = <String, DateTime>{};
    decoded.forEach((key, value) {
      final parsed = DateTime.tryParse(value?.toString() ?? '');
      if (parsed != null) tombstones[key.toString()] = parsed;
    });
    return tombstones;
  }

  @override
  Future<void> saveBookmarkTombstones(Map<String, DateTime> tombstones) async {
    await _set(
      ProfileField.bookmarkTombstones,
      jsonEncode(
        tombstones.map((key, value) => MapEntry(key, value.toIso8601String())),
      ),
    );
  }

  @override
  Future<void> clearBookmarkTombstones() =>
      _remove(ProfileField.bookmarkTombstones);

  @override
  String? getCloudSnapshot() => _string(ProfileField.cloudSnapshot);
  @override
  Future<void> saveCloudSnapshot(String snapshotJson) =>
      _set(ProfileField.cloudSnapshot, snapshotJson);
  @override
  DateTime? getCloudLastSyncedAt() => _date(ProfileField.cloudLastSyncedAt);
  @override
  Future<void> saveCloudLastSyncedAt(DateTime value) =>
      _saveDate(ProfileField.cloudLastSyncedAt, value);

  @override
  int getSyncSuccessCount() => _int(ProfileField.syncSuccessCount);
  @override
  Future<void> saveSyncSuccessCount(int value) =>
      _set(ProfileField.syncSuccessCount, value);
  @override
  int getSyncFailureCount() => _int(ProfileField.syncFailureCount);
  @override
  Future<void> saveSyncFailureCount(int value) =>
      _set(ProfileField.syncFailureCount, value);
  @override
  int getSyncRetryScheduledCount() =>
      _int(ProfileField.syncRetryScheduledCount);
  @override
  Future<void> saveSyncRetryScheduledCount(int value) =>
      _set(ProfileField.syncRetryScheduledCount, value);
  @override
  String? getSyncLastOutcome() => _string(ProfileField.syncLastOutcome);
  @override
  Future<void> saveSyncLastOutcome(String? value) =>
      value == null || value.isEmpty
      ? _remove(ProfileField.syncLastOutcome)
      : _set(ProfileField.syncLastOutcome, value);
  @override
  DateTime? getSyncLastOutcomeAt() => _date(ProfileField.syncLastOutcomeAt);
  @override
  Future<void> saveSyncLastOutcomeAt(DateTime? value) => value == null
      ? _remove(ProfileField.syncLastOutcomeAt)
      : _saveDate(ProfileField.syncLastOutcomeAt, value);
}
