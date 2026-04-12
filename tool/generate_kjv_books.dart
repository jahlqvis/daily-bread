import 'dart:convert';
import 'dart:io';

import 'package:daily_bread/core/utils/book_slug.dart';

const _sourcePath = 'assets/bible/kjv.json';
const _outputDir = 'assets/bible/kjv_books';
const _remoteUrl = 'https://raw.githubusercontent.com/scrollmapper/bible_databases/master/formats/json/KJV.json';

Future<void> main() async {
  final jsonString = await _loadSource();
  final Map<String, dynamic> data = jsonDecode(jsonString) as Map<String, dynamic>;
  final List<dynamic> books = data['books'] as List<dynamic>? ?? [];

  final outputDirectory = Directory(_outputDir);
  if (!outputDirectory.existsSync()) {
    outputDirectory.createSync(recursive: true);
  }

  for (final dynamic bookEntry in books) {
    if (bookEntry is! Map<String, dynamic>) continue;
    final String? name = bookEntry['name'] as String?;
    if (name == null) continue;

    final slug = bookSlug(name);
    final file = File('$_outputDir/$slug.json');
    final content = jsonEncode({
      'name': name,
      'chapters': bookEntry['chapters'],
    });
    await file.writeAsString(content);
  }

  stdout.writeln('Generated ${books.length} book files under $_outputDir');
}

Future<String> _loadSource() async {
  final sourceFile = File(_sourcePath);
  if (sourceFile.existsSync()) {
    return sourceFile.readAsString();
  }

  stdout.writeln('Local KJV source not found. Downloading from $_remoteUrl');
  final client = HttpClient();
  final request = await client.getUrl(Uri.parse(_remoteUrl));
  final response = await request.close();
  if (response.statusCode != 200) {
    throw Exception('Failed to download KJV source: HTTP ${response.statusCode}');
  }
  return await utf8.decoder.bind(response).join();
}
