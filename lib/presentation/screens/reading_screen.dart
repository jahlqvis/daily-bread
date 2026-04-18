import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/bible_provider.dart';
import '../providers/bookmarks_provider.dart';
import '../providers/user_provider.dart';
import '../../core/constants/bible_translation.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/bible_passage_model.dart';
import '../widgets/translation_selector.dart';
import '../providers/reading_plan_provider.dart';
import 'bookmarks_screen.dart';
import 'chapter_selection_screen.dart';
import 'verse_search_screen.dart';
import 'reading_plans_screen.dart';

class ReadingScreen extends StatefulWidget {
  const ReadingScreen({super.key});

  @override
  State<ReadingScreen> createState() => _ReadingScreenState();
}

class _ReadingScreenState extends State<ReadingScreen> {
  String? _lastAutoScrolledTarget;
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

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
            icon: const Icon(Icons.format_list_numbered),
            tooltip: 'Choose chapter',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ChapterSelectionScreen()),
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
            icon: const Icon(Icons.search),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const VerseSearchScreen()),
            ),
          ),
        ],
      ),
      body: Consumer3<BibleProvider, UserProvider, BookmarksProvider>(
        builder:
            (context, bibleProvider, userProvider, bookmarksProvider, child) {
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

              final highlightedVerse = bibleProvider.highlightedVerse;
              final highlightedVerseKey = GlobalKey();
              if (highlightedVerse == null) {
                _lastAutoScrolledTarget = null;
              } else {
                _scheduleScrollToHighlightedVerse(
                  chapter: chapter,
                  highlightedVerse: highlightedVerse,
                  highlightedVerseKey: highlightedVerseKey,
                );
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
                    highlightedVerse,
                  ),
                  Expanded(
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: chapter.verses.length,
                      itemBuilder: (context, index) {
                        final passage = chapter.verses[index];
                        final isBookmarked = bookmarksProvider.isBookmarked(
                          passage.book,
                          passage.chapter,
                          passage.verse,
                          bibleProvider.selectedTranslation.id,
                        );

                        return _buildVerse(
                          context: context,
                          passage: passage,
                          displayNumber: passage.verse,
                          isHighlighted: highlightedVerse == passage.verse,
                          verseKey: highlightedVerse == passage.verse
                              ? highlightedVerseKey
                              : null,
                          isBookmarked: isBookmarked,
                          onToggleBookmark: () async {
                            await _toggleBookmark(
                              context,
                              bookmarksProvider: bookmarksProvider,
                              passage: passage,
                              translation: bibleProvider.selectedTranslation,
                              wasBookmarked: isBookmarked,
                            );
                          },
                        );
                      },
                    ),
                  ),
                  _buildChapterNavigation(context, bibleProvider),
                  if (!isRead) _buildMarkAsReadButton(context, chapter),
                ],
              );
            },
      ),
    );
  }

  void _scheduleScrollToHighlightedVerse({
    required BibleChapter chapter,
    required int highlightedVerse,
    required GlobalKey highlightedVerseKey,
  }) {
    final target = '${chapter.book}|${chapter.chapter}|$highlightedVerse';
    if (_lastAutoScrolledTarget == target) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      final targetContext = highlightedVerseKey.currentContext;
      if (targetContext == null) {
        _scrollToVerseByEstimate(
          highlightedVerse,
          chapter.verses.length,
          highlightedVerseKey,
          target,
        );
        return;
      }

      _lastAutoScrolledTarget = target;
      Scrollable.ensureVisible(
        targetContext,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
        alignment: 0.2,
      );
    });
  }

  void _scrollToVerseByEstimate(
    int highlightedVerse,
    int verseCount,
    GlobalKey highlightedVerseKey,
    String target,
  ) {
    if (!_scrollController.hasClients) {
      return;
    }

    final maxOffset = _scrollController.position.maxScrollExtent;
    final clampedVerseIndex = (highlightedVerse - 1).clamp(0, verseCount - 1);
    final progress = verseCount <= 1
        ? 0.0
        : clampedVerseIndex / (verseCount - 1);
    final desiredOffset = maxOffset * progress;
    final clampedOffset = desiredOffset.clamp(0.0, maxOffset);

    _scrollController
        .animateTo(
          clampedOffset,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOut,
        )
        .then((_) {
          if (!mounted) {
            return;
          }

          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) {
              return;
            }

            final targetContext = highlightedVerseKey.currentContext;
            if (targetContext != null) {
              _lastAutoScrolledTarget = target;
              Scrollable.ensureVisible(
                targetContext,
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                alignment: 0.2,
              );
              return;
            }

            _scrollToVerseByEndExpansion(
              highlightedVerseKey: highlightedVerseKey,
              target: target,
            );
          });
        });
  }

  Future<void> _scrollToVerseByEndExpansion({
    required GlobalKey highlightedVerseKey,
    required String target,
  }) async {
    if (!mounted || !_scrollController.hasClients) {
      return;
    }

    for (var attempt = 0; attempt < 6; attempt++) {
      final targetContext = highlightedVerseKey.currentContext;
      if (targetContext != null) {
        _lastAutoScrolledTarget = target;
        Scrollable.ensureVisible(
          targetContext,
          duration: const Duration(milliseconds: 170),
          curve: Curves.easeOut,
          alignment: 0.2,
        );
        return;
      }

      final beforeMax = _scrollController.position.maxScrollExtent;
      await _scrollController.animateTo(
        beforeMax,
        duration: const Duration(milliseconds: 190),
        curve: Curves.easeOut,
      );

      if (!mounted || !_scrollController.hasClients) {
        return;
      }

      await Future<void>.delayed(const Duration(milliseconds: 16));
      final afterMax = _scrollController.position.maxScrollExtent;
      final reachedEnd = (_scrollController.offset - afterMax).abs() < 1.0;
      final didNotGrow = (afterMax - beforeMax).abs() < 1.0;
      if (reachedEnd && didNotGrow) {
        break;
      }
    }

    if (!mounted) {
      return;
    }

    final finalContext = highlightedVerseKey.currentContext;
    if (finalContext != null) {
      _lastAutoScrolledTarget = target;
      Scrollable.ensureVisible(
        finalContext,
        duration: const Duration(milliseconds: 170),
        curve: Curves.easeOut,
        alignment: 0.2,
      );
    }
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

  Widget _buildVerse({
    required BuildContext context,
    required BiblePassage passage,
    required int displayNumber,
    required bool isHighlighted,
    required Key? verseKey,
    required bool isBookmarked,
    required VoidCallback onToggleBookmark,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: AnimatedContainer(
        key: verseKey,
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
            IconButton(
              onPressed: onToggleBookmark,
              onLongPress: () async {
                await _editBookmarkNote(
                  context,
                  passage: passage,
                  translation: context
                      .read<BibleProvider>()
                      .selectedTranslation,
                );
              },
              icon: Icon(
                isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                color: isBookmarked ? AppTheme.primaryColor : Colors.grey[600],
              ),
              tooltip: isBookmarked
                  ? 'Tap: remove, hold: edit note'
                  : 'Tap: add, hold: add note',
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editBookmarkNote(
    BuildContext context, {
    required BiblePassage passage,
    required BibleTranslation translation,
  }) async {
    final bookmarksProvider = context.read<BookmarksProvider>();
    final alreadyBookmarked = bookmarksProvider.isBookmarked(
      passage.book,
      passage.chapter,
      passage.verse,
      translation.id,
    );

    if (!alreadyBookmarked) {
      await bookmarksProvider.toggleBookmark(
        book: passage.book,
        chapter: passage.chapter,
        verse: passage.verse,
        translationId: translation.id,
      );

      if (!context.mounted) {
        return;
      }
    }

    final existing = bookmarksProvider.bookmarkFor(
      passage.book,
      passage.chapter,
      passage.verse,
      translation.id,
    );
    if (existing == null) {
      return;
    }

    final controller = TextEditingController(text: existing.note ?? '');
    final updatedNote = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('Note for ${passage.reference}'),
          content: TextField(
            controller: controller,
            maxLines: 4,
            minLines: 2,
            decoration: const InputDecoration(
              hintText: 'Write your note...',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, ''),
              child: const Text('Clear'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, controller.text),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (updatedNote == null) {
      return;
    }

    await bookmarksProvider.updateNote(
      passage.book,
      passage.chapter,
      passage.verse,
      translation.id,
      updatedNote,
    );

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            updatedNote.trim().isEmpty
                ? 'Cleared note for ${passage.reference}'
                : 'Updated note for ${passage.reference}',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _toggleBookmark(
    BuildContext context, {
    required BookmarksProvider bookmarksProvider,
    required BiblePassage passage,
    required BibleTranslation translation,
    required bool wasBookmarked,
  }) async {
    await bookmarksProvider.toggleBookmark(
      book: passage.book,
      chapter: passage.chapter,
      verse: passage.verse,
      translationId: translation.id,
    );

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            wasBookmarked
                ? 'Removed bookmark for ${passage.reference}'
                : 'Bookmarked ${passage.reference}',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
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
              final resumePlanChapter = planProvider.resumeReference(
                updatedUser,
                DateTime.now(),
              );
              final completedPlan =
                  isInPlan && planProvider.isCompleted(updatedUser);
              final earnedCompletionReward = completedPlan
                  ? await planProvider.claimCompletionRewardIfNeeded(
                      updatedUser,
                    )
                  : false;

              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      earnedCompletionReward
                          ? 'Amazing! You completed your active reading plan and unlocked a completion reward.'
                          : completedPlan
                          ? 'You have already completed this plan. Great consistency!'
                          : isInPlan && resumePlanChapter != null
                          ? 'Chapter marked as read! Next in your plan: ${resumePlanChapter.label}.'
                          : isInPlan && nextPlanChapter != null
                          ? 'Chapter marked as read! Continue with ${nextPlanChapter.label}.'
                          : 'Chapter marked as read! Keep up the great work!',
                    ),
                    backgroundColor: AppTheme.primaryColor,
                    action: earnedCompletionReward
                        ? SnackBarAction(
                            label: 'View Plans',
                            textColor: Colors.white,
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const ReadingPlansScreen(),
                                ),
                              );
                            },
                          )
                        : null,
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

  Widget _buildChapterNavigation(
    BuildContext context,
    BibleProvider bibleProvider,
  ) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () async {
                await _goToPreviousChapter(context, bibleProvider);
              },
              icon: const Icon(Icons.arrow_back),
              label: const Text('Previous'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () async {
                await _goToNextChapter(context, bibleProvider);
              },
              icon: const Icon(Icons.arrow_forward),
              label: const Text('Next'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _goToPreviousChapter(
    BuildContext context,
    BibleProvider bibleProvider,
  ) async {
    final currentBook = bibleProvider.selectedBook;
    final currentChapter = bibleProvider.selectedChapter;

    if (currentChapter > 1) {
      bibleProvider.selectChapter(currentChapter - 1);
      return;
    }

    final currentIndex = bibleProvider.books.indexOf(currentBook);
    if (currentIndex <= 0) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You are at the first chapter.')),
        );
      }
      return;
    }

    final previousBook = bibleProvider.books[currentIndex - 1];
    final previousBookChapterCount = bibleProvider.getChapterCount(
      previousBook,
    );
    await bibleProvider.selectBook(previousBook);
    bibleProvider.selectChapter(previousBookChapterCount);
  }

  Future<void> _goToNextChapter(
    BuildContext context,
    BibleProvider bibleProvider,
  ) async {
    final currentBook = bibleProvider.selectedBook;
    final currentChapter = bibleProvider.selectedChapter;
    final chapterCount = bibleProvider.getChapterCount(currentBook);

    if (currentChapter < chapterCount) {
      bibleProvider.selectChapter(currentChapter + 1);
      return;
    }

    final currentIndex = bibleProvider.books.indexOf(currentBook);
    if (currentIndex < 0 || currentIndex >= bibleProvider.books.length - 1) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You are at the final chapter.')),
        );
      }
      return;
    }

    final nextBook = bibleProvider.books[currentIndex + 1];
    await bibleProvider.selectBook(nextBook);
    bibleProvider.selectChapter(1);
  }
}
