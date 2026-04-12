class UserModel {
  final int currentStreak;
  final int longestStreak;
  final int totalXp;
  final int level;
  final List<String> badges;
  final DateTime? lastReadDate;
  final Map<String, Set<int>> readingProgress;
  final int streakFreezes;

  UserModel({
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.totalXp = 0,
    this.level = 1,
    this.badges = const [],
    this.lastReadDate,
    Map<String, Set<int>>? readingProgress,
    this.streakFreezes = 1,
  }) : readingProgress = readingProgress ?? {};

  UserModel copyWith({
    int? currentStreak,
    int? longestStreak,
    int? totalXp,
    int? level,
    List<String>? badges,
    DateTime? lastReadDate,
    Map<String, Set<int>>? readingProgress,
    int? streakFreezes,
  }) {
    return UserModel(
      currentStreak: currentStreak ?? this.currentStreak,
      longestStreak: longestStreak ?? this.longestStreak,
      totalXp: totalXp ?? this.totalXp,
      level: level ?? this.level,
      badges: badges ?? this.badges,
      lastReadDate: lastReadDate ?? this.lastReadDate,
      readingProgress: readingProgress ?? this.readingProgress,
      streakFreezes: streakFreezes ?? this.streakFreezes,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'currentStreak': currentStreak,
      'longestStreak': longestStreak,
      'totalXp': totalXp,
      'level': level,
      'badges': badges,
      'lastReadDate': lastReadDate?.toIso8601String(),
      'readingProgress': readingProgress.map(
        (key, value) => MapEntry(key, value.toList()),
      ),
      'streakFreezes': streakFreezes,
    };
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      currentStreak: json['currentStreak'] ?? 0,
      longestStreak: json['longestStreak'] ?? 0,
      totalXp: json['totalXp'] ?? 0,
      level: json['level'] ?? 1,
      badges: List<String>.from(json['badges'] ?? []),
      lastReadDate: json['lastReadDate'] != null
          ? DateTime.parse(json['lastReadDate'])
          : null,
      readingProgress: (json['readingProgress'] as Map<String, dynamic>?)?.map(
            (key, value) => MapEntry(key, Set<int>.from(List<int>.from(value))),
          ) ??
          {},
      streakFreezes: json['streakFreezes'] ?? 1,
    );
  }
}
