import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

enum ProfileTransitionKind { account, signOut }

enum ProfileTransitionStatus { pending, committed }

/// An explicit decision, not evidence of ownership or permission to migrate
/// ambiguous legacy data. The caller must separately identify the source.
enum ProfileTransitionChoice { importLocal, keepSeparate, keepCopy, removeCopy }

class ProfileTransitionRecord {
  const ProfileTransitionRecord._({
    required this.id,
    required this.uid,
    required this.kind,
    required this.status,
    required this.choice,
  });

  final String id;
  final String uid;
  final ProfileTransitionKind kind;
  final ProfileTransitionStatus status;

  /// Null means a decision is still required; it is never implicit consent.
  final ProfileTransitionChoice? choice;

  Map<String, Object?> _toJson() => {
    'version': 1,
    'id': id,
    'uid': uid,
    'kind': kind.name,
    'status': status.name,
    'choice': choice?.name,
  };
}

/// A standalone decision journal; not connected to the app or sync.
///
/// Each update replaces one complete record under one preferences key. A
/// committed record means only that the caller declared completion, not that
/// any profile, authentication, cloud, or deletion operation succeeded. This
/// journal never performs those operations or attributes legacy data. IDs must
/// strictly increase in Dart string order on this installation and be retained
/// across retries. Only the latest record is retained; old decisions are not a
/// history or a durable consent grant.
///
/// Calls are serialized across journal instances in this isolate and reload the
/// preferences cache before every operation, including after failed writes.
/// SharedPreferences offers neither transactions nor compare-and-swap across
/// isolates/processes, and a successful write is not a crash-durability
/// guarantee. Future integration must synchronize *all* writers across
/// isolates/processes, stop legacy writes and fence in-flight/queued sync and
/// account operations, and reconcile external side effects on recovery. A
/// stronger transactional store is required for stronger durability guarantees.
/// Data is not encrypted. No safety claim is made for other writers or clients.
class ProfileTransitionJournal {
  ProfileTransitionJournal(this._prefs);

  static const storageKey = 'profile_transition_journal_v1';
  static Future<void> _queue = Future<void>.value();
  final SharedPreferences _prefs;

  static Future<T> _serialized<T>(Future<T> Function() action) {
    final result = _queue.then((_) => action());
    _queue = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<ProfileTransitionRecord?> read() => _serialized(() async {
    await _prefs.reload();
    return _read();
  });

  /// Starts a transition or retries the exact same pending transition. A new
  /// transition cannot replace a pending one. A new [id] must be strictly
  /// greater than the latest ID using [String.compareTo]; old IDs are rejected.
  Future<ProfileTransitionRecord> begin({
    required String id,
    required String uid,
    required ProfileTransitionKind kind,
  }) => _serialized(() async {
    _validateIdentity(id, uid);
    await _prefs.reload();
    final current = _read();
    if (current != null) {
      if (current.id == id &&
          current.uid == uid &&
          current.kind == kind &&
          current.status == ProfileTransitionStatus.pending) {
        return current;
      }
      if (id.compareTo(current.id) <= 0 ||
          current.status == ProfileTransitionStatus.pending) {
        throw StateError(
          'Stale transition ID or another transition is pending',
        );
      }
    }
    final next = ProfileTransitionRecord._(
      id: id,
      uid: uid,
      kind: kind,
      status: ProfileTransitionStatus.pending,
      choice: null,
    );
    await _write(next);
    return next;
  });

  /// Records one explicit choice. Retrying the identical pending choice is
  /// safe; changing it requires a separately designed cancellation flow.
  Future<ProfileTransitionRecord> choose({
    required String id,
    required String uid,
    required ProfileTransitionChoice choice,
  }) => _serialized(() async {
    await _prefs.reload();
    final current = _require(id, uid);
    if (current.status != ProfileTransitionStatus.pending ||
        !_allowed(current.kind, choice)) {
      throw StateError('Invalid choice or transition status');
    }
    if (current.choice == choice) return current;
    if (current.choice != null) throw StateError('Choice already recorded');
    final next = ProfileTransitionRecord._(
      id: current.id,
      uid: current.uid,
      kind: current.kind,
      status: current.status,
      choice: choice,
    );
    await _write(next);
    return next;
  });

  /// Records the caller's declaration of completion, not proof of effects.
  /// Retrying an identical commit is safe while this is the latest record.
  Future<ProfileTransitionRecord> commit({
    required String id,
    required String uid,
  }) => _serialized(() async {
    await _prefs.reload();
    final current = _require(id, uid);
    if (current.choice == null) throw StateError('Explicit choice required');
    if (current.status == ProfileTransitionStatus.committed) return current;
    final next = ProfileTransitionRecord._(
      id: current.id,
      uid: current.uid,
      kind: current.kind,
      status: ProfileTransitionStatus.committed,
      choice: current.choice,
    );
    await _write(next);
    return next;
  });

  ProfileTransitionRecord _require(String id, String uid) {
    _validateIdentity(id, uid);
    final current = _read();
    if (current == null || current.id != id || current.uid != uid) {
      throw StateError('Unexpected transition ID or account UID');
    }
    return current;
  }

  static void _validateIdentity(String id, String uid) {
    if (id.isEmpty || uid.isEmpty) {
      throw ArgumentError('Transition ID and account UID must not be empty');
    }
  }

  static bool _allowed(
    ProfileTransitionKind kind,
    ProfileTransitionChoice choice,
  ) => switch (kind) {
    ProfileTransitionKind.account =>
      choice == ProfileTransitionChoice.importLocal ||
          choice == ProfileTransitionChoice.keepSeparate,
    ProfileTransitionKind.signOut =>
      choice == ProfileTransitionChoice.keepCopy ||
          choice == ProfileTransitionChoice.removeCopy,
  };

  ProfileTransitionRecord? _read() {
    final raw = _prefs.get(storageKey);
    if (raw == null) return null;
    if (raw is! String) throw const FormatException('Invalid journal value');
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      throw const FormatException('Invalid journal JSON');
    }
    // Accept only a canonical encoding. This rejects
    // duplicate keys, alternate encodings, and unknown additions fail-closed.
    if (decoded is! Map<String, dynamic> ||
        jsonEncode(decoded) != raw ||
        decoded.length != 6 ||
        decoded.keys.toSet().difference({
          'version',
          'id',
          'uid',
          'kind',
          'status',
          'choice',
        }).isNotEmpty ||
        decoded['version'] is! int ||
        decoded['version'] != 1 ||
        decoded['id'] is! String ||
        (decoded['id'] as String).isEmpty ||
        decoded['uid'] is! String ||
        (decoded['uid'] as String).isEmpty) {
      throw const FormatException('Invalid journal record');
    }
    final kindName = decoded['kind'];
    final statusName = decoded['status'];
    final choiceName = decoded['choice'];
    final kind = ProfileTransitionKind.values
        .where((e) => e.name == kindName)
        .firstOrNull;
    final status = ProfileTransitionStatus.values
        .where((e) => e.name == statusName)
        .firstOrNull;
    final choice = ProfileTransitionChoice.values
        .where((e) => e.name == choiceName)
        .firstOrNull;
    if (kind == null ||
        status == null ||
        (decoded['choice'] != null && choice == null) ||
        (choice != null && !_allowed(kind, choice)) ||
        (status == ProfileTransitionStatus.committed && choice == null)) {
      throw const FormatException('Invalid journal state');
    }
    return ProfileTransitionRecord._(
      id: decoded['id'] as String,
      uid: decoded['uid'] as String,
      kind: kind,
      status: status,
      choice: choice,
    );
  }

  Future<void> _write(ProfileTransitionRecord record) async {
    if (!await _prefs.setString(storageKey, jsonEncode(record._toJson()))) {
      throw StateError('Could not save transition journal');
    }
  }
}
