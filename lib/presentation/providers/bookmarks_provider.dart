import 'package:flutter/foundation.dart';

import '../../data/datasources/local_data_source.dart';
import '../../data/models/verse_bookmark_model.dart';

class BookmarksProvider extends ChangeNotifier {
  final LocalDataSource _localDataSource;
  bool _isLoading = true;
  List<VerseBookmark> _bookmarks = const [];

  BookmarksProvider(this._localDataSource);

  bool get isLoading => _isLoading;
  List<VerseBookmark> get bookmarks => _bookmarks;

  Future<void> loadBookmarks() async {
    _isLoading = true;
    notifyListeners();

    _bookmarks = _sortByNewest(_localDataSource.getBookmarks());

    _isLoading = false;
    notifyListeners();
  }

  bool isBookmarked(String book, int chapter, int verse, String translationId) {
    final id = '$translationId|$book|$chapter|$verse';
    return _bookmarks.any((bookmark) => bookmark.id == id);
  }

  VerseBookmark? bookmarkFor(
    String book,
    int chapter,
    int verse,
    String translationId,
  ) {
    final id = '$translationId|$book|$chapter|$verse';
    for (final bookmark in _bookmarks) {
      if (bookmark.id == id) {
        return bookmark;
      }
    }
    return null;
  }

  Future<void> addBookmark(VerseBookmark bookmark) async {
    if (_bookmarks.any((existing) => existing.id == bookmark.id)) {
      return;
    }

    final updated = [..._bookmarks, bookmark];
    await _saveAndNotify(updated);
  }

  Future<void> removeBookmark(
    String book,
    int chapter,
    int verse,
    String translationId,
  ) async {
    final id = '$translationId|$book|$chapter|$verse';
    final updated = _bookmarks.where((bookmark) => bookmark.id != id).toList();
    if (updated.length == _bookmarks.length) {
      return;
    }

    await _saveAndNotify(updated);
  }

  Future<void> toggleBookmark({
    required String book,
    required int chapter,
    required int verse,
    required String translationId,
    String? note,
    DateTime? createdAt,
  }) async {
    if (isBookmarked(book, chapter, verse, translationId)) {
      await removeBookmark(book, chapter, verse, translationId);
      return;
    }

    await addBookmark(
      VerseBookmark(
        book: book,
        chapter: chapter,
        verse: verse,
        translationId: translationId,
        note: note,
        createdAt: createdAt ?? DateTime.now(),
      ),
    );
  }

  Future<void> updateNote(
    String book,
    int chapter,
    int verse,
    String translationId,
    String? note,
  ) async {
    final id = '$translationId|$book|$chapter|$verse';
    final index = _bookmarks.indexWhere((bookmark) => bookmark.id == id);
    if (index < 0) {
      return;
    }

    final updated = [..._bookmarks];
    final trimmed = note?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      updated[index] = updated[index].copyWith(clearNote: true);
    } else {
      updated[index] = updated[index].copyWith(note: trimmed);
    }

    await _saveAndNotify(updated);
  }

  Future<void> clearBookmarks() async {
    await _localDataSource.clearBookmarks();
    _bookmarks = const [];
    notifyListeners();
  }

  Future<void> _saveAndNotify(List<VerseBookmark> updated) async {
    _bookmarks = _sortByNewest(updated);
    await _localDataSource.saveBookmarks(_bookmarks);
    notifyListeners();
  }

  List<VerseBookmark> _sortByNewest(List<VerseBookmark> items) {
    final sorted = [...items]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sorted;
  }
}
