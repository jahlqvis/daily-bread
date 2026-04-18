import '../../data/datasources/local_data_source.dart';

abstract class DailyReminderService {
  bool get isSupported;
  bool get isEnabled;
  String get reminderTime;

  Future<void> setEnabled(bool enabled);
  Future<void> setReminderTime(String hhmm);
}

class LocalReminderService implements DailyReminderService {
  final LocalDataSource _localDataSource;

  LocalReminderService(this._localDataSource);

  @override
  bool get isSupported => false;

  @override
  bool get isEnabled => _localDataSource.isDailyReminderEnabled();

  @override
  String get reminderTime => _localDataSource.getDailyReminderTime();

  @override
  Future<void> setEnabled(bool enabled) async {
    await _localDataSource.saveDailyReminderEnabled(enabled);
  }

  @override
  Future<void> setReminderTime(String hhmm) async {
    await _localDataSource.saveDailyReminderTime(hhmm);
  }
}
