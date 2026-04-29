import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/user_provider.dart';
import '../providers/bible_provider.dart';
import '../providers/reading_plan_provider.dart';
import '../providers/bookmarks_provider.dart';
import '../providers/app_services_provider.dart';
import '../providers/auth_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/bible_translation.dart';
import '../widgets/translation_selector.dart';
import '../utils/sync_diagnostics_formatter.dart';
import 'reading_screen.dart';
import 'progress_screen.dart';
import 'badges_screen.dart';
import 'book_selection_screen.dart';
import 'verse_search_screen.dart';
import 'reading_plans_screen.dart';
import 'bookmarks_screen.dart';
import 'sign_in_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    this.enableAutoSync = true,
    this.onReportSyncDiagnostics,
  });

  final bool enableAutoSync;
  final Future<void> Function(String diagnostics)? onReportSyncDiagnostics;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  static const Duration _bookmarkSyncDebounceDelay = Duration(seconds: 2);

  Timer? _bookmarkSyncDebounce;
  bool _isSyncInFlight = false;
  bool _suppressBookmarkObserver = false;
  String? _lastBookmarksSignature;
  BookmarksProvider? _bookmarksProviderListener;

  @override
  void initState() {
    super.initState();
    if (!widget.enableAutoSync) {
      return;
    }
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      final bookmarksProvider = context.read<BookmarksProvider>();
      _lastBookmarksSignature = _bookmarkSignature(bookmarksProvider);
      _bookmarksProviderListener = bookmarksProvider;
      bookmarksProvider.addListener(_onBookmarksChanged);
      _scheduleAutoSync(reason: 'launch');
    });
  }

  @override
  void dispose() {
    if (widget.enableAutoSync) {
      WidgetsBinding.instance.removeObserver(this);
    }
    _bookmarkSyncDebounce?.cancel();
    _bookmarksProviderListener?.removeListener(_onBookmarksChanged);
    _bookmarksProviderListener = null;
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!widget.enableAutoSync) {
      return;
    }
    if (state == AppLifecycleState.resumed) {
      _scheduleAutoSync(reason: 'resume');
    }
  }

  void _onBookmarksChanged() {
    if (!mounted || _suppressBookmarkObserver) {
      return;
    }

    final bookmarksProvider = context.read<BookmarksProvider>();
    if (bookmarksProvider.isLoading) {
      return;
    }

    final signature = _bookmarkSignature(bookmarksProvider);
    if (signature == _lastBookmarksSignature) {
      return;
    }

    _lastBookmarksSignature = signature;
    _bookmarkSyncDebounce?.cancel();
    _bookmarkSyncDebounce = Timer(
      _bookmarkSyncDebounceDelay,
      () => _scheduleAutoSync(reason: 'bookmark_change'),
    );
  }

  String _bookmarkSignature(BookmarksProvider provider) {
    final bookmarkTokens =
        provider.bookmarks
            .map(
              (bookmark) =>
                  '${bookmark.id}:${bookmark.updatedAt.toIso8601String()}',
            )
            .toList()
          ..sort();
    final tombstoneTokens =
        provider.tombstones.entries
            .map((entry) => '${entry.key}:${entry.value.toIso8601String()}')
            .toList()
          ..sort();
    return '${bookmarkTokens.join(',')}|${tombstoneTokens.join(',')}';
  }

  void _scheduleAutoSync({required String reason}) {
    unawaited(_performSync(showFeedback: false, reason: reason));
  }

  Future<void> _performSync({
    required bool showFeedback,
    required String reason,
  }) async {
    if (!mounted || _isSyncInFlight) {
      return;
    }

    final authProvider = context.read<AuthProvider>();
    if (!_hasAccountLinkedSync(authProvider)) {
      if (showFeedback && mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SignInScreen()),
        );
      }
      return;
    }

    final servicesProvider = context.read<AppServicesProvider>();
    final userProvider = context.read<UserProvider>();
    final bookmarksProvider = context.read<BookmarksProvider>();

    if (userProvider.isLoading || bookmarksProvider.isLoading) {
      _bookmarkSyncDebounce?.cancel();
      _bookmarkSyncDebounce = Timer(
        _bookmarkSyncDebounceDelay,
        () => _scheduleAutoSync(reason: reason),
      );
      return;
    }

    _isSyncInFlight = true;
    _suppressBookmarkObserver = true;
    try {
      await servicesProvider.syncNow(
        user: userProvider.user,
        bookmarks: bookmarksProvider.bookmarks,
        tombstones: bookmarksProvider.tombstones,
        reason: reason,
        onSynced: () async {
          await userProvider.loadUser();
          await bookmarksProvider.loadBookmarks();
        },
      );
      if (!mounted) {
        return;
      }

      _lastBookmarksSignature = _bookmarkSignature(bookmarksProvider);

      if (showFeedback && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(servicesProvider.syncMessage ?? 'Sync completed'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
      servicesProvider.clearSyncMessage();
    } finally {
      _suppressBookmarkObserver = false;
      _isSyncInFlight = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('DailyBread'),
        actions: [
          const TranslationSelector(),
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SignInScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const VerseSearchScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.bookmarks_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const BookmarksScreen()),
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
                _buildSyncAndReminderCard(context),
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
        onPressed: () async {
          await _openSmartReading(context);
        },
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
        final status = planProvider.activePlanStatus(userProvider.user);
        final isCompleted = status == ReadingPlanStatus.activeCompleted;
        final hasClaimedReward = planProvider.hasClaimedCompletionReward(
          activePlan.id,
        );
        final resumeReference = planProvider.resumeReference(
          userProvider.user,
          DateTime.now(),
        );

        final statusLabel = switch (status) {
          ReadingPlanStatus.activeInProgress => 'Active',
          ReadingPlanStatus.activeCompleted => 'Completed',
          ReadingPlanStatus.paused => 'Paused',
          ReadingPlanStatus.completed => 'Completed',
          ReadingPlanStatus.inactive => 'Not Active',
        };

        final statusColor = switch (status) {
          ReadingPlanStatus.activeInProgress => AppTheme.primaryColor,
          ReadingPlanStatus.activeCompleted => Colors.green,
          ReadingPlanStatus.paused => Colors.orange,
          ReadingPlanStatus.completed => Colors.green,
          ReadingPlanStatus.inactive => Colors.grey,
        };

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
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (isCompleted && hasClaimedReward)
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text(
                      'Reward claimed: Plan Finisher',
                      style: TextStyle(
                        color: Colors.amber,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
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
                if (status == ReadingPlanStatus.activeCompleted)
                  ElevatedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ReadingPlansScreen(),
                      ),
                    ),
                    icon: const Icon(Icons.flag),
                    label: const Text('Start New Plan'),
                  )
                else if (resumeReference != null)
                  ElevatedButton.icon(
                    onPressed: () async {
                      final bibleProvider = context.read<BibleProvider>();
                      await bibleProvider.selectBook(resumeReference.book);
                      bibleProvider.selectChapter(resumeReference.chapter);
                      if (context.mounted) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ReadingScreen(),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.play_circle_outline),
                    label: Text('Continue Plan (${resumeReference.label})'),
                  )
                else if (nextChapter != null)
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

  Widget _buildSyncAndReminderCard(BuildContext context) {
    return Consumer2<AppServicesProvider, AuthProvider>(
      builder: (context, servicesProvider, authProvider, _) {
        final syncedAt = servicesProvider.lastSyncedAt;
        final syncedLabel = syncedAt == null
            ? 'Not synced yet'
            : 'Last synced ${DateFormat('MMM d, HH:mm').format(syncedAt)}';
        final backendLabel = servicesProvider.cloudBackendLabel;
        final hasAccountLinkedSync = _hasAccountLinkedSync(authProvider);

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Backup & Reminders',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Backend: $backendLabel',
                  style: TextStyle(color: Colors.grey[700]),
                ),
                const SizedBox(height: 4),
                Text(syncedLabel, style: TextStyle(color: Colors.grey[700])),
                const SizedBox(height: 4),
                Text(
                  _syncStatusLabel(servicesProvider),
                  style: TextStyle(
                    color: _syncStatusColor(servicesProvider),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Successes: ${servicesProvider.syncSuccessCount} • Failures: ${servicesProvider.syncFailureCount} • Retries scheduled: ${servicesProvider.syncRetryScheduledCount}',
                  style: TextStyle(color: Colors.grey[700], fontSize: 13),
                ),
                const SizedBox(height: 2),
                Text(
                  'Last outcome: ${_syncOutcomeLabel(servicesProvider)}',
                  style: TextStyle(color: Colors.grey[700], fontSize: 13),
                ),
                const SizedBox(height: 2),
                Text(
                  'Sync health: ${servicesProvider.syncHealthLabel}',
                  style: TextStyle(
                    color: _syncHealthColor(servicesProvider),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (!hasAccountLinkedSync) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Sign in to back up and sync across devices.',
                    style: TextStyle(
                      color: Colors.grey[800],
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: servicesProvider.isSyncing
                        ? null
                        : () => _performSync(
                            showFeedback: true,
                            reason: 'manual',
                          ),
                    icon: servicesProvider.isSyncing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(
                            hasAccountLinkedSync
                                ? Icons.cloud_upload_outlined
                                : Icons.lock_outline,
                          ),
                    label: Text(
                      servicesProvider.isSyncing
                          ? 'Syncing...'
                          : hasAccountLinkedSync
                          ? 'Sync now'
                          : 'Sign in to sync',
                    ),
                  ),
                ),
                if (servicesProvider.syncStatus == SyncStatus.failed) ...[
                  const SizedBox(height: 8),
                  Text(
                    _syncErrorSummary(servicesProvider),
                    style: TextStyle(color: Colors.red[700]),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: servicesProvider.isSyncing
                            ? null
                            : () => _performSync(
                                showFeedback: true,
                                reason: 'manual_retry',
                              ),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry now'),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () =>
                            _showSyncDetailsDialog(context, servicesProvider),
                        child: const Text('View details'),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Daily reading reminder'),
                  subtitle: Text(
                    servicesProvider.reminderSupported
                        ? 'Reminder set for ${servicesProvider.reminderTime}'
                        : 'Reminders are unavailable on this platform.',
                  ),
                  value: servicesProvider.reminderEnabled,
                  onChanged: servicesProvider.reminderSupported
                      ? (value) async {
                          await servicesProvider.setReminderEnabled(value);
                          if (context.mounted &&
                              servicesProvider.reminderMessage != null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  servicesProvider.reminderMessage!,
                                ),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                            servicesProvider.clearReminderMessage();
                          }
                        }
                      : null,
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: servicesProvider.reminderSupported
                        ? () async {
                            final initialTime = _parseReminderTime(
                              servicesProvider.reminderTime,
                            );
                            final picked = await showTimePicker(
                              context: context,
                              initialTime: initialTime,
                            );
                            if (picked == null) {
                              return;
                            }

                            final hh = picked.hour.toString().padLeft(2, '0');
                            final mm = picked.minute.toString().padLeft(2, '0');
                            await servicesProvider.setReminderTime('$hh:$mm');
                            if (context.mounted &&
                                servicesProvider.reminderMessage != null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    servicesProvider.reminderMessage!,
                                  ),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                              servicesProvider.clearReminderMessage();
                            }
                          }
                        : null,
                    icon: const Icon(Icons.schedule),
                    label: Text(
                      'Reminder time: ${servicesProvider.reminderTime}',
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  TimeOfDay _parseReminderTime(String hhmm) {
    final parts = hhmm.split(':');
    final hour = parts.isNotEmpty ? int.tryParse(parts.first) ?? 8 : 8;
    final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    return TimeOfDay(hour: hour.clamp(0, 23), minute: minute.clamp(0, 59));
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
    return Consumer3<BibleProvider, ReadingPlanProvider, UserProvider>(
      builder: (context, bibleProvider, planProvider, userProvider, _) {
        final smartTarget = _resolveSmartReadingTarget(
          bibleProvider,
          planProvider,
          userProvider,
        );

        return Card(
          child: InkWell(
            onTap: () async {
              await _openSmartReading(context);
            },
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
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Continue Reading',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Next up: ${smartTarget.$1} ${smartTarget.$2}',
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.tune),
                    tooltip: 'Choose book/chapter',
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const BookSelectionScreen(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  (String, int) _resolveSmartReadingTarget(
    BibleProvider bibleProvider,
    ReadingPlanProvider planProvider,
    UserProvider userProvider,
  ) {
    final resumeReference = planProvider.resumeReference(
      userProvider.user,
      DateTime.now(),
    );
    if (resumeReference != null) {
      return (resumeReference.book, resumeReference.chapter);
    }

    final selectedBook = bibleProvider.selectedBook;
    final chapterCount = bibleProvider.getChapterCount(selectedBook);
    final readChapters = userProvider.user.readingProgress[selectedBook] ?? {};

    for (var chapter = 1; chapter <= chapterCount; chapter++) {
      if (!readChapters.contains(chapter)) {
        return (selectedBook, chapter);
      }
    }

    for (final book in bibleProvider.books) {
      final bookChapterCount = bibleProvider.getChapterCount(book);
      final progress = userProvider.user.readingProgress[book] ?? {};
      for (var chapter = 1; chapter <= bookChapterCount; chapter++) {
        if (!progress.contains(chapter)) {
          return (book, chapter);
        }
      }
    }

    return (selectedBook, bibleProvider.selectedChapter);
  }

  Future<void> _openSmartReading(BuildContext context) async {
    final bibleProvider = context.read<BibleProvider>();
    final planProvider = context.read<ReadingPlanProvider>();
    final userProvider = context.read<UserProvider>();
    final target = _resolveSmartReadingTarget(
      bibleProvider,
      planProvider,
      userProvider,
    );

    if (bibleProvider.selectedBook != target.$1) {
      await bibleProvider.selectBook(target.$1);
    }
    bibleProvider.selectChapter(target.$2);

    if (context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ReadingScreen()),
      );
    }
  }

  String _syncStatusLabel(AppServicesProvider servicesProvider) {
    if (servicesProvider.isOffline &&
        (servicesProvider.syncStatus == SyncStatus.pending ||
            servicesProvider.syncStatus == SyncStatus.retrying)) {
      return 'Offline. Sync queued until connection returns.';
    }

    switch (servicesProvider.syncStatus) {
      case SyncStatus.idle:
        return 'Status: Synced';
      case SyncStatus.pending:
        return 'Status: Pending';
      case SyncStatus.syncing:
        return 'Status: Syncing';
      case SyncStatus.retrying:
        final nextRetryAt = servicesProvider.nextRetryAt;
        if (nextRetryAt == null) {
          return 'Status: Retrying';
        }
        final secondsLeft = nextRetryAt
            .difference(DateTime.now())
            .inSeconds
            .clamp(0, 9999);
        return 'Status: Retrying in ${secondsLeft}s';
      case SyncStatus.failed:
        return 'Status: Failed';
    }
  }

  bool _hasAccountLinkedSync(AuthProvider authProvider) {
    return authProvider.isAuthenticated && !authProvider.isAnonymous;
  }

  String _syncErrorSummary(AppServicesProvider servicesProvider) {
    final category = servicesProvider.lastSyncErrorCategory;
    final code = servicesProvider.lastSyncErrorCode;
    if (category == SyncErrorCategory.none) {
      return 'Last sync failed.';
    }
    final categoryLabel = _syncCategoryLabel(category);
    if (code == null || code.isEmpty || code == 'unknown') {
      return 'Reason: $categoryLabel issue';
    }
    return 'Reason: $categoryLabel issue ($code)';
  }

  Future<void> _showSyncDetailsDialog(
    BuildContext parentContext,
    AppServicesProvider servicesProvider,
  ) async {
    final attempted = servicesProvider.lastSyncAttemptAt;
    final lastSuccess = servicesProvider.lastSyncSuccessAt;
    final nextRetryAt = servicesProvider.nextRetryAt;
    final errorMessage = servicesProvider.lastSyncErrorMessage ?? 'N/A';

    await showDialog<void>(
      context: parentContext,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Sync details'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Status: ${servicesProvider.syncStatus.name}'),
                Text('Health: ${servicesProvider.syncHealthLabel}'),
                Text(
                  'Category: ${_syncCategoryLabel(servicesProvider.lastSyncErrorCategory)}',
                ),
                Text(
                  'Code: ${servicesProvider.lastSyncErrorCode ?? 'unknown'}',
                ),
                Text('Successes: ${servicesProvider.syncSuccessCount}'),
                Text('Failures: ${servicesProvider.syncFailureCount}'),
                Text(
                  'Retries scheduled: ${servicesProvider.syncRetryScheduledCount}',
                ),
                Text('Last outcome: ${_syncOutcomeLabel(servicesProvider)}'),
                Text('Retry attempts: ${servicesProvider.retryCount}'),
                Text(
                  'Last attempt: ${attempted == null ? 'N/A' : DateFormat('MMM d, HH:mm:ss').format(attempted)}',
                ),
                Text(
                  'Last success: ${lastSuccess == null ? 'N/A' : DateFormat('MMM d, HH:mm:ss').format(lastSuccess)}',
                ),
                Text(
                  'Next retry: ${nextRetryAt == null ? 'N/A' : DateFormat('MMM d, HH:mm:ss').format(nextRetryAt)}',
                ),
                const SizedBox(height: 8),
                Text('Error: $errorMessage'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                final diagnostics = _syncDiagnosticsText(servicesProvider);
                await Clipboard.setData(ClipboardData(text: diagnostics));
                if (!parentContext.mounted) {
                  return;
                }
                ScaffoldMessenger.of(parentContext).showSnackBar(
                  const SnackBar(
                    content: Text('Diagnostics copied'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              child: const Text('Copy diagnostics'),
            ),
            TextButton(
              onPressed: () async {
                final diagnostics = _syncDiagnosticsText(servicesProvider);
                try {
                  if (widget.onReportSyncDiagnostics != null) {
                    await widget.onReportSyncDiagnostics!(diagnostics);
                  } else {
                    await Share.share(
                      diagnostics,
                      subject: 'DailyBread Sync Diagnostics',
                    );
                  }
                  if (!parentContext.mounted) {
                    return;
                  }
                  ScaffoldMessenger.of(parentContext).showSnackBar(
                    const SnackBar(
                      content: Text('Diagnostics ready to share'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                } catch (_) {
                  if (!parentContext.mounted) {
                    return;
                  }
                  ScaffoldMessenger.of(parentContext).showSnackBar(
                    const SnackBar(
                      content: Text('Sharing not available'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              },
              child: const Text('Report issue'),
            ),
            TextButton(
              onPressed: servicesProvider.isSyncing
                  ? null
                  : () async {
                      await servicesProvider.resetSyncDiagnostics();
                      if (!parentContext.mounted) {
                        return;
                      }
                      Navigator.of(dialogContext).pop();
                      ScaffoldMessenger.of(parentContext).showSnackBar(
                        const SnackBar(
                          content: Text('Diagnostics reset'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
              child: const Text('Reset diagnostics'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  String _syncDiagnosticsText(AppServicesProvider servicesProvider) {
    final diagnostics = buildSyncDiagnosticsText(
      backend: servicesProvider.cloudBackendLabel,
      status: servicesProvider.syncStatus.name,
      health: servicesProvider.syncHealthLabel,
      isOffline: servicesProvider.isOffline,
      category: _syncCategoryLabel(servicesProvider.lastSyncErrorCategory),
      code: servicesProvider.lastSyncErrorCode ?? 'unknown',
      retryAttempts: servicesProvider.retryCount,
      successes: servicesProvider.syncSuccessCount,
      failures: servicesProvider.syncFailureCount,
      retriesScheduled: servicesProvider.syncRetryScheduledCount,
      lastAttemptAt: servicesProvider.lastSyncAttemptAt,
      lastSuccessAt: servicesProvider.lastSyncSuccessAt,
      lastOutcome: servicesProvider.lastSyncOutcome?.name,
      lastOutcomeAt: servicesProvider.lastSyncOutcomeAt,
      nextRetryAt: servicesProvider.nextRetryAt,
      error: servicesProvider.lastSyncErrorMessage ?? 'N/A',
    );
    return redactSyncDiagnosticsText(diagnostics);
  }

  Color _syncStatusColor(AppServicesProvider servicesProvider) {
    switch (servicesProvider.syncStatus) {
      case SyncStatus.idle:
        return Colors.green[700]!;
      case SyncStatus.pending:
        return Colors.orange[800]!;
      case SyncStatus.syncing:
        return AppTheme.primaryColor;
      case SyncStatus.retrying:
        return Colors.orange[800]!;
      case SyncStatus.failed:
        return Colors.red[700]!;
    }
  }

  String _syncCategoryLabel(SyncErrorCategory category) {
    switch (category) {
      case SyncErrorCategory.none:
        return 'Unknown';
      case SyncErrorCategory.network:
        return 'Network';
      case SyncErrorCategory.auth:
        return 'Authentication';
      case SyncErrorCategory.permission:
        return 'Permission';
      case SyncErrorCategory.validation:
        return 'Validation';
      case SyncErrorCategory.server:
        return 'Server';
      case SyncErrorCategory.unknown:
        return 'Unknown';
    }
  }

  String _syncOutcomeLabel(AppServicesProvider servicesProvider) {
    final outcome = servicesProvider.lastSyncOutcome;
    final at = servicesProvider.lastSyncOutcomeAt;
    if (outcome == null || at == null) {
      return 'N/A';
    }
    final outcomeLabel = outcome == SyncOutcome.success ? 'Success' : 'Failure';
    return '$outcomeLabel at ${DateFormat('MMM d, HH:mm:ss').format(at)}';
  }

  Color _syncHealthColor(AppServicesProvider servicesProvider) {
    switch (servicesProvider.syncHealth) {
      case SyncHealth.unknown:
        return Colors.grey[700]!;
      case SyncHealth.healthy:
        return Colors.green[700]!;
      case SyncHealth.degraded:
        return Colors.orange[800]!;
      case SyncHealth.critical:
        return Colors.red[700]!;
    }
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
