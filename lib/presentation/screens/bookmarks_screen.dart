import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.bookmarks_outlined, size: 56),
                    const SizedBox(height: 12),
                    const Text(
                      'No bookmarks yet. Save your favorite verses while reading.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ReadingScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.menu_book),
                      label: const Text('Start Reading'),
                    ),
                  ],
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
                    const SizedBox(height: 2),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _translationLabel(bookmark.translationId),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Text(
                          _createdLabel(bookmark.createdAt),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    if (bookmark.note != null &&
                        bookmark.note!.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        bookmark.note!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontStyle: FontStyle.italic),
                      ),
                    ],
                  ],
                ),
                trailing: PopupMenuButton<String>(
                  onSelected: (value) async {
                    if (value == 'edit_note') {
                      await _showEditNoteDialog(
                        context,
                        bookmarksProvider,
                        bookmark,
                      );
                      return;
                    }

                    if (value == 'remove') {
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
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem<String>(
                      value: 'edit_note',
                      child: Text(
                        bookmark.note == null || bookmark.note!.trim().isEmpty
                            ? 'Add note'
                            : 'Edit note',
                      ),
                    ),
                    const PopupMenuItem<String>(
                      value: 'remove',
                      child: Text('Remove bookmark'),
                    ),
                  ],
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

  String _createdLabel(DateTime dateTime) {
    return DateFormat('MMM d, y').format(dateTime);
  }

  Future<void> _showEditNoteDialog(
    BuildContext context,
    BookmarksProvider bookmarksProvider,
    VerseBookmark bookmark,
  ) async {
    final controller = TextEditingController(text: bookmark.note ?? '');

    final updatedNote = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('Note for ${bookmark.reference}'),
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
      bookmark.book,
      bookmark.chapter,
      bookmark.verse,
      bookmark.translationId,
      updatedNote,
    );

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bookmark note updated'),
          duration: Duration(seconds: 2),
        ),
      );
    }
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
