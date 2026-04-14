import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/bible_provider.dart';
import '../providers/user_provider.dart';
import '../../core/constants/bible_translation.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/bible_passage_model.dart';
import '../widgets/translation_selector.dart';
import '../providers/reading_plan_provider.dart';
import 'verse_search_screen.dart';

class ReadingScreen extends StatelessWidget {
  const ReadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Consumer<BibleProvider>(
          builder: (context, bibleProvider, _) {
            return Text(
              '${bibleProvider.selectedBook} ${bibleProvider.selectedChapter}',
            );
          },
        ),
        actions: [
          const TranslationSelector(),
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const VerseSearchScreen()),
            ),
          ),
        ],
      ),
      body: Consumer2<BibleProvider, UserProvider>(
        builder: (context, bibleProvider, userProvider, child) {
          if (bibleProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (bibleProvider.loadError != null) {
            return _buildLoadError(context, bibleProvider);
          }

          final chapter = bibleProvider.getCurrentChapter();
          if (chapter == null) {
            return _buildNoContent(context, bibleProvider);
          }

          final isRead =
              userProvider.user.readingProgress[chapter.book]?.contains(
                chapter.chapter,
              ) ??
              false;

          return Column(
            children: [
              _buildChapterHeader(
                chapter,
                isRead,
                bibleProvider.selectedTranslation.shortLabel,
                bibleProvider.highlightedVerse,
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: chapter.verses.length,
                  itemBuilder: (context, index) {
                    final passage = chapter.verses[index];
                    return _buildVerse(
                      passage,
                      passage.verse,
                      bibleProvider.highlightedVerse == passage.verse,
                    );
                  },
                ),
              ),
              if (!isRead) _buildMarkAsReadButton(context, chapter),
            ],
          );
        },
      ),
    );
  }

  Widget _buildLoadError(BuildContext context, BibleProvider bibleProvider) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 80, color: AppTheme.errorColor),
            const SizedBox(height: 24),
            const Text(
              'Load Failed',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              '${bibleProvider.selectedBook} ${bibleProvider.selectedChapter} (${bibleProvider.selectedTranslation.shortLabel})\n${bibleProvider.loadError}',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () async {
                await bibleProvider.retryCurrentSelection();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoContent(BuildContext context, BibleProvider bibleProvider) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.menu_book_outlined, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 24),
            const Text(
              'No Content Available',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              '${bibleProvider.selectedBook} ${bibleProvider.selectedChapter} is not available in ${bibleProvider.selectedTranslation.shortLabel}.\nTry a different chapter or translation.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChapterHeader(
    BibleChapter chapter,
    bool isRead,
    String translationLabel,
    int? highlightedVerse,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: isRead ? AppTheme.primaryColor.withAlpha(25) : Colors.grey[100],
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${chapter.reference} · $translationLabel',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${chapter.verses.length} verses',
                  style: TextStyle(color: Colors.grey[600]),
                ),
                if (highlightedVerse != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Jumped to verse $highlightedVerse',
                      style: const TextStyle(
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (isRead)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check, color: Colors.white, size: 16),
                  SizedBox(width: 4),
                  Text(
                    'Read',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildVerse(
    BiblePassage passage,
    int displayNumber,
    bool isHighlighted,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isHighlighted
              ? AppTheme.primaryColor.withAlpha(22)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isHighlighted
                ? AppTheme.primaryColor.withAlpha(90)
                : Colors.transparent,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withAlpha(25),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Text(
                  '$displayNumber',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                passage.text,
                style: const TextStyle(fontSize: 16, height: 1.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMarkAsReadButton(BuildContext context, BibleChapter chapter) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(25),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () async {
              final planProvider = context.read<ReadingPlanProvider>();
              final userProvider = context.read<UserProvider>();
              final isInPlan = planProvider.isChapterInActivePlan(
                chapter.book,
                chapter.chapter,
              );
              await userProvider.markChapterAsRead(
                chapter.book,
                chapter.chapter,
              );

              final updatedUser = userProvider.user;
              final nextPlanChapter = planProvider.nextChapter(updatedUser);

              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      isInPlan && nextPlanChapter != null
                          ? 'Chapter marked as read! Next in your plan: ${nextPlanChapter.label}.'
                          : 'Chapter marked as read! Keep up the great work!',
                    ),
                    backgroundColor: AppTheme.primaryColor,
                  ),
                );
              }
            },
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('Mark as Read (+10 XP)'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
      ),
    );
  }
}
