import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../../core/theme/app_theme.dart';

class BadgesScreen extends StatelessWidget {
  const BadgesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Badges'),
      ),
      body: Consumer<UserProvider>(
        builder: (context, userProvider, _) {
          final earnedBadges = userProvider.user.badges;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildBadgesSection('Reading Streaks', [
                _Badge(
                  id: 'streak_7',
                  name: 'Week Warrior',
                  description: 'Maintain a 7-day streak',
                  icon: Icons.local_fire_department,
                  color: Colors.orange,
                ),
                _Badge(
                  id: 'streak_30',
                  name: 'Month Master',
                  description: 'Maintain a 30-day streak',
                  icon: Icons.local_fire_department,
                  color: Colors.deepOrange,
                ),
                _Badge(
                  id: 'streak_100',
                  name: 'Century Reader',
                  description: 'Maintain a 100-day streak',
                  icon: Icons.local_fire_department,
                  color: Colors.red,
                ),
              ], earnedBadges),
              const SizedBox(height: 24),
              _buildBadgesSection('Levels', [
                _Badge(
                  id: 'level_5',
                  name: 'Rising Star',
                  description: 'Reach level 5',
                  icon: Icons.star,
                  color: AppTheme.xpGoldColor,
                ),
                _Badge(
                  id: 'level_10',
                  name: 'Scripture Scholar',
                  description: 'Reach level 10',
                  icon: Icons.school,
                  color: AppTheme.levelPurpleColor,
                ),
              ], earnedBadges),
              const SizedBox(height: 24),
              _buildBadgesSection('Achievements', [
                _Badge(
                  id: 'first_read',
                  name: 'First Steps',
                  description: 'Read your first chapter',
                  icon: Icons.flag,
                  color: Colors.green,
                ),
                _Badge(
                  id: 'bookworm',
                  name: 'Bookworm',
                  description: 'Complete an entire book of the Bible',
                  icon: Icons.auto_stories,
                  color: Colors.brown,
                ),
                _Badge(
                  id: 'xp_1000',
                  name: 'XP Hunter',
                  description: 'Earn 1000 XP',
                  icon: Icons.stars,
                  color: Colors.amber,
                ),
              ], earnedBadges),
              const SizedBox(height: 24),
              _buildBadgesSection('Special', [
                _Badge(
                  id: 'streak_freeze',
                  name: 'Ice Breaker',
                  description: 'Use a streak freeze to save your streak',
                  icon: Icons.ac_unit,
                  color: Colors.lightBlue,
                ),
              ], earnedBadges),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBadgesSection(String title, List<_Badge> badges, List<String> earned) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: 0.85,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: badges.length,
          itemBuilder: (context, index) {
            final badge = badges[index];
            final isEarned = earned.contains(badge.id);
            return _buildBadgeCard(badge, isEarned);
          },
        ),
      ],
    );
  }

  Widget _buildBadgeCard(_Badge badge, bool isEarned) {
    return Container(
      decoration: BoxDecoration(
        color: isEarned ? badge.color.withAlpha(25) : Colors.grey[100],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isEarned ? badge.color : Colors.grey[300]!,
          width: 2,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            badge.icon,
            size: 40,
            color: isEarned ? badge.color : Colors.grey,
          ),
          const SizedBox(height: 8),
          Text(
            badge.name,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isEarned ? Colors.black87 : Colors.grey,
            ),
          ),
          const SizedBox(height: 4),
          if (isEarned)
            const Icon(
              Icons.check_circle,
              size: 16,
              color: Colors.green,
            )
          else
            Icon(
              Icons.lock,
              size: 16,
              color: Colors.grey[400],
            ),
        ],
      ),
    );
  }
}

class _Badge {
  final String id;
  final String name;
  final String description;
  final IconData icon;
  final Color color;

  _Badge({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.color,
  });
}
