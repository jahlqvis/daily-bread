import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../../data/models/user_model.dart';
import '../../data/models/verse_bookmark_model.dart';
import '../../services/cloud/cloud_sync_service.dart';
import '../../services/notifications/daily_reminder_service.dart';

enum SyncStatus { idle, pending, syncing, retrying, failed }

abstract class SyncConnectivity {
  Future<bool> get isOffline;
  Stream<bool> get onOfflineChanged;
}

class DeviceSyncConnectivity implements SyncConnectivity {
  final Connectivity _connectivity;

  DeviceSyncConnectivity(this._connectivity);

  @override
  Future<bool> get isOffline async {
    final results = await _connectivity.checkConnectivity();
    return _isOfflineFromResults(results);
  }

  @override
  Stream<bool> get onOfflineChanged {
    return _connectivity.onConnectivityChanged.map(_isOfflineFromResults);
  }

  bool _isOfflineFromResults(List<ConnectivityResult> results) {
    return results.isEmpty ||
        results.every((result) => result == ConnectivityResult.none);
  }
}

class _SyncRequest {
  final CloudSyncSnapshot snapshot;
  final String reason;
  final Future<void> Function()? onSynced;

  const _SyncRequest({
    required this.snapshot,
    required this.reason,
    this.onSynced,
  });
}

class AppServicesProvider extends ChangeNotifier {
  static const Duration _baseRetryDelay = Duration(seconds: 2);
  static const Duration _maxRetryDelay = Duration(minutes: 5);
  static const int _maxRetryAttempts = 8;

  final CloudSyncService _cloudSyncService;
  final DailyReminderService _dailyReminderService;
  final SyncConnectivity _syncConnectivity;

  AppServicesProvider(
    this._cloudSyncService,
    this._dailyReminderService, {
    SyncConnectivity? syncConnectivity,
  }) : _syncConnectivity =
           syncConnectivity ?? DeviceSyncConnectivity(Connectivity()) {
    _loadFromServices();
    _connectivityReady = _bootstrapConnectivity();
  }

  bool _isSyncing = false;
  DateTime? _lastSyncedAt;
  bool _reminderEnabled = false;
  String _reminderTime = '08:00';
  String? _reminderMessage;
  String? _syncMessage;

  SyncStatus _syncStatus = SyncStatus.idle;
  int _retryCount = 0;
  DateTime? _nextRetryAt;
  DateTime? _lastSyncAttemptAt;
  DateTime? _lastSyncSuccessAt;
  String? _lastSyncErrorCode;
  String? _lastSyncErrorMessage;
  bool _isOffline = false;
  Timer? _retryTimer;
  StreamSubscription<bool>? _connectivitySubscription;
  _SyncRequest? _queuedSyncRequest;
  late final Future<void> _connectivityReady;

  int _syncSuccessCount = 0;
  int _syncFailureCount = 0;
  int _syncRetryScheduledCount = 0;

  bool get isSyncing => _isSyncing;
  DateTime? get lastSyncedAt => _lastSyncedAt;
  bool get reminderEnabled => _reminderEnabled;
  String get reminderTime => _reminderTime;
  bool get reminderSupported => _dailyReminderService.isSupported;
  String? get reminderMessage => _reminderMessage;
  String? get syncMessage => _syncMessage;
  bool get cloudSyncAvailable => _cloudSyncService.isAvailable;
  String get cloudBackendLabel => _cloudSyncService.backendLabel;

  SyncStatus get syncStatus => _syncStatus;
  int get retryCount => _retryCount;
  DateTime? get nextRetryAt => _nextRetryAt;
  DateTime? get lastSyncAttemptAt => _lastSyncAttemptAt;
  DateTime? get lastSyncSuccessAt => _lastSyncSuccessAt;
  String? get lastSyncErrorCode => _lastSyncErrorCode;
  String? get lastSyncErrorMessage => _lastSyncErrorMessage;
  bool get isOffline => _isOffline;
  int get syncSuccessCount => _syncSuccessCount;
  int get syncFailureCount => _syncFailureCount;
  int get syncRetryScheduledCount => _syncRetryScheduledCount;

  Future<void> syncNow({
    required UserModel user,
    required List<VerseBookmark> bookmarks,
    Map<String, DateTime> tombstones = const {},
    String reason = 'manual',
    Future<void> Function()? onSynced,
  }) async {
    await requestSync(
      user: user,
      bookmarks: bookmarks,
      tombstones: tombstones,
      reason: reason,
      immediate: true,
      onSynced: onSynced,
    );
  }

  Future<void> requestSync({
    required UserModel user,
    required List<VerseBookmark> bookmarks,
    Map<String, DateTime> tombstones = const {},
    required String reason,
    bool immediate = false,
    Future<void> Function()? onSynced,
  }) async {
    await _connectivityReady;

    _queuedSyncRequest = _SyncRequest(
      snapshot: CloudSyncSnapshot(
        syncedAt: DateTime.now(),
        user: user,
        bookmarks: bookmarks,
        tombstones: tombstones,
      ),
      reason: reason,
      onSynced: onSynced,
    );

    if (_isSyncing) {
      _syncStatus = SyncStatus.pending;
      _syncMessage = 'Sync pending...';
      notifyListeners();
      return;
    }

    if (_isOffline) {
      _setOfflinePendingState();
      return;
    }

    if (immediate) {
      _cancelRetry();
      _retryCount = 0;
      _nextRetryAt = null;
      await _drainSyncQueue();
      return;
    }

    _syncStatus = SyncStatus.pending;
    _syncMessage = 'Sync pending...';
    notifyListeners();
    await _drainSyncQueue();
  }

  Future<void> _drainSyncQueue() async {
    if (_isSyncing || _isOffline) {
      return;
    }

    while (_queuedSyncRequest != null && !_isOffline) {
      final request = _queuedSyncRequest!;
      _queuedSyncRequest = null;

      _isSyncing = true;
      _syncStatus = SyncStatus.syncing;
      _lastSyncAttemptAt = DateTime.now();
      _syncMessage = 'Syncing...';
      notifyListeners();

      try {
        _lastSyncedAt = await _cloudSyncService.syncSnapshot(request.snapshot);
        _lastSyncSuccessAt = _lastSyncedAt;
        _lastSyncErrorCode = null;
        _lastSyncErrorMessage = null;
        _retryCount = 0;
        _nextRetryAt = null;
        _cancelRetry();
        _syncStatus = SyncStatus.idle;
        _syncMessage = cloudSyncAvailable
            ? 'Synced to Firebase successfully'
            : 'Firebase not configured. Saved local backup instead.';
        _syncSuccessCount += 1;
        notifyListeners();

        if (request.onSynced != null) {
          await request.onSynced!();
        }
      } catch (error) {
        final retryable = _isRetryableError(error);
        _lastSyncErrorCode = _syncErrorCode(error);
        _lastSyncErrorMessage = error.toString();
        _syncFailureCount += 1;

        if (!retryable) {
          _retryCount = 0;
          _nextRetryAt = null;
          _syncStatus = SyncStatus.failed;
          _syncMessage = 'Sync failed. Please try again.';
          notifyListeners();
          _isSyncing = false;
          return;
        }

        _queuedSyncRequest ??= request;

        _retryCount += 1;
        if (_retryCount > _maxRetryAttempts) {
          _syncStatus = SyncStatus.failed;
          _syncMessage = 'Sync failed after retries. Please sync manually.';
          _nextRetryAt = null;
          notifyListeners();
          _isSyncing = false;
          return;
        }

        final delay = _retryDelayForAttempt(_retryCount);
        _nextRetryAt = DateTime.now().add(delay);
        _syncStatus = _isOffline ? SyncStatus.pending : SyncStatus.retrying;
        _syncMessage = _isOffline
            ? 'Offline. Sync will retry when online.'
            : 'Sync retry scheduled in ${delay.inSeconds}s.';
        _syncRetryScheduledCount += 1;
        notifyListeners();

        _scheduleRetry(delay);
        _isSyncing = false;
        return;
      } finally {
        if (_syncStatus == SyncStatus.idle ||
            _syncStatus == SyncStatus.syncing) {
          _isSyncing = false;
        }
      }
    }
  }

  void _scheduleRetry(Duration delay) {
    _cancelRetry();
    _retryTimer = Timer(delay, () {
      unawaited(_drainSyncQueue());
    });
  }

  void _cancelRetry() {
    _retryTimer?.cancel();
    _retryTimer = null;
  }

  Duration _retryDelayForAttempt(int attempt) {
    final multiplier = 1 << (attempt - 1);
    final raw = _baseRetryDelay * multiplier;
    return raw > _maxRetryDelay ? _maxRetryDelay : raw;
  }

  bool _isRetryableError(Object error) {
    if (error is TimeoutException) {
      return true;
    }

    if (error is FirebaseException) {
      final code = error.code.toLowerCase();
      return {
        'unavailable',
        'deadline-exceeded',
        'resource-exhausted',
        'internal',
        'aborted',
        'unknown',
        'network-request-failed',
      }.contains(code);
    }

    final message = error.toString().toLowerCase();
    return message.contains('timeout') ||
        message.contains('socketexception') ||
        message.contains('network') ||
        message.contains('unavailable') ||
        message.contains('503') ||
        message.contains('502') ||
        message.contains('504') ||
        message.contains('429');
  }

  String _syncErrorCode(Object error) {
    if (error is FirebaseException) {
      return error.code;
    }
    if (error is TimeoutException) {
      return 'timeout';
    }
    return 'unknown';
  }

  Future<void> _bootstrapConnectivity() async {
    _isOffline = await _syncConnectivity.isOffline;
    if (_isOffline) {
      _setOfflinePendingState(notify: false);
    }

    _connectivitySubscription = _syncConnectivity.onOfflineChanged.listen((
      offline,
    ) {
      final previous = _isOffline;
      _isOffline = offline;

      if (_isOffline) {
        _setOfflinePendingState();
        return;
      }

      if (previous && _queuedSyncRequest != null) {
        _syncStatus = SyncStatus.pending;
        _syncMessage = 'Back online. Sync pending...';
        notifyListeners();
        _cancelRetry();
        unawaited(_drainSyncQueue());
        return;
      }

      notifyListeners();
    });
  }

  void _setOfflinePendingState({bool notify = true}) {
    _syncStatus = _queuedSyncRequest == null
        ? SyncStatus.idle
        : SyncStatus.pending;
    if (_queuedSyncRequest != null) {
      _syncMessage = 'Offline. Sync pending until connection returns.';
    }
    if (notify) {
      notifyListeners();
    }
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
    _lastSyncSuccessAt = _lastSyncedAt;
    _reminderEnabled = _dailyReminderService.isEnabled;
    _reminderTime = _dailyReminderService.reminderTime;
  }

  @override
  void dispose() {
    _cancelRetry();
    _connectivitySubscription?.cancel();
    super.dispose();
  }
}
