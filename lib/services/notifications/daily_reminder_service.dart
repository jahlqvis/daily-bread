import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../../data/datasources/local_data_source.dart';

abstract class DailyReminderService {
  bool get isSupported;
  bool get isEnabled;
  String get reminderTime;

  Future<void> initialize();
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
  Future<void> initialize() async {}

  @override
  Future<void> setEnabled(bool enabled) async {
    await _localDataSource.saveDailyReminderEnabled(enabled);
  }

  @override
  Future<void> setReminderTime(String hhmm) async {
    await _localDataSource.saveDailyReminderTime(hhmm);
  }
}

class LocalNotificationReminderService implements DailyReminderService {
  static const int _notificationId = 1201;
  static const String _channelId = 'daily_reading_reminders';
  static const String _channelName = 'Daily reading reminders';

  final LocalDataSource _localDataSource;
  final FlutterLocalNotificationsPlugin _notificationsPlugin;

  bool _initialized = false;

  LocalNotificationReminderService(
    this._localDataSource,
    this._notificationsPlugin,
  );

  @override
  bool get isSupported {
    if (kIsWeb) {
      return false;
    }

    return defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.android;
  }

  @override
  bool get isEnabled => _localDataSource.isDailyReminderEnabled();

  @override
  String get reminderTime => _localDataSource.getDailyReminderTime();

  @override
  Future<void> initialize() async {
    if (!isSupported || _initialized) {
      return;
    }

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwin = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _notificationsPlugin.initialize(
      const InitializationSettings(android: android, iOS: darwin),
    );

    tz.initializeTimeZones();
    try {
      final timezoneName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timezoneName));
    } catch (_) {
      tz.setLocalLocation(tz.local);
    }

    _initialized = true;

    if (isEnabled) {
      await _scheduleDailyReminder(reminderTime);
    }
  }

  @override
  Future<void> setEnabled(bool enabled) async {
    if (!isSupported) {
      await _localDataSource.saveDailyReminderEnabled(false);
      return;
    }

    await initialize();

    if (!enabled) {
      await _notificationsPlugin.cancel(_notificationId);
      await _localDataSource.saveDailyReminderEnabled(false);
      return;
    }

    final granted = await _requestPermissions();
    if (!granted) {
      await _notificationsPlugin.cancel(_notificationId);
      await _localDataSource.saveDailyReminderEnabled(false);
      throw StateError('Notifications permission denied');
    }

    await _scheduleDailyReminder(reminderTime);
    await _localDataSource.saveDailyReminderEnabled(true);
  }

  @override
  Future<void> setReminderTime(String hhmm) async {
    await _localDataSource.saveDailyReminderTime(hhmm);

    if (!isSupported || !isEnabled) {
      return;
    }

    await initialize();
    await _scheduleDailyReminder(hhmm);
  }

  Future<bool> _requestPermissions() async {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final ios = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();

      return await ios?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      final android = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      return await android?.requestNotificationsPermission() ?? true;
    }

    return false;
  }

  Future<void> _scheduleDailyReminder(String hhmm) async {
    final time = _parseTime(hhmm);
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      time.$1,
      time.$2,
    );

    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: 'Reminders to keep your DailyBread streak alive',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
    );

    await _notificationsPlugin.zonedSchedule(
      _notificationId,
      'Time for DailyBread',
      'Read today\'s chapter to keep your streak alive.',
      scheduled,
      details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: 'daily_reminder',
    );
  }

  (int, int) _parseTime(String hhmm) {
    final parts = hhmm.split(':');
    final hour = parts.isNotEmpty ? int.tryParse(parts.first) ?? 8 : 8;
    final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    return (hour.clamp(0, 23), minute.clamp(0, 59));
  }
}
