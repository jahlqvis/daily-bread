import 'dart:convert';

import '../../data/datasources/local_data_source.dart';
import '../../data/models/user_model.dart';
import '../../data/models/verse_bookmark_model.dart';

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
  Future<DateTime> syncSnapshot(CloudSyncSnapshot snapshot);
  DateTime? getLastSyncedAt();
}

class LocalCloudSyncService implements CloudSyncService {
  final LocalDataSource _localDataSource;

  LocalCloudSyncService(this._localDataSource);

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
