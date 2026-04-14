import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/bible_translation.dart';
import '../../data/models/bible_passage_model.dart';
import '../providers/bible_provider.dart';
import '../widgets/translation_selector.dart';
import 'reading_screen.dart';

class VerseSearchScreen extends StatefulWidget {
  const VerseSearchScreen({super.key});

  @override
  State<VerseSearchScreen> createState() => _VerseSearchScreenState();
}

class _VerseSearchScreenState extends State<VerseSearchScreen> {
  final TextEditingController _queryController = TextEditingController();

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _runSearch(BuildContext context) async {
    await context.read<BibleProvider>().searchVerses(_queryController.text);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verse Search'),
        actions: const [TranslationSelector()],
      ),
      body: Consumer<BibleProvider>(
        builder: (context, bibleProvider, _) {
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  controller: _queryController,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _runSearch(context),
                  decoration: InputDecoration(
                    hintText: 'Search verses (e.g. love one another)',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.arrow_forward),
                      onPressed: () => _runSearch(context),
                    ),
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Searching ${bibleProvider.selectedTranslation.label}',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              if (bibleProvider.isSearching)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: LinearProgressIndicator(),
                ),
              const SizedBox(height: 8),
              Expanded(child: _buildSearchBody(context, bibleProvider)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSearchBody(BuildContext context, BibleProvider bibleProvider) {
    if (bibleProvider.searchError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 56),
              const SizedBox(height: 12),
              Text(bibleProvider.searchError!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => _runSearch(context),
                child: const Text('Retry Search'),
              ),
            ],
          ),
        ),
      );
    }

    if (bibleProvider.lastSearchQuery.isEmpty) {
      return const Center(
        child: Text('Type a phrase above to search this translation.'),
      );
    }

    final results = bibleProvider.searchResults;
    if (results.isEmpty) {
      return Center(
        child: Text('No verses found for "${bibleProvider.lastSearchQuery}".'),
      );
    }

    return ListView.separated(
      itemCount: results.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final result = results[index];
        return ListTile(
          title: Text(result.reference),
          subtitle: Text(
            result.text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          onTap: () => _openResult(context, result),
        );
      },
    );
  }

  Future<void> _openResult(BuildContext context, BiblePassage result) async {
    final navigator = Navigator.of(context);
    final provider = context.read<BibleProvider>();
    await provider.selectBook(result.book);
    provider.selectChapter(result.chapter);

    if (!mounted) {
      return;
    }

    navigator.pushReplacement(
      MaterialPageRoute(builder: (_) => const ReadingScreen()),
    );
  }
}
