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
  bool _hydratedQuery = false;

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _runSearch(BuildContext context) async {
    await context.read<BibleProvider>().searchVerses(_queryController.text);
  }

  void _hydrateQuery(BibleProvider bibleProvider) {
    if (_hydratedQuery) {
      return;
    }

    _queryController.text = bibleProvider.lastSearchQuery;
    _hydratedQuery = true;
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
          _hydrateQuery(bibleProvider);

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  controller: _queryController,
                  textInputAction: TextInputAction.search,
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) => _runSearch(context),
                  decoration: InputDecoration(
                    hintText: 'Search verses (e.g. love one another)',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _queryController.text.trim().isEmpty
                            ? Icons.arrow_forward
                            : Icons.clear,
                      ),
                      onPressed: () {
                        if (_queryController.text.trim().isEmpty) {
                          _runSearch(context);
                        } else {
                          _queryController.clear();
                          context.read<BibleProvider>().clearSearchResults();
                          setState(() {});
                        }
                      },
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
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: AnimatedOpacity(
                  opacity: bibleProvider.isSearching ? 1 : 0,
                  duration: const Duration(milliseconds: 150),
                  child: const LinearProgressIndicator(),
                ),
              ),
              const SizedBox(height: 8),
              if (bibleProvider.lastSearchQuery.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '${bibleProvider.searchResults.length} result(s)',
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                  ),
                ),
              if (bibleProvider.lastSearchQuery.isNotEmpty)
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

    if (bibleProvider.isSearching && bibleProvider.searchResults.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text('Searching verses...'),
          ],
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
          leading: CircleAvatar(
            radius: 14,
            child: Text('${index + 1}', style: const TextStyle(fontSize: 11)),
          ),
          title: Text(result.reference),
          subtitle: RichText(
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            text: _highlightedText(
              result.text,
              bibleProvider.lastSearchQuery,
              Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          trailing: const Icon(Icons.arrow_forward_ios, size: 14),
          onTap: () => _openResult(context, result),
        );
      },
    );
  }

  TextSpan _highlightedText(String text, String query, TextStyle? baseStyle) {
    final terms = query
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((term) => term.isNotEmpty)
        .toSet();

    if (terms.isEmpty) {
      return TextSpan(text: text, style: baseStyle);
    }

    final escapedTerms = terms.map(RegExp.escape).join('|');
    final expression = RegExp('($escapedTerms)', caseSensitive: false);
    final matches = expression.allMatches(text).toList();

    if (matches.isEmpty) {
      return TextSpan(text: text, style: baseStyle);
    }

    final children = <InlineSpan>[];
    var cursor = 0;
    for (final match in matches) {
      if (match.start > cursor) {
        children.add(TextSpan(text: text.substring(cursor, match.start)));
      }
      children.add(
        TextSpan(
          text: text.substring(match.start, match.end),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      );
      cursor = match.end;
    }

    if (cursor < text.length) {
      children.add(TextSpan(text: text.substring(cursor)));
    }

    return TextSpan(style: baseStyle, children: children);
  }

  Future<void> _openResult(BuildContext context, BiblePassage result) async {
    final navigator = Navigator.of(context);
    final provider = context.read<BibleProvider>();
    await provider.selectBook(result.book);
    provider.selectChapter(result.chapter);
    provider.setHighlightedVerse(result.verse);

    if (!mounted) {
      return;
    }

    navigator.push(MaterialPageRoute(builder: (_) => const ReadingScreen()));
  }
}
