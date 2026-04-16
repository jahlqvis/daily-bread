import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../models/verse_bookmark_model.dart';

class LocalDataSource {
  static const String _userKey = 'user_data';
  static const String _activePlanIdKey = 'active_plan_id';
  static const String _activePlanStartedAtKey = 'active_plan_started_at';
  static const String _completedPlanRewardsKey = 'completed_plan_reward_ids';
  static const String _bookmarksKey = 'verse_bookmarks';
  final SharedPreferences _prefs;

  LocalDataSource(this._prefs);

  Future<UserModel> getUser() async {
    final jsonString = _prefs.getString(_userKey);
    if (jsonString == null) {
      return UserModel();
    }
    return UserModel.fromJson(json.decode(jsonString));
  }

  Future<void> saveUser(UserModel user) async {
    await _prefs.setString(_userKey, json.encode(user.toJson()));
  }

  Future<void> clearUser() async {
    await _prefs.remove(_userKey);
  }

  String? getActivePlanId() {
    return _prefs.getString(_activePlanIdKey);
  }

  Future<void> saveActivePlanId(String planId) async {
    await _prefs.setString(_activePlanIdKey, planId);
  }

  Future<void> clearActivePlanId() async {
    await _prefs.remove(_activePlanIdKey);
  }

  DateTime? getActivePlanStartedAt() {
    final iso = _prefs.getString(_activePlanStartedAtKey);
    if (iso == null || iso.isEmpty) {
      return null;
    }
    return DateTime.tryParse(iso);
  }

  Future<void> saveActivePlanStartedAt(DateTime value) async {
    await _prefs.setString(_activePlanStartedAtKey, value.toIso8601String());
  }

  Future<void> clearActivePlanStartedAt() async {
    await _prefs.remove(_activePlanStartedAtKey);
  }

  Set<String> getCompletedPlanRewardIds() {
    final ids = _prefs.getStringList(_completedPlanRewardsKey);
    if (ids == null) {
      return <String>{};
    }
    return ids.toSet();
  }

  Future<void> saveCompletedPlanRewardIds(Set<String> planIds) async {
    await _prefs.setStringList(
      _completedPlanRewardsKey,
      planIds.toList(growable: false),
    );
  }

  List<VerseBookmark> getBookmarks() {
    final jsonString = _prefs.getString(_bookmarksKey);
    if (jsonString == null || jsonString.isEmpty) {
      return const [];
    }

    final decoded = jsonDecode(jsonString);
    if (decoded is! List) {
      return const [];
    }

    return decoded
        .whereType<Map<String, dynamic>>()
        .map(VerseBookmark.fromJson)
        .toList(growable: false);
  }

  Future<void> saveBookmarks(List<VerseBookmark> bookmarks) async {
    final payload = bookmarks.map((bookmark) => bookmark.toJson()).toList();
    await _prefs.setString(_bookmarksKey, jsonEncode(payload));
  }

  Future<void> clearBookmarks() async {
    await _prefs.remove(_bookmarksKey);
  }
}
