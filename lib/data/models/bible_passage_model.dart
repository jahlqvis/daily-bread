class BiblePassage {
  final String book;
  final int chapter;
  final int verse;
  final String text;

  BiblePassage({
    required this.book,
    required this.chapter,
    required this.verse,
    required this.text,
  });

  String get reference => '$book $chapter:$verse';
}

class BibleChapter {
  final String book;
  final int chapter;
  final List<BiblePassage> verses;

  BibleChapter({
    required this.book,
    required this.chapter,
    required this.verses,
  });

  String get reference => '$book $chapter';
}
