import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// A device guest profile or an account profile identified by its exact UID.
class ProfileId {
  const ProfileId.guest() : _storageId = 'guest';

  factory ProfileId.account(String uid) {
    if (uid.isEmpty) throw ArgumentError.value(uid, 'uid', 'Must not be empty');
    // Encode code units directly so even unpaired surrogates remain distinct.
    final bytes = uid.codeUnits.expand((unit) => [unit >> 8, unit & 0xff]);
    return ProfileId._('account_${base64Url.encode(bytes.toList())}');
  }

  const ProfileId._(this._storageId);

  final String _storageId;
}

/// The profile-owned keys currently used by LocalDataSource. Values remain in
/// their original SharedPreferences representation; no model parsing is done.
enum ProfileField {
  userData('user_data'),
  activePlanId('active_plan_id'),
  activePlanStartedAt('active_plan_started_at'),
  completedPlanRewardIds('completed_plan_reward_ids'),
  bookmarks('verse_bookmarks'),
  bookmarkTombstones('verse_bookmark_tombstones'),
  cloudSnapshot('cloud_sync_snapshot'),
  cloudLastSyncedAt('cloud_last_synced_at'),
  syncSuccessCount('sync_success_count'),
  syncFailureCount('sync_failure_count'),
  syncRetryScheduledCount('sync_retry_scheduled_count'),
  syncLastOutcome('sync_last_outcome'),
  syncLastOutcomeAt('sync_last_outcome_at');

  const ProfileField(this.legacyKey);
  final String legacyKey;
}

enum LegacyMigrationResult { migrated, alreadyMigrated, noLegacyData }

/// Standalone storage foundation, not used by the current application yet.
///
/// Callers must resolve legacy ownership explicitly before migration. Never
/// infer it from the current login: the unscoped data may belong to someone
/// else. Migration reserves an immutable copy before writing the destination,
/// never removes originals, and refuses to merge into an existing profile.
/// An interrupted migration must be retried for the same owner before that
/// profile can be edited. Translation and reminder preferences are not copied.
///
/// Operations through this class are serialized within this Dart isolate only.
/// SharedPreferences is not transactional across isolates, processes, or other
/// writers; integration must coordinate all writers and stop legacy writes
/// before taking a migration snapshot. Await writes before relying on [get]:
/// synchronous reads are not serialized with in-flight writes. Storage is not
/// encrypted. A successful SharedPreferences write is not a guarantee of
/// crash-durable persistence.
class ProfileStorage {
  ProfileStorage(this._prefs);

  static const _prefix = 'profile_storage_v1_';
  static const _migrationKey = '${_prefix}legacy_migration';
  static Future<void> _queue = Future<void>.value();
  static final _cacheNeedsReload = <SharedPreferences>{};
  final SharedPreferences _prefs;

  static Future<T> _serialized<T>(Future<T> Function() action) {
    final result = _queue.then((_) => action());
    _queue = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  String _profileKey(ProfileId profile) =>
      '${_prefix}profile_${profile._storageId}';

  /// Returns a detached value, or null if the field has not been saved.
  Object? get(ProfileId profile, ProfileField field) {
    if (_cacheNeedsReload.contains(_prefs)) {
      throw StateError('Preferences cache must be reloaded before reading');
    }
    final data = _readProfile(profile)?['data'] as Map<String, dynamic>?;
    final value = data?[field.legacyKey];
    return value == null ? null : _copyValue(value);
  }

  /// Stores SharedPreferences-compatible primitives or a list of strings.
  Future<void> set(ProfileId profile, ProfileField field, Object value) =>
      _serialized(() async {
        await _ensureCache();
        _checkNotPending(profile);
        final document =
            _readProfile(profile) ??
            <String, dynamic>{'data': <String, dynamic>{}};
        final data = document['data'] as Map<String, dynamic>;
        data[field.legacyKey] = _copyValue(value);
        await _write(_profileKey(profile), jsonEncode(document));
      });

  Future<void> remove(ProfileId profile, ProfileField field) =>
      _serialized(() async {
        await _ensureCache();
        _checkNotPending(profile);
        final document = _readProfile(profile);
        if (document == null) return;
        (document['data'] as Map<String, dynamic>).remove(field.legacyKey);
        await _write(_profileKey(profile), jsonEncode(document));
      });

  /// Attributes all present legacy fields to [owner], only after the caller
  /// has established ownership. Never call this merely because a user signed in.
  Future<LegacyMigrationResult> migrateLegacy(
    ProfileId owner,
  ) => _serialized(() async {
    await _ensureCache();
    var record = _readDocument(_migrationKey);
    if (record != null) {
      if (record['owner'] != owner._storageId) {
        throw StateError('Legacy data is reserved for another profile');
      }
      if (record['complete'] == true) {
        return LegacyMigrationResult.alreadyMigrated;
      }
      if (record['complete'] != false ||
          record['data'] is! Map<String, dynamic>) {
        throw const FormatException('Invalid legacy migration record');
      }
    } else {
      if (_readProfile(owner) != null) {
        throw StateError('Cannot import legacy data into an existing profile');
      }
      final data = <String, dynamic>{};
      for (final field in ProfileField.values) {
        final value = _prefs.get(field.legacyKey);
        if (value != null) data[field.legacyKey] = _copyValue(value);
      }
      if (data.isEmpty) return LegacyMigrationResult.noLegacyData;
      record = {'owner': owner._storageId, 'complete': false, 'data': data};
      await _write(_migrationKey, jsonEncode(record));
    }

    final existing = _readProfile(owner);
    if (existing == null) {
      await _write(
        _profileKey(owner),
        jsonEncode({'data': record['data'], 'legacyImport': true}),
      );
    } else if (existing['legacyImport'] != true) {
      throw StateError('Cannot import legacy data into an existing profile');
    }
    record['complete'] = true;
    await _write(_migrationKey, jsonEncode(record));
    return LegacyMigrationResult.migrated;
  });

  void _checkNotPending(ProfileId profile) {
    final record = _readDocument(_migrationKey);
    if (record != null &&
        record['owner'] == profile._storageId &&
        record['complete'] != true) {
      throw StateError(
        'Retry the interrupted legacy migration before editing this profile',
      );
    }
  }

  Map<String, dynamic>? _readProfile(ProfileId profile) {
    final document = _readDocument(_profileKey(profile));
    if (document != null && document['data'] is! Map<String, dynamic>) {
      throw const FormatException('Invalid profile data');
    }
    return document;
  }

  Map<String, dynamic>? _readDocument(String key) {
    final raw = _prefs.getString(key);
    if (raw == null) return null;
    final document = jsonDecode(raw);
    if (document is! Map<String, dynamic>) {
      throw const FormatException('Invalid storage document');
    }
    return document;
  }

  static Object _copyValue(Object value) {
    if (value is String || value is bool || value is int) return value;
    if (value is double && value.isFinite) return value;
    if (value is List && value.every((item) => item is String)) {
      return List<String>.from(value);
    }
    throw ArgumentError.value(
      value,
      'value',
      'Unsupported SharedPreferences value',
    );
  }

  Future<void> _write(String key, String value) async {
    try {
      if (!await _prefs.setString(key, value)) {
        throw StateError('Could not save $key');
      }
    } catch (_) {
      // SharedPreferences may update its cache before the platform write fails.
      // Reconcile it so a retry does not mistake a failed write for success.
      _cacheNeedsReload.add(_prefs);
      await _ensureCache();
      rethrow;
    }
  }

  Future<void> _ensureCache() async {
    if (_cacheNeedsReload.contains(_prefs)) {
      await _prefs.reload();
      _cacheNeedsReload.remove(_prefs);
    }
  }
}
