import 'dart:async';

import 'package:daily_bread/data/datasources/bible_data_source.dart';
import 'package:daily_bread/data/datasources/local_data_source.dart';
import 'package:daily_bread/data/models/verse_bookmark_model.dart';
import 'package:daily_bread/data/repositories/user_repository.dart';
import 'package:daily_bread/presentation/providers/app_services_provider.dart';
import 'package:daily_bread/presentation/providers/bible_provider.dart';
import 'package:daily_bread/presentation/providers/bookmarks_provider.dart';
import 'package:daily_bread/presentation/providers/reading_plan_provider.dart';
import 'package:daily_bread/presentation/providers/user_provider.dart';
import 'package:daily_bread/presentation/screens/home_screen.dart';
import 'package:daily_bread/services/cloud/cloud_sync_service.dart';
import 'package:daily_bread/services/notifications/daily_reminder_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeConnectivity implements SyncConnectivity {
  final bool _offline;
  final StreamController<bool> _controller = StreamController<bool>.broadcast();

  _FakeConnectivity(this._offline);

  @override
  Future<bool> get isOffline async => _offline;

  @override
  Stream<bool> get onOfflineChanged => _controller.stream;

  Future<void> dispose() async {
    await _controller.close();
  }
}

class _FakeCloudSyncService implements CloudSyncService {
  Object? nextError;

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
    final error = nextError;
    nextError = null;
    if (error != null) {
      throw error;
    }
    return DateTime.now();
  }
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

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final localDataSource = LocalDataSource(prefs);
    final fakeSyncService = _FakeCloudSyncService();
    final connectivity = _FakeConnectivity(false);

    final bibleProvider = BibleProvider(BibleDataSource());
    final userProvider = UserProvider(UserRepository(localDataSource));
    final planProvider = ReadingPlanProvider(localDataSource);
    final bookmarksProvider = BookmarksProvider(localDataSource);
    final appServicesProvider = AppServicesProvider(
      fakeSyncService,
      LocalReminderService(localDataSource),
      syncConnectivity: connectivity,
    );

    await Future.wait([
      userProvider.loadUser(),
      planProvider.loadPlanState(),
      bookmarksProvider.loadBookmarks(),
    ]);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<BibleProvider>.value(value: bibleProvider),
          ChangeNotifierProvider<UserProvider>.value(value: userProvider),
          ChangeNotifierProvider<ReadingPlanProvider>.value(
            value: planProvider,
          ),
          ChangeNotifierProvider<BookmarksProvider>.value(
            value: bookmarksProvider,
          ),
          ChangeNotifierProvider<AppServicesProvider>.value(
            value: appServicesProvider,
          ),
        ],
        child: MaterialApp(
          home: HomeScreen(
            enableAutoSync: false,
            onReportSyncDiagnostics: (diagnostics) async {
              sharedDiagnosticsText = diagnostics;
            },
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    fakeSyncService.nextError = FirebaseException(
      plugin: 'cloud_functions',
      code: 'permission-denied',
    );

    await appServicesProvider.syncNow(
      user: userProvider.user,
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

  });
}
