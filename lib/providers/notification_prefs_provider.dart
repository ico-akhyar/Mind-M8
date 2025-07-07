import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/notification_preferences.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

final notificationPrefsProvider =
StateNotifierProvider<NotificationPrefsNotifier, NotificationPreferences>((ref) {
  return NotificationPrefsNotifier();
});

class NotificationPrefsNotifier extends StateNotifier<NotificationPreferences> {
  static const _prefsKey = 'notification_preferences';

  NotificationPrefsNotifier() : super(_defaultPrefs()) {
    loadPreferences();
  }

  static NotificationPreferences _defaultPrefs() => NotificationPreferences(
    mode: 0, // Default to Off
    dailyReminder: true,
    reminderTime: const TimeOfDay(hour: 20, minute: 0),
  );

  Future<void> loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_prefsKey);
      if (jsonString != null) {
        final map = json.decode(jsonString) as Map<String, dynamic>;
        state = NotificationPreferences.fromMap(map);
      }
    } catch (e) {
      debugPrint('Error loading notification prefs: $e');
      state = _defaultPrefs();
      await _savePreferences();
    }
  }

  Future<void> _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, json.encode(state.toMap()));
  }

  void setMode(int mode) {
    state = state.copyWith(mode: mode);
    _savePreferences();
  }

  void setDailyReminder(bool value) {
    state = state.copyWith(dailyReminder: value);
    _savePreferences();
  }

  void setReminderTime(TimeOfDay time) {
    state = state.copyWith(reminderTime: time);
    _savePreferences();
  }
}