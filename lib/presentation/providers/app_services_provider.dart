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
  String? _reminderMessage;
  String? _syncMessage;

  bool get isSyncing => _isSyncing;
  DateTime? get lastSyncedAt => _lastSyncedAt;
  bool get reminderEnabled => _reminderEnabled;
  String get reminderTime => _reminderTime;
  bool get reminderSupported => _dailyReminderService.isSupported;
  String? get reminderMessage => _reminderMessage;
  String? get syncMessage => _syncMessage;
  bool get cloudSyncAvailable => _cloudSyncService.isAvailable;
  String get cloudBackendLabel => _cloudSyncService.backendLabel;

  Future<void> syncNow({
    required UserModel user,
    required List<VerseBookmark> bookmarks,
  }) async {
    _isSyncing = true;
    _syncMessage = null;
    notifyListeners();

    final snapshot = CloudSyncSnapshot(
      syncedAt: DateTime.now(),
      user: user,
      bookmarks: bookmarks,
    );
    try {
      _lastSyncedAt = await _cloudSyncService.syncSnapshot(snapshot);
      _syncMessage = cloudSyncAvailable
          ? 'Synced to Firebase successfully'
          : 'Firebase not configured. Saved local backup instead.';
    } catch (_) {
      _syncMessage = 'Sync failed. Please try again.';
    }

    _isSyncing = false;
    notifyListeners();
  }

  void clearSyncMessage() {
    _syncMessage = null;
    notifyListeners();
  }

  Future<void> setReminderEnabled(bool enabled) async {
    try {
      await _dailyReminderService.setEnabled(enabled);
      _reminderEnabled = _dailyReminderService.isEnabled;
      _reminderMessage = _reminderEnabled
          ? 'Daily reminder enabled at $_reminderTime'
          : 'Daily reminder disabled';
    } catch (_) {
      _reminderEnabled = _dailyReminderService.isEnabled;
      _reminderMessage =
          'Could not enable reminders. Please allow notifications in Settings.';
    }
    notifyListeners();
  }

  Future<void> setReminderTime(String hhmm) async {
    try {
      await _dailyReminderService.setReminderTime(hhmm);
      _reminderTime = _dailyReminderService.reminderTime;
      _reminderMessage = _reminderEnabled
          ? 'Reminder moved to $_reminderTime'
          : 'Reminder time saved to $_reminderTime';
    } catch (_) {
      _reminderMessage = 'Could not update reminder time right now.';
    }
    notifyListeners();
  }

  void clearReminderMessage() {
    _reminderMessage = null;
    notifyListeners();
  }

  void _loadFromServices() {
    _lastSyncedAt = _cloudSyncService.getLastSyncedAt();
    _reminderEnabled = _dailyReminderService.isEnabled;
    _reminderTime = _dailyReminderService.reminderTime;
  }
}
