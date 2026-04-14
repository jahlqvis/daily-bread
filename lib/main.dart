import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/theme/app_theme.dart';
import 'data/datasources/local_data_source.dart';
import 'data/datasources/bible_data_source.dart';
import 'data/repositories/user_repository.dart';
import 'presentation/providers/user_provider.dart';
import 'presentation/providers/bible_provider.dart';
import 'presentation/providers/reading_plan_provider.dart';
import 'presentation/screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();

  final localDataSource = LocalDataSource(prefs);
  final bibleDataSource = BibleDataSource();
  final userRepository = UserRepository(localDataSource);

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
