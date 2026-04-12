import 'dart:convert';
import 'dart:io';

import 'package:daily_bread/core/utils/book_slug.dart';

class TranslationConfig {
  final String id;
  final String name;
  final String remoteUrl;

  const TranslationConfig({
    required this.id,
    required this.name,
    required this.remoteUrl,
  });

  String get sourcePath => 'assets/bible/$id.json';
  String get outputDir => 'assets/bible/${id}_books';
}

const _translations = [
  TranslationConfig(
    id: 'kjv',
    name: 'King James Version',
    remoteUrl:
        'https://raw.githubusercontent.com/scrollmapper/bible_databases/master/formats/json/KJV.json',
  ),
  TranslationConfig(
    id: 'asv',
    name: 'American Standard Version',
    remoteUrl:
        'https://raw.githubusercontent.com/scrollmapper/bible_databases/master/formats/json/ASV.json',
  ),
  TranslationConfig(
    id: 'web',
    name: 'World English Bible',
    remoteUrl:
        'https://raw.githubusercontent.com/scrollmapper/bible_databases/master/formats/json/WEB.json',
  ),
];

Future<void> main(List<String> args) async {
  final requested = args.isEmpty ? null : args.map((e) => e.toLowerCase()).toSet();
  for (final config in _translations) {
    if (requested != null && !requested.contains(config.id)) {
      continue;
    }
    try {
      await _generateTranslation(config);
    } catch (error) {
      stderr.writeln('Failed to generate ${config.name}: $error');
    }
  }
}

Future<void> _generateTranslation(TranslationConfig config) async {
  stdout.writeln('Processing ${config.name} (${config.id.toUpperCase()})');
  final jsonString = await _loadSource(config);
  final Map<String, dynamic> jsonMap = jsonDecode(jsonString) as Map<String, dynamic>;
  final List<dynamic> books = jsonMap['books'] as List<dynamic>? ?? [];

  final outputDirectory = Directory(config.outputDir);
  if (outputDirectory.existsSync()) {
    for (final entity in outputDirectory.listSync()) {
      if (entity is File) {
        entity.deleteSync();
      }
    }
  } else {
    outputDirectory.createSync(recursive: true);
  }

  for (final dynamic bookEntry in books) {
    if (bookEntry is! Map<String, dynamic>) continue;
    final String? name = bookEntry['name'] as String?;
    if (name == null) continue;

    final slug = bookSlug(name);
    final file = File('${config.outputDir}/$slug.json');
    final content = jsonEncode({
      'name': name,
      'chapters': bookEntry['chapters'],
    });
    await file.writeAsString(content);
  }

  stdout.writeln(' -> Wrote ${books.length} books to ${config.outputDir}\n');
}

Future<String> _loadSource(TranslationConfig config) async {
  final sourceFile = File(config.sourcePath);
  if (sourceFile.existsSync()) {
    stdout.writeln('Using local source file: ${config.sourcePath}');
    return sourceFile.readAsString();
  }

  stdout.writeln('Downloading ${config.remoteUrl}');
  final client = HttpClient();
  try {
    final request = await client.getUrl(Uri.parse(config.remoteUrl));
    final response = await request.close();
    if (response.statusCode != 200) {
      throw Exception('Failed to download ${config.remoteUrl}: ${response.statusCode}');
    }
    return await utf8.decoder.bind(response).join();
  } finally {
    client.close(force: true);
  }
}
