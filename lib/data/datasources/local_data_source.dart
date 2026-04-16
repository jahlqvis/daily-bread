import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';

class LocalDataSource {
  static const String _userKey = 'user_data';
  static const String _activePlanIdKey = 'active_plan_id';
  static const String _completedPlanRewardsKey = 'completed_plan_reward_ids';
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
}
