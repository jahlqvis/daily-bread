import 'dart:convert';
import 'dart:io';

import 'package:daily_bread/core/constants/bible_translation.dart';
import 'package:daily_bread/data/datasources/bible_data_source.dart';
import 'package:daily_bread/data/datasources/local_data_source.dart';
import 'package:daily_bread/main.dart' as app;
import 'package:daily_bread/presentation/providers/app_services_provider.dart';
import 'package:daily_bread/presentation/providers/auth_provider.dart';
import 'package:daily_bread/presentation/providers/bible_provider.dart';
import 'package:daily_bread/presentation/screens/home_screen.dart';
import 'package:daily_bread/presentation/screens/reading_screen.dart';
import 'package:daily_bread/services/cloud/firebase_backend_config.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('real startup, offline reading and restored local data', (
    tester,
  ) async {
    var httpAttempts = 0;
    await HttpOverrides.runZoned(
      () async {
        SharedPreferences.setMockInitialValues({});
        BibleDataSource.clearCachesForTesting();
        // Make the lack of build-time Firebase configuration explicit, rather
        // than depending on the host machine or a caught initialization failure.
        final config = FirebaseBackendConfig.fromEnvironment();
        expect(config.apiKey, isEmpty);
        expect(config.projectId, isEmpty);
        expect(config.messagingSenderId, isEmpty);
        expect(config.androidAppId, isEmpty);
        expect(config.iosAppId, isEmpty);
        expect(config.webAppId, isEmpty);
        expect(config.hasCoreValues, isFalse);
        expect(Firebase.apps, isEmpty);

        final originalPlatform = debugDefaultTargetPlatformOverride;
        final messenger = tester.binding.defaultBinaryMessenger;
        final connectivityCalls = <String>[];
        final connectivityEventCalls = <String>[];
        const connectivity = MethodChannel(
          'dev.fluttercommunity.plus/connectivity',
        );
        const connectivityEvents = MethodChannel(
          'dev.fluttercommunity.plus/connectivity_status',
        );
        debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
        messenger.setMockMethodCallHandler(connectivity, (call) async {
          connectivityCalls.add(call.method);
          return ['none'];
        });
        messenger.setMockMethodCallHandler(connectivityEvents, (call) async {
          connectivityEventCalls.add(call.method);
          return null;
        });
        // Large asset strings are decoded in an isolate; complete that work in
        // real async time rather than starving it with fake-clock animation pumps.
        await tester.runAsync(
          () => rootBundle.loadString('assets/bible/asv_books/genesis.json'),
        );
        addTearDown(() {
          messenger.setMockMethodCallHandler(connectivity, null);
          messenger.setMockMethodCallHandler(connectivityEvents, null);
          debugDefaultTargetPlatformOverride = originalPlatform;
          rootBundle.evict('assets/bible/asv_books/genesis.json');
          BibleDataSource.clearCachesForTesting();
        });

        final fontManifest =
            jsonDecode(await rootBundle.loadString('FontManifest.json'))
                as List;
        final noto = fontManifest.cast<Map<String, dynamic>>().singleWhere(
          (family) => family['family'] == 'NotoSans',
        );
        final faces = (noto['fonts'] as List).cast<Map<String, dynamic>>();
        expect(faces, hasLength(18));
        const weights = {
          100: 'Thin',
          200: 'ExtraLight',
          300: 'Light',
          400: 'Regular',
          500: 'Medium',
          600: 'SemiBold',
          700: 'Bold',
          800: 'ExtraBold',
          900: 'Black',
        };
        for (final entry in weights.entries) {
          for (final italic in [false, true]) {
            final style = italic
                ? '${entry.value == 'Regular' ? '' : entry.value}Italic'
                : entry.value;
            expect(
              faces.where(
                (face) =>
                    face['weight'] == entry.key &&
                    (face['style'] == 'italic') == italic &&
                    face['asset'] ==
                        'assets/fonts/noto_sans/NotoSans-$style.ttf',
              ),
              hasLength(1),
            );
          }
        }
        expect(
          await rootBundle.loadString('assets/fonts/noto_sans/OFL.txt'),
          contains('SIL OPEN FONT LICENSE Version 1.1'),
        );
        final fontLoader = FontLoader('NotoSans');
        for (final face in faces) {
          final asset = face['asset'] as String;
          expect(asset, startsWith('assets/fonts/noto_sans/NotoSans-'));
          fontLoader.addFont(rootBundle.load(asset));
        }
        await fontLoader.load();

        app.main();
        await tester.pump();
        await tester.pumpAndSettle();
        final theme = Theme.of(
          tester.element(find.text('Choose your Bible translation')),
        );
        expect(theme.textTheme.bodyMedium?.fontFamily, 'NotoSans');
        expect(theme.appBarTheme.titleTextStyle?.fontFamily, 'NotoSans');
        expect(theme.appBarTheme.titleTextStyle?.fontWeight, FontWeight.w600);
        expect(find.text('Choose your Bible translation'), findsOneWidget);
        expect(
          find.textContaining('offline without an account'),
          findsOneWidget,
        );
        expect(find.byType(HomeScreen), findsNothing);
        expect(
          tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
          isNull,
        );

        await tester.tap(find.text('American Standard Version (ASV)'));
        await tester.pump();
        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();
        expect(find.byType(HomeScreen), findsOneWidget);
        await tester.runAsync(
          () => BibleDataSource().preloadBook('Genesis', BibleTranslation.asv),
        );
        await tester.pump();
        final home = tester.element(find.byType(HomeScreen));
        expect(
          home.read<BibleProvider>().selectedTranslation,
          BibleTranslation.asv,
        );
        expect(home.read<BibleProvider>().isLoading, isFalse);
        expect(home.read<BibleProvider>().loadError, isNull);
        expect(home.read<AppServicesProvider>().isOffline, isTrue);
        expect(home.read<AppServicesProvider>().profileSafetyBlocked, isTrue);
        expect(home.read<AppServicesProvider>().cloudSyncAvailable, isFalse);
        expect(home.read<AuthProvider>().accountChangesBlocked, isTrue);
        expect(Firebase.apps, isEmpty);
        expect(find.text('Status: Paused'), findsOneWidget);
        expect(find.text('Not signed in'), findsOneWidget);
        expect(
          tester
              .widget<OutlinedButton>(
                find.widgetWithText(OutlinedButton, 'Create account'),
              )
              .onPressed,
          isNull,
        );
        expect(
          tester
              .widget<ElevatedButton>(
                find.widgetWithText(ElevatedButton, 'Sign in'),
              )
              .onPressed,
          isNull,
        );
        expect(
          tester
              .widget<ElevatedButton>(
                find.widgetWithText(ElevatedButton, 'Sync paused'),
              )
              .onPressed,
          isNull,
        );

        await tester.tap(find.widgetWithText(FloatingActionButton, 'Read'));
        await tester.pumpAndSettle();
        expect(find.byType(ReadingScreen), findsOneWidget);
        expect(
          find.text('In the beginning God created the heavens and the earth.'),
          findsOneWidget,
        );
        await tester.longPress(
          find.byTooltip(
            'Add bookmark for Genesis 1:1; long press to add note',
          ),
        );
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), 'Offline note');
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();
        await tester.pump(const Duration(seconds: 5));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Mark as Read (+10 XP)'));
        await tester.pumpAndSettle();

        final prefs = await SharedPreferences.getInstance();
        final local = LocalDataSource(prefs);
        expect(prefs.getString('bible_translation'), 'asv');
        expect(local.getBookmarks().single.note, 'Offline note');
        expect(local.getBookmarks().single.translationId, 'asv');
        final user = await local.getUser();
        expect(user.readingProgress['Genesis'], contains(1));
        expect(user.totalXp, 10);
        expect(local.getCloudSnapshot(), isNull);
        final saved = {for (final key in prefs.getKeys()) key: prefs.get(key)};
        // Let the transient XP notification expire before disposing its provider.
        await tester.pump(const Duration(seconds: 3));
        await tester.pumpAndSettle();

        // Dispose the full provider tree, then run the real entry point again with
        // the same mock preferences, not the previous in-memory providers/caches.
        await tester.pumpWidget(const SizedBox.shrink());
        BibleDataSource.clearCachesForTesting();
        app.main();
        await tester.pump();
        await tester.pumpAndSettle();
        await tester.runAsync(
          () => BibleDataSource().preloadBook('Genesis', BibleTranslation.asv),
        );
        await tester.pump();
        expect(find.text('Choose your Bible translation'), findsNothing);
        expect(find.byType(HomeScreen), findsOneWidget);
        expect(find.text('Status: Paused'), findsOneWidget);
        final restoredHome = tester.element(find.byType(HomeScreen));
        expect(
          restoredHome.read<BibleProvider>().selectedTranslation,
          BibleTranslation.asv,
        );
        expect(restoredHome.read<AppServicesProvider>().isOffline, isTrue);
        expect(
          restoredHome.read<AppServicesProvider>().profileSafetyBlocked,
          isTrue,
        );
        expect(restoredHome.read<AuthProvider>().accountChangesBlocked, isTrue);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pump(const Duration(seconds: 3));
        expect(Firebase.apps, isEmpty);
        expect({for (final key in prefs.getKeys()) key: prefs.get(key)}, saved);
        expect((await local.getUser()).readingProgress['Genesis'], contains(1));
        expect((await local.getUser()).totalXp, 10);
        expect(local.getBookmarks().single.note, 'Offline note');
        expect(local.getCloudSnapshot(), isNull);

        await tester.tap(find.widgetWithText(FloatingActionButton, 'Read'));
        await tester.pumpAndSettle();
        expect(find.text('Genesis 2'), findsOneWidget);
        await tester.tap(find.byTooltip('Choose chapter'));
        await tester.pumpAndSettle();
        expect(find.text('1 / 50 chapters'), findsOneWidget);
        await tester.tap(find.text('1'));
        await tester.pumpAndSettle();
        expect(
          find.text('In the beginning God created the heavens and the earth.'),
          findsOneWidget,
        );
        expect(
          find.byTooltip(
            'Remove bookmark for Genesis 1:1; long press to edit note',
          ),
          findsOneWidget,
        );
        expect(find.text('Mark as Read (+10 XP)'), findsNothing);
        await tester.pumpWidget(const SizedBox.shrink());
        expect(connectivityCalls, everyElement('check'));
        expect(connectivityCalls.length, 2);
        expect(connectivityEventCalls, contains('listen'));
        expect(httpAttempts, 0);
        debugDefaultTargetPlatformOverride = originalPlatform;
      },
      createHttpClient: (_) {
        httpAttempts++;
        throw StateError('Unexpected HTTP request during offline startup');
      },
    );
  });
}
