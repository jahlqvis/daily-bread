import 'package:flutter/foundation.dart';
import '../../data/datasources/bible_data_source.dart';
import '../../data/models/bible_passage_model.dart';
import '../../core/constants/app_constants.dart';

class BibleProvider extends ChangeNotifier {
  final BibleDataSource _dataSource;
  bool _isLoading = true;
  String _selectedBook = 'Genesis';
  int _selectedChapter = 1;

  BibleProvider(this._dataSource);

  bool get isLoading => _isLoading;
  String get selectedBook => _selectedBook;
  int get selectedChapter => _selectedChapter;
  List<String> get books => AppConstants.booksOfTheBible;

  Future<void> loadBible() async {
    _isLoading = true;
    notifyListeners();
    
    await _dataSource.loadBibleData();
    
    _isLoading = false;
    notifyListeners();
  }

  void selectBook(String book) {
    _selectedBook = book;
    _selectedChapter = 1;
    notifyListeners();
  }

  void selectChapter(int chapter) {
    _selectedChapter = chapter;
    notifyListeners();
  }

  BibleChapter? getCurrentChapter() {
    return _dataSource.getChapter(_selectedBook, _selectedChapter);
  }

  int getChapterCount(String book) {
    return _dataSource.getChapterCount(book);
  }

  bool hasChapterData(String book, int chapter) {
    return _dataSource.getChapter(book, chapter) != null;
  }
}
