import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/bible_translation.dart';
import '../../data/models/verse_bookmark_model.dart';
import '../providers/bible_provider.dart';
import '../providers/bookmarks_provider.dart';
import 'reading_screen.dart';

class BookmarksScreen extends StatelessWidget {
  const BookmarksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bookmarks')),
      body: Consumer<BookmarksProvider>(
        builder: (context, bookmarksProvider, _) {
          if (bookmarksProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final bookmarks = bookmarksProvider.bookmarks;
          if (bookmarks.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No bookmarks yet. Save your favorite verses while reading.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return ListView.separated(
            itemCount: bookmarks.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final bookmark = bookmarks[index];
              return ListTile(
                title: Text(bookmark.reference),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_translationLabel(bookmark.translationId)),
                    if (bookmark.note != null &&
                        bookmark.note!.trim().isNotEmpty)
                      Text(
                        bookmark.note!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
                trailing: IconButton(
                  onPressed: () async {
                    await bookmarksProvider.removeBookmark(
                      bookmark.book,
                      bookmark.chapter,
                      bookmark.verse,
                      bookmark.translationId,
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Removed ${bookmark.reference} bookmark',
                          ),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Remove bookmark',
                ),
                onTap: () => _openBookmark(context, bookmark),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _openBookmark(
    BuildContext context,
    VerseBookmark bookmark,
  ) async {
    final bibleProvider = context.read<BibleProvider>();
    final translation = _translationFromId(bookmark.translationId);
    if (translation != null) {
      await bibleProvider.selectTranslation(translation);
    }
    await bibleProvider.selectBook(bookmark.book);
    bibleProvider.selectChapter(bookmark.chapter);
    bibleProvider.setHighlightedVerse(bookmark.verse);

    if (context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ReadingScreen()),
      );
    }
  }

  String _translationLabel(String translationId) {
    return _translationFromId(translationId)?.shortLabel ??
        translationId.toUpperCase();
  }

  BibleTranslation? _translationFromId(String id) {
    for (final translation in BibleTranslation.values) {
      if (translation.id == id) {
        return translation;
      }
    }
    return null;
  }
}
