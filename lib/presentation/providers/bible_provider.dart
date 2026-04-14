import 'package:flutter/foundation.dart';
import '../../data/datasources/bible_data_source.dart';
import '../../data/models/bible_passage_model.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/bible_translation.dart';

class BibleProvider extends ChangeNotifier {
  final BibleDataSource _dataSource;
  bool _isLoading = true;
  String? _loadError;
  bool _isSearching = false;
  String? _searchError;
  String _lastSearchQuery = '';
  List<BiblePassage> _searchResults = const [];
  String _selectedBook = 'Genesis';
  int _selectedChapter = 1;
  BibleTranslation _selectedTranslation = BibleTranslation.kjv;

  BibleProvider(this._dataSource);

  bool get isLoading => _isLoading;
  String? get loadError => _loadError;
  bool get isSearching => _isSearching;
  String? get searchError => _searchError;
  String get lastSearchQuery => _lastSearchQuery;
  List<BiblePassage> get searchResults => _searchResults;
  String get selectedBook => _selectedBook;
  int get selectedChapter => _selectedChapter;
  BibleTranslation get selectedTranslation => _selectedTranslation;
  List<BibleTranslation> get availableTranslations => BibleTranslation.values;
  List<String> get books => AppConstants.booksOfTheBible;

  Future<void> loadBible() async {
    await _withLoading(
      () => _dataSource.preloadBook(_selectedBook, _selectedTranslation),
    );
  }

  Future<void> selectBook(String book) async {
    if (_selectedBook == book) return;
    _selectedBook = book;
    _selectedChapter = 1;
    notifyListeners();
    await _withLoading(
      () => _dataSource.preloadBook(book, _selectedTranslation),
    );
  }

  void selectChapter(int chapter) {
    if (_selectedChapter == chapter) return;
    _selectedChapter = chapter;
    notifyListeners();
  }

  Future<void> selectTranslation(BibleTranslation translation) async {
    if (_selectedTranslation == translation) return;
    _selectedTranslation = translation;
    clearSearchResults(notify: false);
    notifyListeners();
    await _withLoading(
      () => _dataSource.preloadBook(_selectedBook, translation),
    );
  }

  BibleChapter? getCurrentChapter() {
    return _dataSource.getChapter(
      _selectedBook,
      _selectedChapter,
      _selectedTranslation,
    );
  }

  int getChapterCount(String book) {
    return _dataSource.getChapterCount(book);
  }

  bool hasChapterData(String book, int chapter) {
    return _dataSource.getChapter(book, chapter, _selectedTranslation) != null;
  }

  Future<void> retryCurrentSelection() async {
    await _withLoading(
      () => _dataSource.preloadBook(_selectedBook, _selectedTranslation),
    );
  }

  Future<void> searchVerses(String query) async {
    final trimmed = query.trim();
    _lastSearchQuery = trimmed;

    if (trimmed.isEmpty) {
      clearSearchResults();
      return;
    }

    _isSearching = true;
    _searchError = null;
    notifyListeners();

    try {
      _searchResults = await _dataSource.searchVerses(
        trimmed,
        _selectedTranslation,
      );
      _searchError = null;
    } catch (_) {
      _searchResults = const [];
      _searchError = 'Could not search verses right now. Please try again.';
    } finally {
      _isSearching = false;
      notifyListeners();
    }
  }

  void clearSearchResults({bool notify = true}) {
    _isSearching = false;
    _searchError = null;
    _lastSearchQuery = '';
    _searchResults = const [];
    if (notify) {
      notifyListeners();
    }
  }

  Future<void> _withLoading(Future<void> Function() task) async {
    _isLoading = true;
    _loadError = null;
    notifyListeners();
    try {
      await task();
      _loadError = null;
    } catch (_) {
      _loadError = 'Could not load Bible content right now. Please try again.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
