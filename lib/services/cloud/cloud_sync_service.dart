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

  FirebaseCloudSyncService({
    required LocalDataSource localDataSource,
    required FirebaseBackendConfig config,
    required CloudSyncService fallback,
    FirebaseAuth? firebaseAuth,
    FirebaseFirestore? firebaseFirestore,
  }) : _localDataSource = localDataSource,
       _config = config,
       _fallback = fallback,
       _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
       _firebaseFirestore = firebaseFirestore ?? FirebaseFirestore.instance;

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
      final syncedAt = snapshot.syncedAt.toUtc();
      final syncTime = Timestamp.fromDate(syncedAt);

      final userDoc = _firebaseFirestore.collection('users').doc(user.uid);
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

      await _localDataSource.saveCloudSnapshot(jsonEncode(snapshot.toJson()));
      await _localDataSource.saveCloudLastSyncedAt(snapshot.syncedAt);
      return snapshot.syncedAt;
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
}
