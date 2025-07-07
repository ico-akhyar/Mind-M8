import 'package:flutter/material.dart';

class NotificationPreferences {
  final int mode; // 0 = Off, 1 = Auto, 2 = Custom
  final bool dailyReminder;
  final TimeOfDay reminderTime;

  NotificationPreferences({
    required this.mode,
    required this.dailyReminder,
    required this.reminderTime,
  });

  NotificationPreferences copyWith({
    int? mode,
    bool? dailyReminder,
    TimeOfDay? reminderTime,
  }) {
    return NotificationPreferences(
      mode: mode ?? this.mode,
      dailyReminder: dailyReminder ?? this.dailyReminder,
      reminderTime: reminderTime ?? this.reminderTime,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'mode': mode,
      'dailyReminder': dailyReminder,
      'reminderTimeHour': reminderTime.hour,
      'reminderTimeMinute': reminderTime.minute,
    };
  }

  factory NotificationPreferences.fromMap(Map<String, dynamic> map) {
    return NotificationPreferences(
      mode: map['mode'] as int,
      dailyReminder: map['dailyReminder'] as bool,
      reminderTime: TimeOfDay(
        hour: map['reminderTimeHour'] as int,
        minute: map['reminderTimeMinute'] as int,
      ),
    );
  }
}