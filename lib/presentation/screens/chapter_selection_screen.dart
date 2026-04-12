import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/bible_provider.dart';
import '../providers/user_provider.dart';
import '../../core/theme/app_theme.dart';
import '../widgets/translation_selector.dart';
import 'reading_screen.dart';

class ChapterSelectionScreen extends StatelessWidget {
  const ChapterSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Consumer<BibleProvider>(
          builder: (context, bibleProvider, _) {
            return Text(bibleProvider.selectedBook);
          },
        ),
        actions: const [TranslationSelector()],
      ),
      body: Consumer2<BibleProvider, UserProvider>(
        builder: (context, bibleProvider, userProvider, _) {
          final chapterCount = bibleProvider.getChapterCount(bibleProvider.selectedBook);
          final progress = userProvider.user.readingProgress[bibleProvider.selectedBook] ?? {};
          final readCount = progress.length;
          final totalCount = chapterCount;

          return Column(
            children: [
              _buildProgressHeader(readCount, totalCount),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 6,
                    childAspectRatio: 1,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: chapterCount,
                  itemBuilder: (context, index) {
                    final chapter = index + 1;
                    final isRead = progress.contains(chapter);
                    final hasData = bibleProvider.hasChapterData(
                      bibleProvider.selectedBook,
                      chapter,
                    );

                    return _buildChapterTile(
                      context,
                      chapter,
                      isRead,
                      hasData,
                      bibleProvider,
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildProgressHeader(int read, int total) {
    final progress = total > 0 ? read / total : 0.0;
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Progress',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                '$read / $total chapters',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: Colors.grey[200],
              valueColor: const AlwaysStoppedAnimation(AppTheme.primaryColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChapterTile(
    BuildContext context,
    int chapter,
    bool isRead,
    bool hasData,
    BibleProvider bibleProvider,
  ) {
    return InkWell(
      onTap: () {
        bibleProvider.selectChapter(chapter);
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ReadingScreen()),
        );
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        decoration: BoxDecoration(
          color: isRead
              ? AppTheme.primaryColor
              : hasData
                  ? AppTheme.primaryColor.withAlpha(25)
                  : Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            '$chapter',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isRead
                  ? Colors.white
                  : hasData
                      ? AppTheme.primaryColor
                      : Colors.grey,
            ),
          ),
        ),
      ),
    );
  }
}
