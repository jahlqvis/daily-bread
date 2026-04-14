import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/user_provider.dart';
import '../providers/bible_provider.dart';
import '../providers/reading_plan_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/bible_translation.dart';
import '../widgets/translation_selector.dart';
import 'reading_screen.dart';
import 'progress_screen.dart';
import 'badges_screen.dart';
import 'book_selection_screen.dart';
import 'verse_search_screen.dart';
import 'reading_plans_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('DailyBread'),
        actions: [
          const TranslationSelector(),
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const VerseSearchScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.calendar_month),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ReadingPlansScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.emoji_events),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const BadgesScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.bar_chart),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProgressScreen()),
            ),
          ),
        ],
      ),
      body: Consumer<UserProvider>(
        builder: (context, userProvider, child) {
          final user = userProvider.user;
          final today = DateFormat('EEEE, MMMM d').format(DateTime.now());

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildWelcomeCard(today),
                const SizedBox(height: 16),
                _buildStreakCard(
                  context,
                  user.currentStreak,
                  user.longestStreak,
                ),
                const SizedBox(height: 16),
                _buildXpCard(context, userProvider),
                const SizedBox(height: 16),
                _buildTranslationCard(context),
                const SizedBox(height: 16),
                _buildPlanCard(context),
                const SizedBox(height: 16),
                _buildTodayReadingCard(context),
                if (userProvider.lastXpGain != null) ...[
                  const SizedBox(height: 16),
                  _buildXpGainBanner(userProvider.lastXpGain!),
                ],
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ReadingScreen()),
        ),
        icon: const Icon(Icons.menu_book),
        label: const Text('Read'),
      ),
    );
  }

  Widget _buildPlanCard(BuildContext context) {
    return Consumer2<ReadingPlanProvider, UserProvider>(
      builder: (context, planProvider, userProvider, _) {
        if (planProvider.isLoading) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        final activePlan = planProvider.activePlan;
        final nextChapter = planProvider.nextChapter(userProvider.user);

        if (activePlan == null) {
          return Card(
            child: InkWell(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ReadingPlansScreen()),
              ),
              borderRadius: BorderRadius.circular(16),
              child: const Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Reading Plan',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text('Start a plan to get a guided chapter each day.'),
                  ],
                ),
              ),
            ),
          );
        }

        final completed = planProvider.completedCount(userProvider.user);
        final progress = planProvider.progress(userProvider.user);

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Today\'s Plan',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ReadingPlansScreen(),
                        ),
                      ),
                      child: const Text('Manage'),
                    ),
                  ],
                ),
                Text(
                  activePlan.title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text('$completed / ${activePlan.totalDays} chapters completed'),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor: Colors.grey[200],
                    valueColor: const AlwaysStoppedAnimation(
                      AppTheme.primaryColor,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (nextChapter != null)
                  ElevatedButton.icon(
                    onPressed: () async {
                      final bibleProvider = context.read<BibleProvider>();
                      await bibleProvider.selectBook(nextChapter.book);
                      bibleProvider.selectChapter(nextChapter.chapter);
                      if (context.mounted) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ReadingScreen(),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.play_arrow),
                    label: Text('Read ${nextChapter.label}'),
                  )
                else
                  const Text(
                    'Plan complete! Pick a new one or keep exploring.',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryColor,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildWelcomeCard(String today) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              today,
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            const Text(
              'Ready for your daily reading?',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Keep your streak alive and grow in faith.',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStreakCard(
    BuildContext context,
    int currentStreak,
    int longestStreak,
  ) {
    return Card(
      color: AppTheme.streakFireColor.withAlpha(25),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: const BoxDecoration(
                color: AppTheme.streakFireColor,
                borderRadius: BorderRadius.all(Radius.circular(30)),
              ),
              child: const Icon(
                Icons.local_fire_department,
                color: Colors.white,
                size: 32,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '$currentStreak',
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.streakFireColor,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'day streak',
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                    ],
                  ),
                  Text(
                    'Best: $longestStreak days',
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildXpCard(BuildContext context, UserProvider userProvider) {
    final user = userProvider.user;
    return Card(
      color: AppTheme.xpGoldColor.withAlpha(25),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.levelPurpleColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      '${user.level}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Level ${user.level}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  '${user.totalXp} XP',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.xpGoldColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: userProvider.levelProgress,
                minHeight: 8,
                backgroundColor: Colors.grey[200],
                valueColor: const AlwaysStoppedAnimation(
                  AppTheme.levelPurpleColor,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${userProvider.xpToNextLevel} XP to Level ${user.level + 1}',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTranslationCard(BuildContext context) {
    return Consumer<BibleProvider>(
      builder: (context, bibleProvider, _) {
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Translation',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Choose the Bible translation you prefer for reading today.',
                  style: TextStyle(color: Colors.grey[600]),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: bibleProvider.availableTranslations
                      .map(
                        (translation) => ChoiceChip(
                          label: Text(translation.shortLabel),
                          selected:
                              bibleProvider.selectedTranslation == translation,
                          onSelected: (_) =>
                              bibleProvider.selectTranslation(translation),
                          selectedColor: AppTheme.primaryColor,
                          labelStyle: TextStyle(
                            color:
                                bibleProvider.selectedTranslation == translation
                                ? Colors.white
                                : AppTheme.primaryColor,
                            fontWeight: FontWeight.bold,
                          ),
                          side: const BorderSide(color: AppTheme.primaryColor),
                          backgroundColor: AppTheme.primaryColor.withAlpha(25),
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTodayReadingCard(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const BookSelectionScreen()),
        ),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withAlpha(25),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.auto_stories,
                  color: AppTheme.primaryColor,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Start Reading',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Tap to begin your daily reading',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildXpGainBanner(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
      decoration: BoxDecoration(
        color: AppTheme.xpGoldColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.star, color: Colors.white),
          const SizedBox(width: 8),
          Text(
            message,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}
