import 'package:flutter/material.dart';

class ClassSchedule {
  final String id;
  final String name;
  final List<int> days; // 1=Mon, 2=Tue, 3=Wed, 4=Thu, 5=Fri, 6=Sat, 7=Sun
  final TimeOfDay time;
  final int reminderMinutes; // how many minutes before class to notify
  final String? room;

  const ClassSchedule({
    required this.id,
    required this.name,
    required this.days,
    required this.time,
    required this.reminderMinutes,
    this.room,
  });

  /// Display label for a day integer (1=Mon … 7=Sun).
  static String dayLabel(int day) {
    const labels = {
      1: 'Mon', 2: 'Tue', 3: 'Wed',
      4: 'Thu', 5: 'Fri', 6: 'Sat', 7: 'Sun',
    };
    return labels[day] ?? '';
  }

  /// Full name of a day integer.
  static String dayName(int day) {
    const names = {
      1: 'Monday',   2: 'Tuesday',  3: 'Wednesday',
      4: 'Thursday', 5: 'Friday',   6: 'Saturday', 7: 'Sunday',
    };
    return names[day] ?? '';
  }

  /// Sorted days as short labels, e.g. "Mon, Wed, Fri".
  String get daysLabel {
    final sorted = List<int>.from(days)..sort();
    return sorted.map(ClassSchedule.dayLabel).join(', ');
  }

  /// Time formatted as "9:00 AM".
  String get timeLabel {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  ClassSchedule copyWith({
    String? id,
    String? name,
    List<int>? days,
    TimeOfDay? time,
    int? reminderMinutes,
    String? room,
  }) {
    return ClassSchedule(
      id:              id              ?? this.id,
      name:            name            ?? this.name,
      days:            days            ?? this.days,
      time:            time            ?? this.time,
      reminderMinutes: reminderMinutes ?? this.reminderMinutes,
      room:            room            ?? this.room,
    );
  }

  Map<String, dynamic> toJson() => {
    'id':              id,
    'name':            name,
    'days':            days,
    'timeHour':        time.hour,
    'timeMinute':      time.minute,
    'reminderMinutes': reminderMinutes,
    'room':            room,
  };

  factory ClassSchedule.fromJson(Map<String, dynamic> j) {
    return ClassSchedule(
      id:              j['id'] as String,
      name:            j['name'] as String,
      days:            List<int>.from(j['days'] as List),
      time:            TimeOfDay(
                         hour:   (j['timeHour']   as num).toInt(),
                         minute: (j['timeMinute'] as num).toInt(),
                       ),
      reminderMinutes: (j['reminderMinutes'] as num).toInt(),
      room:            j['room'] as String?,
    );
  }
}