import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/bible_provider.dart';
import '../../core/theme/app_theme.dart';

class BookSelectionScreen extends StatelessWidget {
  const BookSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Book'),
      ),
      body: Consumer<BibleProvider>(
        builder: (context, bibleProvider, _) {
          final oldTestament = bibleProvider.books.sublist(0, 39);
          final newTestament = bibleProvider.books.sublist(39);

          return ListView(
            children: [
              _buildSectionHeader('Old Testament', oldTestament.length),
              ...oldTestament.map((book) => _buildBookTile(context, book, bibleProvider)),
              _buildSectionHeader('New Testament', newTestament.length),
              ...newTestament.map((book) => _buildBookTile(context, book, bibleProvider)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title, int bookCount) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: AppTheme.primaryColor.withAlpha(25),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: AppTheme.primaryColor,
            ),
          ),
          const Spacer(),
          Text(
            '$bookCount books',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildBookTile(BuildContext context, String book, BibleProvider bibleProvider) {
    final isSelected = bibleProvider.selectedBook == book;
    final chapterCount = bibleProvider.getChapterCount(book);

    return ListTile(
      title: Text(
        book,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? AppTheme.primaryColor : null,
        ),
      ),
      subtitle: Text('$chapterCount chapters'),
      trailing: isSelected
          ? const Icon(Icons.check, color: AppTheme.primaryColor)
          : const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: () {
        bibleProvider.selectBook(book);
        Navigator.pop(context);
      },
    );
  }
}
