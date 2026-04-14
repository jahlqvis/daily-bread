class ReadingReference {
  final String book;
  final int chapter;

  const ReadingReference({required this.book, required this.chapter});

  String get id => '$book:$chapter';

  String get label => '$book $chapter';
}

class ReadingPlan {
  final String id;
  final String title;
  final String description;
  final List<ReadingReference> chapters;

  const ReadingPlan({
    required this.id,
    required this.title,
    required this.description,
    required this.chapters,
  });

  int get totalDays => chapters.length;
}
