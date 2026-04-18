import 'package:flutter/foundation.dart';

import '../../data/models/user_model.dart';
import '../../data/models/verse_bookmark_model.dart';
import '../../services/cloud/cloud_sync_service.dart';
import '../../services/notifications/daily_reminder_service.dart';

class AppServicesProvider extends ChangeNotifier {
  final CloudSyncService _cloudSyncService;
  final DailyReminderService _dailyReminderService;

  AppServicesProvider(this._cloudSyncService, this._dailyReminderService) {
    _loadFromServices();
  }

  bool _isSyncing = false;
  DateTime? _lastSyncedAt;
  bool _reminderEnabled = false;
  String _reminderTime = '08:00';

  bool get isSyncing => _isSyncing;
  DateTime? get lastSyncedAt => _lastSyncedAt;
  bool get reminderEnabled => _reminderEnabled;
  String get reminderTime => _reminderTime;
  bool get reminderSupported => _dailyReminderService.isSupported;

  Future<void> syncNow({
    required UserModel user,
    required List<VerseBookmark> bookmarks,
  }) async {
    _isSyncing = true;
    notifyListeners();

    final snapshot = CloudSyncSnapshot(
      syncedAt: DateTime.now(),
      user: user,
      bookmarks: bookmarks,
    );
    _lastSyncedAt = await _cloudSyncService.syncSnapshot(snapshot);

    _isSyncing = false;
    notifyListeners();
  }

  Future<void> setReminderEnabled(bool enabled) async {
    await _dailyReminderService.setEnabled(enabled);
    _reminderEnabled = _dailyReminderService.isEnabled;
    notifyListeners();
  }

  Future<void> setReminderTime(String hhmm) async {
    await _dailyReminderService.setReminderTime(hhmm);
    _reminderTime = _dailyReminderService.reminderTime;
    notifyListeners();
  }

  void _loadFromServices() {
    _lastSyncedAt = _cloudSyncService.getLastSyncedAt();
    _reminderEnabled = _dailyReminderService.isEnabled;
    _reminderTime = _dailyReminderService.reminderTime;
  }
}
