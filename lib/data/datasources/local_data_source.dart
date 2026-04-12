import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';

class LocalDataSource {
  static const String _userKey = 'user_data';
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
}
