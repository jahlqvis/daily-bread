import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../../data/datasources/local_data_source.dart';
import '../../data/models/user_model.dart';
import '../../data/models/verse_bookmark_model.dart';
import 'firebase_backend_config.dart';

class CloudSyncSnapshot {
  final DateTime syncedAt;
  final UserModel user;
  final List<VerseBookmark> bookmarks;

  const CloudSyncSnapshot({
    required this.syncedAt,
    required this.user,
    required this.bookmarks,
  });

  Map<String, dynamic> toJson() {
    return {
      'syncedAt': syncedAt.toIso8601String(),
      'user': user.toJson(),
      'bookmarks': bookmarks.map((bookmark) => bookmark.toJson()).toList(),
    };
  }

  factory CloudSyncSnapshot.fromJson(Map<String, dynamic> json) {
    final bookmarksJson = (json['bookmarks'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);

    return CloudSyncSnapshot(
      syncedAt:
          DateTime.tryParse(json['syncedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      user: UserModel.fromJson(
        (json['user'] as Map<String, dynamic>?) ?? const <String, dynamic>{},
      ),
      bookmarks: bookmarksJson
          .map(VerseBookmark.fromJson)
          .toList(growable: false),
    );
  }
}

class CloudSyncMerger {
  const CloudSyncMerger._();

  static CloudSyncSnapshot merge({
    required CloudSyncSnapshot local,
    CloudSyncSnapshot? remote,
  }) {
    if (remote == null) {
      return local;
    }

    final mergedSyncedAt = local.syncedAt.isAfter(remote.syncedAt)
        ? local.syncedAt
        : remote.syncedAt;

    return CloudSyncSnapshot(
      syncedAt: mergedSyncedAt,
      user: mergeUsers(local.user, remote.user),
      bookmarks: mergeBookmarks(local.bookmarks, remote.bookmarks),
    );
  }

  static UserModel mergeUsers(UserModel local, UserModel remote) {
    final localLastRead = local.lastReadDate;
    final remoteLastRead = remote.lastReadDate;
    final latestLastRead = _maxDate(localLastRead, remoteLastRead);
    final remoteIsNewer = _isRemoteNewer(localLastRead, remoteLastRead);

    final mergedProgress = <String, Set<int>>{};
    for (final entry in local.readingProgress.entries) {
      mergedProgress[entry.key] = {...entry.value};
    }
    for (final entry in remote.readingProgress.entries) {
      mergedProgress.update(
        entry.key,
        (existing) => {...existing, ...entry.value},
        ifAbsent: () => {...entry.value},
      );
    }

    final mergedBadges = <String>{...local.badges, ...remote.badges}.toList()
      ..sort();

    return UserModel(
      currentStreak: remoteIsNewer ? remote.currentStreak : local.currentStreak,
      longestStreak: local.longestStreak > remote.longestStreak
          ? local.longestStreak
          : remote.longestStreak,
      totalXp: local.totalXp > remote.totalXp ? local.totalXp : remote.totalXp,
      level: local.level > remote.level ? local.level : remote.level,
      badges: mergedBadges,
      lastReadDate: latestLastRead,
      readingProgress: mergedProgress,
      streakFreezes: remoteIsNewer ? remote.streakFreezes : local.streakFreezes,
    );
  }

  static List<VerseBookmark> mergeBookmarks(
    List<VerseBookmark> local,
    List<VerseBookmark> remote,
  ) {
    final byId = <String, VerseBookmark>{};
    final localById = {for (final bookmark in local) bookmark.id: bookmark};
    final remoteById = {for (final bookmark in remote) bookmark.id: bookmark};
    final allIds = <String>{...localById.keys, ...remoteById.keys};

    for (final id in allIds) {
      final localBookmark = localById[id];
      final remoteBookmark = remoteById[id];

      if (localBookmark != null && remoteBookmark != null) {
        byId[id] = remoteBookmark.createdAt.isAfter(localBookmark.createdAt)
            ? remoteBookmark
            : localBookmark;
      } else {
        byId[id] = localBookmark ?? remoteBookmark!;
      }
    }

    final merged = byId.values.toList(growable: false)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return merged;
  }

  static DateTime? _maxDate(DateTime? a, DateTime? b) {
    if (a == null) {
      return b;
    }
    if (b == null) {
      return a;
    }
    return a.isAfter(b) ? a : b;
  }

  static bool _isRemoteNewer(DateTime? local, DateTime? remote) {
    if (remote == null) {
      return false;
    }
    if (local == null) {
      return true;
    }
    return remote.isAfter(local);
  }
}

abstract class CloudSyncService {
  bool get isAvailable;
  String get backendLabel;

  Future<void> initialize();
  Future<DateTime> syncSnapshot(CloudSyncSnapshot snapshot);
  DateTime? getLastSyncedAt();
}

class LocalCloudSyncService implements CloudSyncService {
  final LocalDataSource _localDataSource;

  LocalCloudSyncService(this._localDataSource);

  @override
  bool get isAvailable => true;

  @override
  String get backendLabel => 'Local backup';

  @override
  Future<void> initialize() async {}

  @override
  Future<DateTime> syncSnapshot(CloudSyncSnapshot snapshot) async {
    await _localDataSource.saveCloudSnapshot(jsonEncode(snapshot.toJson()));
    await _localDataSource.saveCloudLastSyncedAt(snapshot.syncedAt);
    return snapshot.syncedAt;
  }

  @override
  DateTime? getLastSyncedAt() {
    return _localDataSource.getCloudLastSyncedAt();
  }
}

class FirebaseCloudSyncService implements CloudSyncService {
  final LocalDataSource _localDataSource;
  final FirebaseBackendConfig _config;
  final CloudSyncService _fallback;
  final FirebaseAuth _firebaseAuth;
  final FirebaseFirestore _firebaseFirestore;

  bool _initialized = false;
  bool _isAvailable = false;
  final DateTime Function() _nowProvider;

  FirebaseCloudSyncService({
    required LocalDataSource localDataSource,
    required FirebaseBackendConfig config,
    required CloudSyncService fallback,
    FirebaseAuth? firebaseAuth,
    FirebaseFirestore? firebaseFirestore,
    DateTime Function()? nowProvider,
  }) : _localDataSource = localDataSource,
       _config = config,
       _fallback = fallback,
       _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
       _firebaseFirestore = firebaseFirestore ?? FirebaseFirestore.instance,
       _nowProvider = nowProvider ?? DateTime.now;

  @override
  bool get isAvailable => _isAvailable;

  @override
  String get backendLabel {
    return _isAvailable ? 'Firebase' : _fallback.backendLabel;
  }

  @override
  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    _initialized = true;
    final options = _config.optionsForPlatform(defaultTargetPlatform);
    if (options == null) {
      _isAvailable = false;
      await _fallback.initialize();
      return;
    }

    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(options: options);
      }

      await _ensureSignedIn();
      _isAvailable = true;
    } catch (_) {
      _isAvailable = false;
      await _fallback.initialize();
    }
  }

  @override
  Future<DateTime> syncSnapshot(CloudSyncSnapshot snapshot) async {
    await initialize();

    if (!_isAvailable) {
      return _fallback.syncSnapshot(snapshot);
    }

    try {
      final user = await _ensureSignedIn();
      final remote = await _loadRemoteSnapshot(user.uid);
      final merged = CloudSyncMerger.merge(local: snapshot, remote: remote);
      final syncedSnapshot = CloudSyncSnapshot(
        syncedAt: _nowProvider(),
        user: merged.user,
        bookmarks: merged.bookmarks,
      );

      await _saveRemoteSnapshot(user.uid, syncedSnapshot);
      await _localDataSource.saveUser(syncedSnapshot.user);
      await _localDataSource.saveBookmarks(syncedSnapshot.bookmarks);
      await _localDataSource.saveCloudSnapshot(
        jsonEncode(syncedSnapshot.toJson()),
      );
      await _localDataSource.saveCloudLastSyncedAt(syncedSnapshot.syncedAt);
      return syncedSnapshot.syncedAt;
    } catch (_) {
      return _fallback.syncSnapshot(snapshot);
    }
  }

  @override
  DateTime? getLastSyncedAt() {
    return _localDataSource.getCloudLastSyncedAt() ??
        _fallback.getLastSyncedAt();
  }

  Future<User> _ensureSignedIn() async {
    final current = _firebaseAuth.currentUser;
    if (current != null) {
      return current;
    }

    final credential = await _firebaseAuth.signInAnonymously();
    return credential.user!;
  }

  Future<CloudSyncSnapshot?> _loadRemoteSnapshot(String uid) async {
    final userDoc = _firebaseFirestore.collection('users').doc(uid);
    final userDocSnapshot = await userDoc.get();
    if (!userDocSnapshot.exists) {
      return null;
    }

    final userData = userDocSnapshot.data();
    if (userData == null) {
      return null;
    }

    final userJson = _toStringKeyMap(userData['user']);
    final lastClientSyncAt = userData['lastClientSyncAt'];
    final syncAt = lastClientSyncAt is Timestamp
        ? lastClientSyncAt.toDate()
        : DateTime.fromMillisecondsSinceEpoch(0);

    final bookmarksSnapshot = await userDoc.collection('bookmarks').get();
    final bookmarks = <VerseBookmark>[];
    for (final doc in bookmarksSnapshot.docs) {
      final data = doc.data();
      final deletedAt = data['deletedAt'];
      if (deletedAt != null) {
        continue;
      }

      try {
        final bookmarkJson = Map<String, dynamic>.from(data)
          ..remove('updatedAt')
          ..remove('deletedAt');
        bookmarks.add(VerseBookmark.fromJson(bookmarkJson));
      } catch (_) {
        continue;
      }
    }

    return CloudSyncSnapshot(
      syncedAt: syncAt,
      user: UserModel.fromJson(userJson),
      bookmarks: bookmarks,
    );
  }

  Future<void> _saveRemoteSnapshot(
    String uid,
    CloudSyncSnapshot snapshot,
  ) async {
    final userDoc = _firebaseFirestore.collection('users').doc(uid);
    final syncTime = Timestamp.fromDate(snapshot.syncedAt.toUtc());
    final batch = _firebaseFirestore.batch();

    batch.set(userDoc, {
      'user': snapshot.user.toJson(),
      'lastClientSyncAt': syncTime,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    for (final bookmark in snapshot.bookmarks) {
      final bookmarkDoc = userDoc.collection('bookmarks').doc(bookmark.id);
      batch.set(bookmarkDoc, {
        ...bookmark.toJson(),
        'updatedAt': syncTime,
        'deletedAt': null,
      }, SetOptions(merge: true));
    }

    await batch.commit();
  }

  Map<String, dynamic> _toStringKeyMap(Object? value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.map((key, mapValue) => MapEntry(key.toString(), mapValue));
    }
    return const <String, dynamic>{};
  }
}
