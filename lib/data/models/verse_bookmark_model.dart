class VerseBookmark {
  final String book;
  final int chapter;
  final int verse;
  final String translationId;
  final String? note;
  final DateTime createdAt;
  final DateTime updatedAt;

  VerseBookmark({
    required this.book,
    required this.chapter,
    required this.verse,
    required this.translationId,
    this.note,
    required this.createdAt,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? createdAt;

  String get id => '$translationId|$book|$chapter|$verse';

  String get reference => '$book $chapter:$verse';

  VerseBookmark copyWith({
    String? book,
    int? chapter,
    int? verse,
    String? translationId,
    String? note,
    bool clearNote = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return VerseBookmark(
      book: book ?? this.book,
      chapter: chapter ?? this.chapter,
      verse: verse ?? this.verse,
      translationId: translationId ?? this.translationId,
      note: clearNote ? null : (note ?? this.note),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'book': book,
      'chapter': chapter,
      'verse': verse,
      'translationId': translationId,
      'note': note,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory VerseBookmark.fromJson(Map<String, dynamic> json) {
    return VerseBookmark(
      book: json['book'] as String? ?? '',
      chapter: json['chapter'] as int? ?? 0,
      verse: json['verse'] as int? ?? 0,
      translationId: json['translationId'] as String? ?? '',
      note: json['note'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? ''),
    );
  }
}
