import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/theme/app_theme.dart';
import 'data/datasources/local_data_source.dart';
import 'data/datasources/bible_data_source.dart';
import 'data/repositories/user_repository.dart';
import 'presentation/providers/user_provider.dart';
import 'presentation/providers/bible_provider.dart';
import 'presentation/providers/reading_plan_provider.dart';
import 'presentation/providers/bookmarks_provider.dart';
import 'presentation/providers/app_services_provider.dart';
import 'presentation/providers/auth_provider.dart';
import 'presentation/screens/home_screen.dart';
import 'services/auth/firebase_auth_service.dart';
import 'services/cloud/cloud_sync_service.dart';
import 'services/cloud/firebase_backend_config.dart';
import 'services/notifications/daily_reminder_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();

  final localDataSource = LocalDataSource(prefs);
  final bibleDataSource = BibleDataSource();
  final userRepository = UserRepository(localDataSource);
  final authService = FirebaseAuthService();
  final localCloudSyncService = LocalCloudSyncService(localDataSource);
  final cloudSyncService = FirebaseCloudSyncService(
    localDataSource: localDataSource,
    config: FirebaseBackendConfig.fromEnvironment(),
    fallback: localCloudSyncService,
  );
  final notificationsPlugin = FlutterLocalNotificationsPlugin();
  final dailyReminderService = LocalNotificationReminderService(
    localDataSource,
    notificationsPlugin,
  );
  await cloudSyncService.initialize();
  await dailyReminderService.initialize();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => UserProvider(userRepository)..loadUser(),
        ),
        ChangeNotifierProvider(
          create: (_) => BibleProvider(bibleDataSource)..loadBible(),
        ),
        ChangeNotifierProvider(
          create: (_) => ReadingPlanProvider(localDataSource)..loadPlanState(),
        ),
        ChangeNotifierProvider(
          create: (_) => BookmarksProvider(localDataSource)..loadBookmarks(),
        ),
        ChangeNotifierProvider(create: (_) => AuthProvider(authService)),
        ChangeNotifierProvider(
          create: (_) =>
              AppServicesProvider(
                cloudSyncService,
                dailyReminderService,
                localDataSource: localDataSource,
              ),
        ),
      ],
      child: const DailyBreadApp(),
    ),
  );
}

class DailyBreadApp extends StatelessWidget {
  const DailyBreadApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DailyBread',
      theme: AppTheme.lightTheme,
      debugShowCheckedModeBanner: false,
      home: const HomeScreen(),
    );
  }
}
