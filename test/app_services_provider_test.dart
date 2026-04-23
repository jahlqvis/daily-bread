import 'dart:async';
import 'dart:collection';

import 'package:daily_bread/data/datasources/local_data_source.dart';
import 'package:daily_bread/data/models/user_model.dart';
import 'package:daily_bread/data/models/verse_bookmark_model.dart';
import 'package:daily_bread/presentation/providers/app_services_provider.dart';
import 'package:daily_bread/services/cloud/cloud_sync_service.dart';
import 'package:daily_bread/services/notifications/daily_reminder_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeConnectivity implements SyncConnectivity {
  bool _offline;
  final StreamController<bool> _controller = StreamController<bool>.broadcast();

  _FakeConnectivity(this._offline);

  @override
  Future<bool> get isOffline async => _offline;

  @override
  Stream<bool> get onOfflineChanged => _controller.stream;

  void setOffline(bool value) {
    _offline = value;
    _controller.add(value);
  }

  Future<void> dispose() async {
    await _controller.close();
  }
}

class _FakeCloudSyncService implements CloudSyncService {
  final DateTime Function() _nowProvider;
  final Queue<Object> _errors = Queue<Object>();

  CloudSyncSnapshot? _lastSnapshot;
  DateTime? _lastSyncedAt;
  int callCount = 0;

  _FakeCloudSyncService({DateTime Function()? nowProvider})
    : _nowProvider = nowProvider ?? DateTime.now;

  @override
  bool get isAvailable => true;

  @override
  String get backendLabel => 'Firebase';

  @override
  Future<void> initialize() async {}

  @override
  DateTime? getLastSyncedAt() => _lastSyncedAt;

  @override
  Future<DateTime> syncSnapshot(CloudSyncSnapshot snapshot) async {
    callCount += 1;
    _lastSnapshot = snapshot;
    if (_errors.isNotEmpty) {
      throw _errors.removeFirst();
    }

    _lastSyncedAt = _nowProvider();
    return _lastSyncedAt!;
  }

  void enqueueError(Object error) {
    _errors.add(error);
  }

  CloudSyncSnapshot? get lastSnapshot => _lastSnapshot;
}

class _FakeSyncTelemetry implements SyncTelemetry {
  final List<Map<String, Object?>> events = [];

  @override
  void record(String event, Map<String, Object?> metadata) {
    events.add({'event': event, ...metadata});
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppServicesProvider', () {
    test('syncNow persists snapshot timestamp', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final localDataSource = LocalDataSource(prefs);
      final fakeSyncService = _FakeCloudSyncService();
      final connectivity = _FakeConnectivity(false);

      final provider = AppServicesProvider(
        fakeSyncService,
        LocalReminderService(localDataSource),
        syncConnectivity: connectivity,
      );

      await provider.syncNow(
        user: UserModel(currentStreak: 3, totalXp: 120),
        bookmarks: [
          VerseBookmark(
            book: 'John',
            chapter: 3,
            verse: 16,
            translationId: 'web',
            createdAt: DateTime(2026, 4, 18),
          ),
        ],
      );

      expect(provider.lastSyncedAt, isNotNull);
      expect(fakeSyncService.lastSnapshot, isNotNull);
      expect(provider.syncStatus, SyncStatus.idle);
      expect(provider.lastSyncOutcome, SyncOutcome.success);
      expect(provider.lastSyncOutcomeAt, isNotNull);

      provider.dispose();
      await connectivity.dispose();
    });

    test(
      'retryable sync failures schedule backoff retry and recover',
      () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final localDataSource = LocalDataSource(prefs);
        final fakeSyncService = _FakeCloudSyncService();
        final connectivity = _FakeConnectivity(false);

        fakeSyncService.enqueueError(
          FirebaseException(plugin: 'cloud_functions', code: 'unavailable'),
        );

        final provider = AppServicesProvider(
          fakeSyncService,
          LocalReminderService(localDataSource),
          syncConnectivity: connectivity,
        );

        await provider.syncNow(
          user: UserModel(totalXp: 10),
          bookmarks: const [],
        );

        expect(provider.syncStatus, SyncStatus.retrying);
        expect(provider.retryCount, 1);
        expect(provider.nextRetryAt, isNotNull);

        await Future<void>.delayed(const Duration(seconds: 3));

        expect(provider.syncStatus, SyncStatus.idle);
        expect(provider.retryCount, 0);
        expect(provider.syncSuccessCount, 1);
        expect(fakeSyncService.callCount, greaterThanOrEqualTo(2));

        provider.dispose();
        await connectivity.dispose();
      },
    );

    test(
      'non-retryable sync failure enters failed state immediately',
      () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final localDataSource = LocalDataSource(prefs);
        final fakeSyncService = _FakeCloudSyncService();
        final connectivity = _FakeConnectivity(false);

        fakeSyncService.enqueueError(
          FirebaseException(
            plugin: 'cloud_functions',
            code: 'invalid-argument',
          ),
        );

        final provider = AppServicesProvider(
          fakeSyncService,
          LocalReminderService(localDataSource),
          syncConnectivity: connectivity,
        );

        await provider.syncNow(
          user: UserModel(totalXp: 10),
          bookmarks: const [],
        );

        expect(provider.syncStatus, SyncStatus.failed);
        expect(provider.retryCount, 0);
        expect(provider.nextRetryAt, isNull);
        expect(provider.lastSyncErrorCategory, SyncErrorCategory.validation);
        expect(provider.lastSyncOutcome, SyncOutcome.failure);
        expect(provider.lastSyncOutcomeAt, isNotNull);

        provider.dispose();
        await connectivity.dispose();
      },
    );

    test('manual retry can recover after non-retryable failure', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final localDataSource = LocalDataSource(prefs);
      final fakeSyncService = _FakeCloudSyncService();
      final connectivity = _FakeConnectivity(false);

      fakeSyncService.enqueueError(
        FirebaseException(plugin: 'cloud_functions', code: 'permission-denied'),
      );

      final provider = AppServicesProvider(
        fakeSyncService,
        LocalReminderService(localDataSource),
        syncConnectivity: connectivity,
      );

      await provider.syncNow(user: UserModel(totalXp: 8), bookmarks: const []);
      expect(provider.syncStatus, SyncStatus.failed);

      await provider.syncNow(
        user: UserModel(totalXp: 9),
        bookmarks: const [],
        reason: 'manual_retry',
      );

      expect(provider.syncStatus, SyncStatus.idle);
      expect(provider.lastSyncErrorCategory, SyncErrorCategory.none);
      expect(provider.syncSuccessCount, 1);
      expect(provider.lastSyncOutcome, SyncOutcome.success);
      expect(provider.lastSyncOutcomeAt, isNotNull);

      provider.dispose();
      await connectivity.dispose();
    });

    test('telemetry records failure, retry, and success events', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final localDataSource = LocalDataSource(prefs);
      final fakeSyncService = _FakeCloudSyncService();
      final connectivity = _FakeConnectivity(false);
      final telemetry = _FakeSyncTelemetry();

      fakeSyncService.enqueueError(
        FirebaseException(plugin: 'cloud_functions', code: 'unavailable'),
      );

      final provider = AppServicesProvider(
        fakeSyncService,
        LocalReminderService(localDataSource),
        syncConnectivity: connectivity,
        syncTelemetry: telemetry,
      );

      await provider.syncNow(
        user: UserModel(totalXp: 12),
        bookmarks: const [],
        reason: 'launch',
      );
      await Future<void>.delayed(const Duration(seconds: 3));

      final eventNames = telemetry.events
          .map((entry) => entry['event'] as String)
          .toList();
      expect(eventNames, contains('sync_failure'));
      expect(eventNames, contains('sync_retry_scheduled'));
      expect(eventNames, contains('sync_success'));

      final failureEvent = telemetry.events.firstWhere(
        (entry) => entry['event'] == 'sync_failure',
      );
      expect(failureEvent['backend'], 'Firebase');
      expect(failureEvent['reason'], 'launch');
      expect(failureEvent['isOffline'], isFalse);
      expect(failureEvent['category'], 'network');

      final retryEvent = telemetry.events.firstWhere(
        (entry) => entry['event'] == 'sync_retry_scheduled',
      );
      expect(retryEvent['nextRetryInSeconds'], 2);

      final successEvent = telemetry.events.firstWhere(
        (entry) => entry['event'] == 'sync_success',
      );
      expect(successEvent['attemptNumber'], 2);

      provider.dispose();
      await connectivity.dispose();
    });

    test('telemetry records retry exhaustion after max attempts', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final localDataSource = LocalDataSource(prefs);
      final fakeSyncService = _FakeCloudSyncService();
      final connectivity = _FakeConnectivity(false);
      final telemetry = _FakeSyncTelemetry();

      for (var i = 0; i < 3; i++) {
        fakeSyncService.enqueueError(
          FirebaseException(plugin: 'cloud_functions', code: 'unavailable'),
        );
      }

      final provider = AppServicesProvider(
        fakeSyncService,
        LocalReminderService(localDataSource),
        syncConnectivity: connectivity,
        syncTelemetry: telemetry,
        baseRetryDelay: const Duration(milliseconds: 10),
        maxRetryDelay: const Duration(milliseconds: 20),
        maxRetryAttempts: 2,
      );

      await provider.syncNow(
        user: UserModel(totalXp: 12),
        bookmarks: const [],
        reason: 'launch',
      );
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(provider.syncStatus, SyncStatus.failed);
      expect(
        provider.syncMessage,
        'Sync failed after retries. Please sync manually.',
      );
      expect(provider.lastSyncOutcome, SyncOutcome.failure);
      expect(provider.lastSyncOutcomeAt, isNotNull);

      final exhaustedEvent = telemetry.events.firstWhere(
        (entry) => entry['event'] == 'sync_retry_exhausted',
      );
      expect(exhaustedEvent['reason'], 'launch');
      expect(exhaustedEvent['backend'], 'Firebase');
      expect(exhaustedEvent['category'], 'network');
      expect(exhaustedEvent['isOffline'], isFalse);

      provider.dispose();
      await connectivity.dispose();
    });

    test('offline state queues sync until connectivity is restored', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final localDataSource = LocalDataSource(prefs);
      final fakeSyncService = _FakeCloudSyncService();
      final connectivity = _FakeConnectivity(true);

      final provider = AppServicesProvider(
        fakeSyncService,
        LocalReminderService(localDataSource),
        syncConnectivity: connectivity,
      );

      await provider.requestSync(
        user: UserModel(totalXp: 15),
        bookmarks: const [],
        reason: 'launch',
      );

      expect(provider.syncStatus, SyncStatus.pending);
      expect(fakeSyncService.callCount, 0);

      connectivity.setOffline(false);
      await Future<void>.delayed(const Duration(milliseconds: 300));

      expect(fakeSyncService.callCount, 1);
      expect(provider.syncStatus, SyncStatus.idle);

      provider.dispose();
      await connectivity.dispose();
    });

    test('reminder settings are persisted and reloaded', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final localDataSource = LocalDataSource(prefs);
      final connectivity = _FakeConnectivity(false);

      final provider = AppServicesProvider(
        _FakeCloudSyncService(),
        LocalReminderService(localDataSource),
        syncConnectivity: connectivity,
      );

      await provider.setReminderEnabled(true);
      await provider.setReminderTime('07:30');

      final reloaded = AppServicesProvider(
        _FakeCloudSyncService(),
        LocalReminderService(localDataSource),
        syncConnectivity: connectivity,
      );

      expect(reloaded.reminderEnabled, isTrue);
      expect(reloaded.reminderTime, '07:30');
      expect(reloaded.reminderSupported, isFalse);

      provider.dispose();
      reloaded.dispose();
      await connectivity.dispose();
    });
  });
}
