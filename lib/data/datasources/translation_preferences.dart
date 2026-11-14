import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/bible_translation.dart';

class TranslationPreferences {
  static const _key = 'bible_translation';
  final SharedPreferences _prefs;

  TranslationPreferences(this._prefs);

  BibleTranslation? getTranslation() {
    final id = _prefs.getString(_key);
    for (final translation in BibleTranslation.values) {
      if (translation.id == id) return translation;
    }
    return null;
  }

  Future<void> saveTranslation(BibleTranslation translation) async {
    if (!await _prefs.setString(_key, translation.id)) {
      throw StateError('Could not save Bible translation');
    }
  }
}
