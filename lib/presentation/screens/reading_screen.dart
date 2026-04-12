import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/bible_provider.dart';
import '../providers/user_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/bible_passage_model.dart';

class ReadingScreen extends StatelessWidget {
  const ReadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Consumer<BibleProvider>(
          builder: (context, bibleProvider, _) {
            return Text('${bibleProvider.selectedBook} ${bibleProvider.selectedChapter}');
          },
        ),
      ),
      body: Consumer2<BibleProvider, UserProvider>(
        builder: (context, bibleProvider, userProvider, child) {
          if (bibleProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final chapter = bibleProvider.getCurrentChapter();
          if (chapter == null) {
            return _buildComingSoon(context, bibleProvider);
          }

          final isRead = userProvider.user.readingProgress[chapter.book]?.contains(chapter.chapter) ?? false;

          return Column(
            children: [
              _buildChapterHeader(chapter, isRead),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: chapter.verses.length,
                  itemBuilder: (context, index) {
                    return _buildVerse(chapter.verses[index], index + 1);
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

  Widget _buildComingSoon(BuildContext context, BibleProvider bibleProvider) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.book_outlined,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 24),
            const Text(
              'Coming Soon',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${bibleProvider.selectedBook} ${bibleProvider.selectedChapter}\nwill be available soon.\nFor now, enjoy the sample passages.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChapterHeader(BibleChapter chapter, bool isRead) {
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
                  chapter.reference,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${chapter.verses.length} verses',
                  style: TextStyle(color: Colors.grey[600]),
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
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildVerse(BiblePassage passage, int displayNumber) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
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
              style: const TextStyle(
                fontSize: 16,
                height: 1.6,
              ),
            ),
          ),
        ],
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
              await context.read<UserProvider>().markChapterAsRead(
                    chapter.book,
                    chapter.chapter,
                  );
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Chapter marked as read! Keep up the great work!'),
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
