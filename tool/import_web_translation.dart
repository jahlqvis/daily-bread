import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:daily_bread/core/constants/app_constants.dart';
import 'package:daily_bread/core/utils/book_slug.dart';
import 'package:html/dom.dart';
import 'package:html/parser.dart' as html;

const _downloadUrl = 'https://ebible.org/Scriptures/engwebp_html.zip';
const _outputDir = 'assets/bible/web_books';

Future<void> main() async {
  final archiveBytes = await _downloadZip();
  final archive = ZipDecoder().decodeBytes(archiveBytes);

  final indexFile = archive.files.firstWhere(
    (file) => file.isFile && file.name.toLowerCase().endsWith('index.htm'),
    orElse: () => throw Exception('index.htm not found in archive'),
  );

  final bookMap = _parseBookIndex(utf8.decode(indexFile.content));
  final bookChapters = <String, Map<int, List<Map<String, dynamic>>>>{};

  final chapterFilePattern = RegExp(r'^([0-9A-Z]+?)(\d+)\.HTM$', caseSensitive: false);

  for (final file in archive.files) {
    if (!file.isFile) continue;
    final name = file.name.split('/').last;
    final match = chapterFilePattern.firstMatch(name.toUpperCase());
    if (match == null) continue;

    final prefix = match.group(1)!;
    final chapterNumber = int.parse(match.group(2)!);
    final bookName = bookMap[prefix];
    if (bookName == null) continue;

    final verses = _parseChapter(utf8.decode(file.content));
    if (verses.isEmpty) continue;

    final chapters = bookChapters.putIfAbsent(bookName, () => {});
    chapters[chapterNumber] = verses;
  }

  final outputDirectory = Directory(_outputDir);
  if (outputDirectory.existsSync()) {
    for (final entity in outputDirectory.listSync()) {
      if (entity is File) {
        entity.deleteSync();
      }
    }
  } else {
    outputDirectory.createSync(recursive: true);
  }

  for (final bookName in AppConstants.booksOfTheBible) {
    final chapters = bookChapters[bookName];
    if (chapters == null || chapters.isEmpty) {
      stderr.writeln('Missing chapters for $bookName');
      continue;
    }

    final chapterEntries = chapters.keys.toList()..sort();
    final chaptersJson = chapterEntries
        .map((chapterNumber) => {
              'chapter': chapterNumber,
              'verses': chapters[chapterNumber],
            })
        .toList();

    final file = File('${outputDirectory.path}/${bookSlug(bookName)}.json');
    file.writeAsStringSync(jsonEncode({
      'name': bookName,
      'chapters': chaptersJson,
    }));
  }
}

Future<List<int>> _downloadZip() async {
  stdout.writeln('Downloading WEB HTML archive...');
  final client = HttpClient();
  try {
    final request = await client.getUrl(Uri.parse(_downloadUrl));
    final response = await request.close();
    if (response.statusCode != 200) {
      throw Exception('Failed to download WEB archive: HTTP ${response.statusCode}');
    }
    final chunks = <int>[];
    await for (final data in response) {
      chunks.addAll(data);
    }
    stdout.writeln('Download complete (${chunks.length} bytes)');
    return chunks;
  } finally {
    client.close(force: true);
  }
}

Map<String, String> _parseBookIndex(String htmlContent) {
  final document = html.parse(htmlContent);
  final container = document.querySelector('div.bookList');
  if (container == null) {
    return {};
  }
  final anchors = container.querySelectorAll('a');
  final map = <String, String>{};
  final filePattern = RegExp(r'^([0-9A-Z]+?)(\d+)\.HTM$', caseSensitive: false);
  for (final anchor in anchors) {
    final href = anchor.attributes['href'] ?? '';
    final match = filePattern.firstMatch(href.toUpperCase());
    if (match == null) continue;
    final prefix = match.group(1)!;
    final bookName = anchor.text.trim();
    if (bookName.isEmpty) continue;
    map[prefix] = bookName;
  }
  return map;
}

List<Map<String, dynamic>> _parseChapter(String htmlContent) {
  final document = html.parse(htmlContent);
  final verseSpans = document.querySelectorAll('span.verse');
  final verses = <Map<String, dynamic>>[];
  for (final span in verseSpans) {
    final verseNumber = _parseVerseNumber(span.text);
    if (verseNumber == null) continue;
    final text = _extractVerseText(span);
    if (text.isEmpty) continue;
    verses.add({'verse': verseNumber, 'text': text});
  }
  return verses;
}

int? _parseVerseNumber(String raw) {
  final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.isEmpty) return null;
  return int.tryParse(digits);
}

String _extractVerseText(Element verseSpan) {
  final buffer = StringBuffer();
  Node? node = _nextNodeAfter(verseSpan);
  while (node != null) {
    if (node is Element) {
      if (node.classes.contains('verse')) {
        break;
      }
      if (node.classes.contains('chapterlabel')) {
        break;
      }
      if (node.querySelector('span.verse') != null) {
        break;
      }
    }
    if (node.nodeType == Node.TEXT_NODE && node.text?.trim().isEmpty == true) {
      node = _nextNodeAfter(node);
      continue;
    }
    buffer.write(_nodeToText(node));
    node = _nextNodeAfter(node);
  }
  final text = buffer.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
  return text;
}

Node? _nextNodeAfter(Node node) {
  final parent = node.parentNode;
  if (parent == null) {
    return null;
  }
  final siblings = parent.nodes;
  final index = siblings.indexOf(node);
  if (index + 1 < siblings.length) {
    return siblings[index + 1];
  }
  return _nextNodeAfter(parent);
}

String _nodeToText(Node node) {
  if (node is Text) {
    return node.data;
  }
  if (node is Element) {
    if (node.localName == 'a' && node.classes.contains('notemark')) {
      return '';
    }
    return node.text;
  }
  return '';
}
