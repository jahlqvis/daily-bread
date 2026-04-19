import 'package:daily_bread/data/models/verse_bookmark_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('toJson and fromJson preserve bookmark fields', () {
    final bookmark = VerseBookmark(
      book: 'John',
      chapter: 3,
      verse: 16,
      translationId: 'web',
      note: 'Remember this promise.',
      createdAt: DateTime(2026, 4, 16, 10, 30),
    );

    final decoded = VerseBookmark.fromJson(bookmark.toJson());

    expect(decoded.book, bookmark.book);
    expect(decoded.chapter, bookmark.chapter);
    expect(decoded.verse, bookmark.verse);
    expect(decoded.translationId, bookmark.translationId);
    expect(decoded.note, bookmark.note);
    expect(decoded.createdAt, bookmark.createdAt);
    expect(decoded.updatedAt, bookmark.createdAt);
    expect(decoded.id, bookmark.id);
    expect(decoded.reference, 'John 3:16');
  });

  test('copyWith updates note and can clear note', () {
    final bookmark = VerseBookmark(
      book: 'Psalms',
      chapter: 23,
      verse: 1,
      translationId: 'kjv',
      note: 'Comfort chapter',
      createdAt: DateTime(2026, 4, 16),
    );

    final updated = bookmark.copyWith(note: 'The Lord is my shepherd');
    final cleared = updated.copyWith(clearNote: true);

    expect(updated.note, 'The Lord is my shepherd');
    expect(cleared.note, isNull);
  });

  test('fromJson preserves updatedAt when provided', () {
    final bookmark = VerseBookmark.fromJson({
      'book': 'Romans',
      'chapter': 8,
      'verse': 1,
      'translationId': 'web',
      'note': null,
      'createdAt': '2026-04-20T08:00:00.000',
      'updatedAt': '2026-04-20T10:30:00.000',
    });

    expect(bookmark.updatedAt, DateTime.parse('2026-04-20T10:30:00.000'));
  });
}
