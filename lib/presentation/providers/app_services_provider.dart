import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../../data/datasources/local_data_source.dart';
import '../../data/models/user_model.dart';
import '../../data/models/verse_bookmark_model.dart';
import '../../services/cloud/cloud_sync_service.dart';
import '../../services/notifications/daily_reminder_service.dart';

enum SyncStatus { idle, pending, syncing, retrying, failed }

enum SyncOutcome { success, failure }

enum SyncHealth { unknown, healthy, degraded, critical }

enum SyncErrorCategory {
  none,
  network,
  auth,
  permission,
  validation,
  server,
  unknown,
}

abstract class SyncTelemetry {
  void record(String event, Map<String, Object?> metadata);
}

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
  static const Duration _defaultBaseRetryDelay = Duration(seconds: 2);
  static const Duration _defaultMaxRetryDelay = Duration(minutes: 5);
  static const int _defaultMaxRetryAttempts = 8;

  final CloudSyncService _cloudSyncService;
  final DailyReminderService _dailyReminderService;
  final SyncConnectivity _syncConnectivity;
  final SyncTelemetry? _syncTelemetry;
  final LocalDataSource? _localDataSource;
  final Duration _baseRetryDelay;
  final Duration _maxRetryDelay;
  final int _maxRetryAttempts;

  AppServicesProvider(
    this._cloudSyncService,
    this._dailyReminderService, {
    SyncConnectivity? syncConnectivity,
    SyncTelemetry? syncTelemetry,
    LocalDataSource? localDataSource,
    Duration baseRetryDelay = _defaultBaseRetryDelay,
    Duration maxRetryDelay = _defaultMaxRetryDelay,
    int maxRetryAttempts = _defaultMaxRetryAttempts,
  }) : _syncConnectivity =
            syncConnectivity ?? DeviceSyncConnectivity(Connectivity()),
       _syncTelemetry = syncTelemetry,
       _localDataSource = localDataSource,
       _baseRetryDelay = baseRetryDelay,
       _maxRetryDelay = maxRetryDelay,
       _maxRetryAttempts = maxRetryAttempts {
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
  DateTime? _lastSyncOutcomeAt;
  SyncOutcome? _lastSyncOutcome;
  String? _lastSyncErrorCode;
  String? _lastSyncErrorMessage;
  SyncErrorCategory _lastSyncErrorCategory = SyncErrorCategory.none;
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
  DateTime? get lastSyncOutcomeAt => _lastSyncOutcomeAt;
  SyncOutcome? get lastSyncOutcome => _lastSyncOutcome;
  String? get lastSyncErrorCode => _lastSyncErrorCode;
  String? get lastSyncErrorMessage => _lastSyncErrorMessage;
  SyncErrorCategory get lastSyncErrorCategory => _lastSyncErrorCategory;
  bool get isOffline => _isOffline;
  int get syncSuccessCount => _syncSuccessCount;
  int get syncFailureCount => _syncFailureCount;
  int get syncRetryScheduledCount => _syncRetryScheduledCount;
  SyncHealth get syncHealth {
    if (_syncSuccessCount == 0 && _syncFailureCount == 0) {
      return SyncHealth.unknown;
    }
    if (_syncFailureCount > 0 && _syncSuccessCount == 0) {
      return SyncHealth.critical;
    }
    if (_syncFailureCount > _syncSuccessCount) {
      return SyncHealth.degraded;
    }
    return SyncHealth.healthy;
  }

  String get syncHealthLabel {
    switch (syncHealth) {
      case SyncHealth.unknown:
        return 'Unknown';
      case SyncHealth.healthy:
        return 'Healthy';
      case SyncHealth.degraded:
        return 'Needs attention';
      case SyncHealth.critical:
        return 'Critical';
    }
  }

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
        final attemptNumber = _retryCount + 1;
        _lastSyncedAt = await _cloudSyncService.syncSnapshot(request.snapshot);
        _lastSyncSuccessAt = _lastSyncedAt;
        _lastSyncErrorCode = null;
        _lastSyncErrorMessage = null;
        _lastSyncErrorCategory = SyncErrorCategory.none;
        _lastSyncOutcome = SyncOutcome.success;
        _lastSyncOutcomeAt = _lastSyncedAt;
        _retryCount = 0;
        _nextRetryAt = null;
        _cancelRetry();
        _syncStatus = SyncStatus.idle;
        _syncMessage = cloudSyncAvailable
            ? 'Synced to Firebase successfully'
            : 'Firebase not configured. Saved local backup instead.';
        _syncSuccessCount += 1;
        await _persistSyncTelemetryState();
        _recordTelemetry(
          'sync_success',
          _baseTelemetryMetadata(
            reason: request.reason,
            attemptNumber: attemptNumber,
          ),
        );
        notifyListeners();

        if (request.onSynced != null) {
          await request.onSynced!();
        }
      } catch (error) {
        final category = _classifyError(error);
        final retryable = _isRetryableError(error);
        _lastSyncErrorCode = _syncErrorCode(error);
        _lastSyncErrorMessage = error.toString();
        _lastSyncErrorCategory = category;
        _syncFailureCount += 1;
        _recordTelemetry(
          'sync_failure',
          _baseTelemetryMetadata(
            reason: request.reason,
            retryable: retryable,
            category: category,
            code: _lastSyncErrorCode,
            error: _lastSyncErrorMessage,
            attemptNumber: _retryCount + 1,
          ),
        );

        if (!retryable) {
          _retryCount = 0;
          _nextRetryAt = null;
          _syncStatus = SyncStatus.failed;
          _syncMessage = _failureMessageForCategory(category);
          _lastSyncOutcome = SyncOutcome.failure;
          _lastSyncOutcomeAt = DateTime.now();
          await _persistSyncTelemetryState();
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
          _lastSyncOutcome = SyncOutcome.failure;
          _lastSyncOutcomeAt = DateTime.now();
          await _persistSyncTelemetryState();
          _recordTelemetry(
            'sync_retry_exhausted',
            _baseTelemetryMetadata(
              reason: request.reason,
              retryable: retryable,
              category: category,
              code: _lastSyncErrorCode,
              error: _lastSyncErrorMessage,
              attemptNumber: _retryCount,
            ),
          );
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
        await _persistSyncTelemetryState();
        _recordTelemetry(
          'sync_retry_scheduled',
          _baseTelemetryMetadata(
            reason: request.reason,
            category: category,
            code: _lastSyncErrorCode,
            error: _lastSyncErrorMessage,
            nextRetryInSeconds: delay.inSeconds,
            attemptNumber: _retryCount,
          ),
        );
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
    final category = _classifyError(error);
    return category == SyncErrorCategory.network ||
        category == SyncErrorCategory.server;
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

  SyncErrorCategory _classifyError(Object error) {
    if (error is TimeoutException) {
      return SyncErrorCategory.network;
    }

    if (error is FirebaseException) {
      final code = error.code.toLowerCase();
      if ({
        'network-request-failed',
        'unavailable',
        'deadline-exceeded',
        'aborted',
      }.contains(code)) {
        return SyncErrorCategory.network;
      }
      if ({'resource-exhausted', 'internal', 'unknown'}.contains(code)) {
        return SyncErrorCategory.server;
      }
      if ({'unauthenticated', 'auth-error'}.contains(code)) {
        return SyncErrorCategory.auth;
      }
      if ({'permission-denied'}.contains(code)) {
        return SyncErrorCategory.permission;
      }
      if ({
        'invalid-argument',
        'failed-precondition',
        'out-of-range',
      }.contains(code)) {
        return SyncErrorCategory.validation;
      }
      return SyncErrorCategory.unknown;
    }

    final message = error.toString().toLowerCase();
    if (message.contains('timeout') ||
        message.contains('socketexception') ||
        message.contains('network') ||
        message.contains('dns')) {
      return SyncErrorCategory.network;
    }
    if (message.contains('503') ||
        message.contains('502') ||
        message.contains('504') ||
        message.contains('429') ||
        message.contains('server error')) {
      return SyncErrorCategory.server;
    }
    if (message.contains('unauthenticated') || message.contains('auth')) {
      return SyncErrorCategory.auth;
    }
    if (message.contains('permission')) {
      return SyncErrorCategory.permission;
    }
    if (message.contains('invalid') || message.contains('argument')) {
      return SyncErrorCategory.validation;
    }
    return SyncErrorCategory.unknown;
  }

  String _failureMessageForCategory(SyncErrorCategory category) {
    switch (category) {
      case SyncErrorCategory.auth:
        return 'Sync failed: sign-in issue. Please authenticate again.';
      case SyncErrorCategory.permission:
        return 'Sync failed: permission denied.';
      case SyncErrorCategory.validation:
        return 'Sync failed: invalid data payload.';
      case SyncErrorCategory.server:
        return 'Sync failed: server issue. Retrying may help.';
      case SyncErrorCategory.network:
        return 'Sync failed: network issue. Retrying may help.';
      case SyncErrorCategory.unknown:
        return 'Sync failed. Please try again.';
      case SyncErrorCategory.none:
        return 'Sync failed. Please try again.';
    }
  }

  void _recordTelemetry(String event, Map<String, Object?> metadata) {
    _syncTelemetry?.record(event, metadata);
  }

  Map<String, Object?> _baseTelemetryMetadata({
    required String reason,
    int? attemptNumber,
    bool? retryable,
    SyncErrorCategory? category,
    String? code,
    String? error,
    int? nextRetryInSeconds,
  }) {
    final metadata = <String, Object?>{
      'reason': reason,
      'backend': cloudBackendLabel,
      'status': _syncStatus.name,
      'retryCount': _retryCount,
      'isOffline': _isOffline,
      'attemptNumber': attemptNumber,
      'category': category?.name,
      'code': code,
      'retryable': retryable,
      'nextRetryInSeconds': nextRetryInSeconds,
      'error': error,
    };
    metadata.removeWhere((_, value) => value == null);
    return metadata;
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
    _loadSyncTelemetryState();
    if (_lastSyncOutcomeAt == null && _lastSyncedAt != null) {
      _lastSyncOutcomeAt = _lastSyncedAt;
      _lastSyncOutcome = SyncOutcome.success;
    }
    _reminderEnabled = _dailyReminderService.isEnabled;
    _reminderTime = _dailyReminderService.reminderTime;
  }

  void _loadSyncTelemetryState() {
    final localDataSource = _localDataSource;
    if (localDataSource == null) {
      return;
    }

    _syncSuccessCount = localDataSource.getSyncSuccessCount();
    _syncFailureCount = localDataSource.getSyncFailureCount();
    _syncRetryScheduledCount = localDataSource.getSyncRetryScheduledCount();
    _lastSyncOutcomeAt = localDataSource.getSyncLastOutcomeAt();

    switch (localDataSource.getSyncLastOutcome()) {
      case 'success':
        _lastSyncOutcome = SyncOutcome.success;
        break;
      case 'failure':
        _lastSyncOutcome = SyncOutcome.failure;
        break;
      default:
        _lastSyncOutcome = null;
        break;
    }
  }

  Future<void> _persistSyncTelemetryState() async {
    final localDataSource = _localDataSource;
    if (localDataSource == null) {
      return;
    }

    await localDataSource.saveSyncSuccessCount(_syncSuccessCount);
    await localDataSource.saveSyncFailureCount(_syncFailureCount);
    await localDataSource.saveSyncRetryScheduledCount(_syncRetryScheduledCount);
    await localDataSource.saveSyncLastOutcome(_lastSyncOutcome?.name);
    await localDataSource.saveSyncLastOutcomeAt(_lastSyncOutcomeAt);
  }

  @override
  void dispose() {
    _cancelRetry();
    _connectivitySubscription?.cancel();
    super.dispose();
  }
}
