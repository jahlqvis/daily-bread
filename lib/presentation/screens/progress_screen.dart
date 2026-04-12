import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';

class ProgressScreen extends StatelessWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Progress'),
      ),
      body: Consumer<UserProvider>(
        builder: (context, userProvider, _) {
          final user = userProvider.user;
          final totalBooks = AppConstants.booksOfTheBible.length;
          final booksStarted = user.readingProgress.keys.length;
          final totalChaptersRead = user.readingProgress.values
              .fold<int>(0, (sum, chapters) => sum + chapters.length);
          final totalChapters = AppConstants.chaptersPerBook.values
              .fold<int>(0, (sum, count) => sum + count);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildStatsCard(
                'Reading Stats',
                [
                  _StatItem('Current Streak', '${user.currentStreak} days', Icons.local_fire_department),
                  _StatItem('Longest Streak', '${user.longestStreak} days', Icons.emoji_events),
                  _StatItem('Total XP', '${user.totalXp}', Icons.star),
                  _StatItem('Level', '${user.level}', Icons.trending_up),
                ],
              ),
              const SizedBox(height: 16),
              _buildStatsCard(
                'Bible Progress',
                [
                  _StatItem('Books Started', '$booksStarted / $totalBooks', Icons.book),
                  _StatItem('Chapters Read', '$totalChaptersRead / $totalChapters', Icons.menu_book),
                  _StatItem('Badges Earned', '${user.badges.length}', Icons.verified),
                  _StatItem('Streak Freezes', '${user.streakFreezes}', Icons.ac_unit),
                ],
              ),
              const SizedBox(height: 16),
              _buildProgressCard(totalChaptersRead, totalChapters),
              const SizedBox(height: 16),
              _buildBookProgressList(user.readingProgress),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatsCard(String title, List<_StatItem> items) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ...items.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withAlpha(25),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(item.icon, color: AppTheme.primaryColor, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          item.label,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                      Text(
                        item.value,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressCard(int read, int total) {
    final progress = total > 0 ? read / total : 0.0;
    final percentage = (progress * 100).toStringAsFixed(1);

    return Card(
      color: AppTheme.primaryColor.withAlpha(25),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text(
              'Overall Bible Progress',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 120,
                  height: 120,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 12,
                    backgroundColor: Colors.white,
                    valueColor: const AlwaysStoppedAnimation(AppTheme.primaryColor),
                  ),
                ),
                Text(
                  '$percentage%',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              '$read of $total chapters read',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookProgressList(Map<String, Set<int>> progress) {
    if (progress.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: Text(
              'Start reading to see your progress!',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Books Progress',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ...progress.entries.map((entry) {
              final book = entry.key;
              final chapters = entry.value;
              final total = AppConstants.chaptersPerBook[book] ?? 1;
              final bookProgress = chapters.length / total;

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(book),
                        Text('${chapters.length}/$total'),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: bookProgress,
                        minHeight: 6,
                        backgroundColor: Colors.grey[200],
                        valueColor: const AlwaysStoppedAnimation(AppTheme.primaryColor),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _StatItem {
  final String label;
  final String value;
  final IconData icon;

  _StatItem(this.label, this.value, this.icon);
}
