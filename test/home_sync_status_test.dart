import 'dart:async';

import 'package:daily_bread/data/datasources/bible_data_source.dart';
import 'package:daily_bread/data/datasources/local_data_source.dart';
import 'package:daily_bread/data/models/verse_bookmark_model.dart';
import 'package:daily_bread/data/repositories/user_repository.dart';
import 'package:daily_bread/presentation/providers/app_services_provider.dart';
import 'package:daily_bread/presentation/providers/auth_provider.dart';
import 'package:daily_bread/presentation/providers/bible_provider.dart';
import 'package:daily_bread/presentation/providers/bookmarks_provider.dart';
import 'package:daily_bread/presentation/providers/reading_plan_provider.dart';
import 'package:daily_bread/presentation/providers/user_provider.dart';
import 'package:daily_bread/presentation/screens/home_screen.dart';
import 'package:daily_bread/presentation/screens/sign_in_screen.dart';
import 'package:daily_bread/services/auth/auth_service.dart';
import 'package:daily_bread/services/cloud/cloud_sync_service.dart';
import 'package:daily_bread/services/notifications/daily_reminder_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
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
  Object? nextError;
  final List<CloudSyncSnapshot> snapshots = [];
  final List<Completer<void>> _callBlocks = [];
  final List<Object> _errors = [];
  int callCount = 0;

  @override
  bool get isAvailable => true;

  @override
  String get backendLabel => 'Firebase';

  @override
  Future<void> initialize() async {}

  @override
  DateTime? getLastSyncedAt() => null;

  @override
  Future<DateTime> syncSnapshot(CloudSyncSnapshot snapshot) async {
    callCount += 1;
    snapshots.add(snapshot);
    if (_callBlocks.isNotEmpty) {
      await _callBlocks.removeAt(0).future;
    }

    final error = _errors.isNotEmpty ? _errors.removeAt(0) : nextError;
    nextError = null;
    if (error != null) {
      throw error;
    }
    return DateTime.now();
  }

  void enqueueError(Object error) {
    _errors.add(error);
  }

  Completer<void> blockNextCall() {
    final completer = Completer<void>();
    _callBlocks.add(completer);
    return completer;
  }
}

class _FakeSyncTelemetry implements SyncTelemetry {
  final List<Map<String, Object?>> events = [];

  @override
  void record(String event, Map<String, Object?> metadata) {
    events.add({'event': event, ...metadata});
  }
}

class _FakeAuthService implements AuthService {
  final StreamController<AuthUser?> _controller =
      StreamController<AuthUser?>.broadcast();
  AuthUser? _currentUser;

  _FakeAuthService(this._currentUser);

  @override
  Stream<AuthUser?> authStateChanges() => _controller.stream;

  @override
  AuthUser? get currentUser => _currentUser;

  @override
  Future<void> signInWithEmailPassword(String email, String password) async {
    _emit(AuthUser(uid: 'signed-in', email: email, isAnonymous: false));
  }

  @override
  Future<void> signUpWithEmailPassword(String email, String password) async {
    _emit(AuthUser(uid: 'signed-up', email: email, isAnonymous: false));
  }

  @override
  Future<void> linkAnonymousWithEmailPassword(
    String email,
    String password,
  ) async {
    _emit(
      AuthUser(
        uid: _currentUser?.uid ?? 'linked',
        email: email,
        isAnonymous: false,
      ),
    );
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {}

  @override
  Future<void> signOut() async {
    _emit(null);
  }

  void _emit(AuthUser? user) {
    _currentUser = user;
    _controller.add(user);
  }

  Future<void> dispose() async {
    await _controller.close();
  }
}

class _HomeTestHarness {
  final LocalDataSource localDataSource;
  final _FakeCloudSyncService syncService;
  final _FakeConnectivity connectivity;
  final UserProvider userProvider;
  final ReadingPlanProvider planProvider;
  final BookmarksProvider bookmarksProvider;
  final AppServicesProvider appServicesProvider;
  final _FakeAuthService authService;
  final AuthProvider authProvider;

  _HomeTestHarness({
    required this.localDataSource,
    required this.syncService,
    required this.connectivity,
    required this.userProvider,
    required this.planProvider,
    required this.bookmarksProvider,
    required this.appServicesProvider,
    required this.authService,
    required this.authProvider,
  });

  Future<void> dispose() async {
    authProvider.dispose();
    await authService.dispose();
    appServicesProvider.dispose();
    await connectivity.dispose();
  }
}

Future<_HomeTestHarness> _pumpHome(
  WidgetTester tester, {
  required _FakeCloudSyncService syncService,
  required _FakeConnectivity connectivity,
  bool enableAutoSync = false,
  Future<void> Function(String diagnostics)? onReportSyncDiagnostics,
  Duration? baseRetryDelay,
  Duration? maxRetryDelay,
  SyncTelemetry? telemetry,
  AuthUser? authUser = const AuthUser(
    uid: 'auth-user',
    email: 'user@example.com',
    isAnonymous: false,
  ),
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final localDataSource = LocalDataSource(prefs);

  final userProvider = UserProvider(UserRepository(localDataSource));
  final planProvider = ReadingPlanProvider(localDataSource);
  final bookmarksProvider = BookmarksProvider(localDataSource);
  final appServicesProvider = AppServicesProvider(
    syncService,
    LocalReminderService(localDataSource),
    syncConnectivity: connectivity,
    localDataSource: localDataSource,
    syncTelemetry: telemetry,
    baseRetryDelay: baseRetryDelay ?? const Duration(seconds: 2),
    maxRetryDelay: maxRetryDelay ?? const Duration(minutes: 5),
  );
  final authService = _FakeAuthService(authUser);
  final authProvider = AuthProvider(authService);

  await Future.wait([
    userProvider.loadUser(),
    planProvider.loadPlanState(),
    bookmarksProvider.loadBookmarks(),
  ]);

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<BibleProvider>.value(
          value: BibleProvider(BibleDataSource()),
        ),
        ChangeNotifierProvider<UserProvider>.value(value: userProvider),
        ChangeNotifierProvider<ReadingPlanProvider>.value(value: planProvider),
        ChangeNotifierProvider<BookmarksProvider>.value(
          value: bookmarksProvider,
        ),
        ChangeNotifierProvider<AppServicesProvider>.value(
          value: appServicesProvider,
        ),
        ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
      ],
      child: MaterialApp(
        home: HomeScreen(
          enableAutoSync: enableAutoSync,
          onReportSyncDiagnostics: onReportSyncDiagnostics,
        ),
      ),
    ),
  );
  await tester.pump();

  return _HomeTestHarness(
    localDataSource: localDataSource,
    syncService: syncService,
    connectivity: connectivity,
    userProvider: userProvider,
    planProvider: planProvider,
    bookmarksProvider: bookmarksProvider,
    appServicesProvider: appServicesProvider,
    authService: authService,
    authProvider: authProvider,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('shows failed sync status with retry controls', (tester) async {
    String? clipboardText;
    String? sharedDiagnosticsText;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (methodCall) async {
          if (methodCall.method == 'Clipboard.setData') {
            clipboardText = (methodCall.arguments as Map)['text'] as String;
            return null;
          }
          return null;
        });

    final fakeSyncService = _FakeCloudSyncService();
    final connectivity = _FakeConnectivity(false);
    final harness = await _pumpHome(
      tester,
      syncService: fakeSyncService,
      connectivity: connectivity,
      enableAutoSync: false,
      onReportSyncDiagnostics: (diagnostics) async {
        sharedDiagnosticsText = diagnostics;
      },
    );
    await tester.pump(const Duration(milliseconds: 300));

    fakeSyncService.nextError = FirebaseException(
      plugin: 'cloud_functions',
      code: 'permission-denied',
    );

    await harness.appServicesProvider.syncNow(
      user: harness.userProvider.user,
      bookmarks: const <VerseBookmark>[],
      reason: 'manual',
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Status: Failed'), findsOneWidget);
    expect(
      find.text('Successes: 0 • Failures: 1 • Retries scheduled: 0'),
      findsOneWidget,
    );
    expect(find.textContaining('Last outcome: Failure at'), findsOneWidget);
    expect(find.text('Sync health: Critical'), findsOneWidget);
    expect(find.text('Retry now'), findsOneWidget);
    expect(find.text('View details'), findsOneWidget);
    expect(find.text('Sync details'), findsNothing);

    await tester.ensureVisible(find.text('View details'));
    await tester.tap(find.text('View details'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Sync details'), findsOneWidget);
    expect(find.text('Successes: 0'), findsOneWidget);
    expect(find.text('Failures: 1'), findsOneWidget);
    expect(find.text('Retries scheduled: 0'), findsOneWidget);
    expect(find.text('Health: Critical'), findsOneWidget);
    expect(find.text('Category: Permission'), findsOneWidget);
    expect(find.text('Report issue'), findsOneWidget);

    await tester.tap(find.text('Copy diagnostics'));
    await tester.pump();
    expect(find.text('Diagnostics copied'), findsOneWidget);
    expect(clipboardText, isNotNull);
    expect(clipboardText, contains('Health: Critical'));
    expect(clipboardText, contains('Failures: 1'));
    expect(clipboardText, contains('Category: Permission'));

    await tester.tap(find.text('Report issue'));
    await tester.pump();
    expect(sharedDiagnosticsText, isNotNull);
    expect(sharedDiagnosticsText, contains('Health: Critical'));
    expect(sharedDiagnosticsText, contains('Failures: 1'));
    expect(sharedDiagnosticsText, contains('Category: Permission'));

    await tester.tap(find.text('Reset diagnostics'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Sync details'), findsNothing);
    expect(find.text('Status: Synced'), findsOneWidget);
    expect(
      find.text('Successes: 0 • Failures: 0 • Retries scheduled: 0'),
      findsOneWidget,
    );
    expect(find.text('Last outcome: N/A'), findsOneWidget);
    expect(find.text('Sync health: Unknown'), findsOneWidget);
    expect(find.text('Retry now'), findsNothing);
    expect(find.text('View details'), findsNothing);

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
    await harness.dispose();
  });

  testWidgets('signed-out Sync now opens sign-in flow instead of syncing', (
    tester,
  ) async {
    final syncService = _FakeCloudSyncService();
    final connectivity = _FakeConnectivity(false);
    final harness = await _pumpHome(
      tester,
      syncService: syncService,
      connectivity: connectivity,
      enableAutoSync: false,
      authUser: null,
    );

    expect(
      find.text('Sign in to back up and sync across devices.'),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(ElevatedButton, 'Sign in to sync'),
      findsOneWidget,
    );

    await tester.ensureVisible(
      find.widgetWithText(ElevatedButton, 'Sign in to sync'),
    );
    await tester.tap(find.widgetWithText(ElevatedButton, 'Sign in to sync'));
    await tester.pumpAndSettle();

    expect(syncService.callCount, 0);
    expect(find.byType(SignInScreen), findsOneWidget);

    await harness.dispose();
  });

  testWidgets(
    'auto-sync on resume does not start a second sync while one is in flight',
    (tester) async {
      final syncService = _FakeCloudSyncService();
      final connectivity = _FakeConnectivity(false);
      final firstCallGate = syncService.blockNextCall();

      final harness = await _pumpHome(
        tester,
        syncService: syncService,
        connectivity: connectivity,
        enableAutoSync: true,
      );

      await tester.pump(const Duration(milliseconds: 80));
      expect(syncService.callCount, 1);
      expect(find.text('Status: Syncing'), findsOneWidget);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(milliseconds: 120));

      expect(syncService.callCount, 1);

      firstCallGate.complete();
      await tester.pump(const Duration(milliseconds: 120));
      expect(syncService.callCount, 1);

      await harness.dispose();
    },
  );

  testWidgets(
    'rapid bookmark changes are debounced into a single bookmark_change sync',
    (tester) async {
      final syncService = _FakeCloudSyncService();
      final connectivity = _FakeConnectivity(false);
      final telemetry = _FakeSyncTelemetry();

      final harness = await _pumpHome(
        tester,
        syncService: syncService,
        connectivity: connectivity,
        enableAutoSync: true,
        telemetry: telemetry,
      );

      await tester.pump(const Duration(milliseconds: 120));
      final baselineCalls = syncService.callCount;

      await harness.bookmarksProvider.addBookmark(
        VerseBookmark(
          book: 'John',
          chapter: 1,
          verse: 1,
          translationId: 'web',
          createdAt: DateTime(2026, 4, 25, 10),
        ),
      );
      await harness.bookmarksProvider.addBookmark(
        VerseBookmark(
          book: 'John',
          chapter: 1,
          verse: 2,
          translationId: 'web',
          createdAt: DateTime(2026, 4, 25, 10, 0, 1),
        ),
      );
      await harness.bookmarksProvider.addBookmark(
        VerseBookmark(
          book: 'John',
          chapter: 1,
          verse: 3,
          translationId: 'web',
          createdAt: DateTime(2026, 4, 25, 10, 0, 2),
        ),
      );

      await tester.pump(const Duration(milliseconds: 600));
      expect(syncService.callCount, baselineCalls);

      await tester.pump(const Duration(seconds: 3));
      expect(syncService.callCount, baselineCalls + 1);

      final bookmarkChangeSuccesses = telemetry.events
          .where(
            (event) =>
                event['event'] == 'sync_success' &&
                event['reason'] == 'bookmark_change',
          )
          .length;
      expect(bookmarkChangeSuccesses, 1);

      await harness.dispose();
    },
  );

  testWidgets(
    'resume while offline queues exactly one pending sync that drains once on reconnect',
    (tester) async {
      final syncService = _FakeCloudSyncService();
      final connectivity = _FakeConnectivity(false);

      final harness = await _pumpHome(
        tester,
        syncService: syncService,
        connectivity: connectivity,
        enableAutoSync: true,
      );

      await tester.pump(const Duration(milliseconds: 150));
      final baselineCalls = syncService.callCount;

      connectivity.setOffline(true);
      await tester.pump(const Duration(milliseconds: 120));
      expect(harness.appServicesProvider.isOffline, isTrue);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(milliseconds: 180));

      expect(harness.appServicesProvider.syncStatus, SyncStatus.pending);
      expect(syncService.callCount, baselineCalls);

      connectivity.setOffline(false);
      await tester.pump(const Duration(milliseconds: 350));

      expect(syncService.callCount, baselineCalls + 1);
      expect(harness.appServicesProvider.syncStatus, SyncStatus.idle);
      expect(find.text('Status: Synced'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 400));
      expect(syncService.callCount, baselineCalls + 1);

      await harness.dispose();
    },
  );

  testWidgets(
    'manual retry during scheduled retry window triggers one immediate sync without duplicate retry execution',
    (tester) async {
      final syncService = _FakeCloudSyncService();
      final connectivity = _FakeConnectivity(false);
      syncService.enqueueError(
        FirebaseException(plugin: 'cloud_functions', code: 'unavailable'),
      );

      final harness = await _pumpHome(
        tester,
        syncService: syncService,
        connectivity: connectivity,
        enableAutoSync: false,
        baseRetryDelay: const Duration(milliseconds: 500),
        maxRetryDelay: const Duration(milliseconds: 500),
      );

      await tester.ensureVisible(find.text('Sync now'));
      await tester.tap(find.text('Sync now'));
      await tester.pump(const Duration(milliseconds: 150));

      expect(syncService.callCount, 1);
      expect(find.textContaining('Status: Retrying'), findsOneWidget);

      await tester.ensureVisible(find.text('Sync now'));
      await tester.tap(find.text('Sync now'));
      await tester.pump(const Duration(milliseconds: 200));

      expect(syncService.callCount, 2);
      expect(find.text('Status: Synced'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 700));
      expect(syncService.callCount, 2);
      expect(find.text('Retry now'), findsNothing);
      expect(find.text('View details'), findsNothing);

      await harness.dispose();
    },
  );

  testWidgets(
    'auto-sync lifecycle transitions keep sync status UI consistent without duplicate controls',
    (tester) async {
      final syncService = _FakeCloudSyncService();
      final connectivity = _FakeConnectivity(false);

      final harness = await _pumpHome(
        tester,
        syncService: syncService,
        connectivity: connectivity,
        enableAutoSync: true,
      );

      await tester.pump(const Duration(milliseconds: 150));
      connectivity.setOffline(true);
      await tester.pump(const Duration(milliseconds: 120));
      expect(harness.appServicesProvider.isOffline, isTrue);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(milliseconds: 180));

      expect(harness.appServicesProvider.syncStatus, SyncStatus.pending);
      expect(find.text('Retry now'), findsNothing);
      expect(find.text('View details'), findsNothing);

      connectivity.setOffline(false);
      await tester.pump(const Duration(milliseconds: 350));

      expect(harness.appServicesProvider.syncStatus, SyncStatus.idle);
      expect(find.text('Status: Synced'), findsOneWidget);
      expect(find.text('Retry now'), findsNothing);
      expect(find.text('View details'), findsNothing);

      await harness.dispose();
    },
  );
}
