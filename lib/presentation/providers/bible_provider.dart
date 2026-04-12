import 'package:flutter/foundation.dart';
import '../../data/datasources/bible_data_source.dart';
import '../../data/models/bible_passage_model.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/bible_translation.dart';

class BibleProvider extends ChangeNotifier {
  final BibleDataSource _dataSource;
  bool _isLoading = true;
  String _selectedBook = 'Genesis';
  int _selectedChapter = 1;
  BibleTranslation _selectedTranslation = BibleTranslation.kjv;

  BibleProvider(this._dataSource);

  bool get isLoading => _isLoading;
  String get selectedBook => _selectedBook;
  int get selectedChapter => _selectedChapter;
  BibleTranslation get selectedTranslation => _selectedTranslation;
  List<BibleTranslation> get availableTranslations => BibleTranslation.values;
  List<String> get books => AppConstants.booksOfTheBible;

  Future<void> loadBible() async {
    await _withLoading(() => _dataSource.preloadBook(_selectedBook, _selectedTranslation));
  }

  Future<void> selectBook(String book) async {
    if (_selectedBook == book) return;
    _selectedBook = book;
    _selectedChapter = 1;
    notifyListeners();
    await _withLoading(() => _dataSource.preloadBook(book, _selectedTranslation));
  }

  void selectChapter(int chapter) {
    if (_selectedChapter == chapter) return;
    _selectedChapter = chapter;
    notifyListeners();
  }

  Future<void> selectTranslation(BibleTranslation translation) async {
    if (_selectedTranslation == translation) return;
    _selectedTranslation = translation;
    notifyListeners();
    await _withLoading(() => _dataSource.preloadBook(_selectedBook, translation));
  }

  BibleChapter? getCurrentChapter() {
    return _dataSource.getChapter(_selectedBook, _selectedChapter, _selectedTranslation);
  }

  int getChapterCount(String book) {
    return _dataSource.getChapterCount(book);
  }

  bool hasChapterData(String book, int chapter) {
    return _dataSource.getChapter(book, chapter, _selectedTranslation) != null;
  }

  Future<void> _withLoading(Future<void> Function() task) async {
    _isLoading = true;
    notifyListeners();
    await task();
    _isLoading = false;
    notifyListeners();
  }
}
