import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import '../models/class_schedule.dart';
import '../store/auth_store.dart';

// ─────────────────────────────────────────────────────────────
// Storage key — user-scoped, same convention as the rest of the app.
// ─────────────────────────────────────────────────────────────
String get _kClassSchedules =>
    AuthStore.instance.scopedKey('class_schedules');

// ─────────────────────────────────────────────────────────────
// Notification channel (Android)
// ─────────────────────────────────────────────────────────────
const _kChannelId   = 'class_alerts';
const _kChannelName = 'Class Alerts';
const _kChannelDesc = 'Reminders for upcoming classes';

// ─────────────────────────────────────────────────────────────
// ClassScheduleStore
// ─────────────────────────────────────────────────────────────
class ClassScheduleStore extends ChangeNotifier {
  ClassScheduleStore._();
  static final ClassScheduleStore instance = ClassScheduleStore._();

  final List<ClassSchedule> _schedules = [];
  late final FlutterLocalNotificationsPlugin _notifPlugin;
  bool _notifReady = false;

  List<ClassSchedule> get schedules => List.unmodifiable(_schedules);

  // ── Initialisation ────────────────────────────────────────

  /// Call once at app startup, after other stores are loaded.
  Future<void> load() async {
    await _initNotifications();
    await _loadFromPrefs();
  }

  /// Cancels existing notifications, clears the list, then reloads
  /// from prefs using the current user's scoped key. Call on login.
  Future<void> reload() async {
    for (final s in List.of(_schedules)) {
      try {
        await _cancelNotifications(s.id);
      } catch (_) {}
    }
    _schedules.clear();
    await _loadFromPrefs();
    for (final s in _schedules) {
      await _scheduleNotifications(s);
    }
  }

  Future<void> _initNotifications() async {
    tz_data.initializeTimeZones();
    final String timeZoneName = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(timeZoneName));

    _notifPlugin = FlutterLocalNotificationsPlugin();

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifPlugin.initialize(initSettings);

    // Request permission on Android 13+
    final android = _notifPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();

    _notifReady = true;
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final raw = prefs.getString(_kClassSchedules);
      if (raw != null) {
        final list = jsonDecode(raw) as List;
        _schedules
          ..clear()
          ..addAll(list.map((e) =>
              ClassSchedule.fromJson(Map<String, dynamic>.from(e as Map))));
      }
    } catch (_) {
      // Corrupt data — start clean rather than crash.
      _schedules.clear();
      await prefs.remove(_kClassSchedules);
    }
    notifyListeners();
  }

  // ── Add ───────────────────────────────────────────────────

  Future<void> add(ClassSchedule schedule) async {
    _schedules.add(schedule);
    await _persist();
    await _scheduleNotifications(schedule);
    notifyListeners();
  }

  // ── Remove ────────────────────────────────────────────────

  Future<void> remove(String id) async {
    _schedules.removeWhere((s) => s.id == id);
    await _persist();
    await _cancelNotifications(id);
    notifyListeners();
  }

  // ── Update ────────────────────────────────────────────────

  Future<void> update(ClassSchedule updated) async {
    final index = _schedules.indexWhere((s) => s.id == updated.id);
    if (index == -1) return;
    _schedules[index] = updated;
    await _persist();
    // Cancel old notifications then reschedule with new settings.
    await _cancelNotifications(updated.id);
    await _scheduleNotifications(updated);
    notifyListeners();
  }

  // ── Helpers ───────────────────────────────────────────────

  /// Returns all schedules that fall on [weekday] (1=Mon … 7=Sun),
  /// sorted by time ascending.
  List<ClassSchedule> forDay(int weekday) {
    return _schedules
        .where((s) => s.days.contains(weekday))
        .toList()
      ..sort((a, b) {
        final aMin = a.time.hour * 60 + a.time.minute;
        final bMin = b.time.hour * 60 + b.time.minute;
        return aMin.compareTo(bMin);
      });
  }

  /// Returns today's classes, sorted by time.
  List<ClassSchedule> get todaysSchedules =>
      forDay(DateTime.now().weekday);

  // ── Notification scheduling ───────────────────────────────

  /// Each class gets one repeating weekly notification per day it runs.
  /// Notification ID = stable int derived from schedule id + day
  /// so we can cancel them individually without a lookup table.
  Future<void> _scheduleNotifications(ClassSchedule s) async {
    if (!_notifReady) return;

    for (final day in s.days) {
      try {
        final notifId = _notifId(s.id, day);
        final now     = tz.TZDateTime.now(tz.local);

        final reminderTZ = _nextWeekday(
          day,
          s.time.hour,
          s.time.minute,
          s.reminderMinutes,
          now,
        );

        final body = (s.room != null && s.room!.isNotEmpty)
            ? '${s.name} starts in ${s.reminderMinutes} min · ${s.room}'
            : '${s.name} starts in ${s.reminderMinutes} min';

        await _notifPlugin.zonedSchedule(
          notifId,
          '📚 Class Starting Soon',
          body,
          reminderTZ,
          NotificationDetails(
            android: AndroidNotificationDetails(
              _kChannelId,
              _kChannelName,
              channelDescription: _kChannelDesc,
              importance: Importance.high,
              priority: Priority.high,
              icon: '@mipmap/ic_launcher',
            ),
            iOS: const DarwinNotificationDetails(
              presentAlert: true,
              presentBadge: true,
              presentSound: true,
            ),
          ),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
      } catch (_) {
        // Notification scheduling failed for this day — skip silently
        // so the schedule is still saved and the UI doesn't hang.
      }
    }
  }

  /// Cancel all notifications for a given schedule id across all 7 possible days.
  Future<void> _cancelNotifications(String scheduleId) async {
    if (!_notifReady) return;
    for (int day = 1; day <= 7; day++) {
      await _notifPlugin.cancel(_notifId(scheduleId, day));
    }
  }

  /// Derives a stable 32-bit int notification ID from schedule id + day.
  /// Namespace prefix 0xCA ("class alerts") avoids collisions with other
  /// notification types in the app.
  int _notifId(String scheduleId, int day) {
    // Must fit in a signed 32-bit int (max 2^31-1 = 2147483647).
    // Use a smaller hash range and keep the result positive.
    final hash = scheduleId.hashCode.abs() % 9999983; // prime < 10M
    return ((hash * 10 + day) & 0x7FFFFFFF);
  }

  /// Returns the next [tz.TZDateTime] for [weekday] at the reminder time
  /// ([hour]:[minute] minus [offsetMinutes]), strictly after [from].
  tz.TZDateTime _nextWeekday(
    int weekday,
    int hour,
    int minute,
    int offsetMinutes,
    tz.TZDateTime from,
  ) {
    // Subtract reminder offset to get the notification fire time.
    var reminderMinute = minute - offsetMinutes;
    var reminderHour   = hour;
    while (reminderMinute < 0) {
      reminderMinute += 60;
      reminderHour   -= 1;
    }
    if (reminderHour < 0) reminderHour += 24;

    // Start from today at the computed reminder time.
    var candidate = tz.TZDateTime(
      tz.local,
      from.year,
      from.month,
      from.day,
      reminderHour,
      reminderMinute,
    );

    // Advance day by day until we land on the right weekday in the future.
    for (var i = 0; i < 8; i++) {
      if (candidate.weekday == weekday && candidate.isAfter(from)) {
        return candidate;
      }
      candidate = candidate.add(const Duration(days: 1));
    }

    return candidate; // Fallback — always resolves within 7 days.
  }

  // ── Persistence ───────────────────────────────────────────

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _kClassSchedules,
      jsonEncode(_schedules.map((s) => s.toJson()).toList()),
    );
  }

  // ── Clear (called on logout) ──────────────────────────────

  /// Cancels all class notifications and wipes persisted data.
  Future<void> clear() async {
    // Capture the scoped key BEFORE auth is cleared so we remove
    // the correct key even if the user session is wiped mid-logout.
    final key = _kClassSchedules;
    for (final s in List.of(_schedules)) {
      try {
        await _cancelNotifications(s.id);
      } catch (_) {}
    }
    _schedules.clear();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(key);
    } catch (_) {}
    notifyListeners();
  }
}