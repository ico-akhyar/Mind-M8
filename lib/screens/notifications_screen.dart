import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/notification_prefs_provider.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  Future<void> _selectTime(BuildContext context, WidgetRef ref) async {
    final currentTime = ref.read(notificationPrefsProvider).reminderTime;
    final theme = Theme.of(context);
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: currentTime,
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: theme.copyWith(
            colorScheme: theme.colorScheme.copyWith(
              primary: theme.colorScheme.primary,
              onPrimary: Colors.white,
              surface: theme.cardTheme.color!,
              onSurface: theme.colorScheme.onSurface,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != currentTime) {
      ref.read(notificationPrefsProvider.notifier).setReminderTime(picked);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final prefs = ref.watch(notificationPrefsProvider);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('Notifications', style: theme.textTheme.titleLarge),
        backgroundColor: theme.appBarTheme.backgroundColor,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: theme.cardTheme.color,
            child: Column(
              children: [
                RadioListTile<int>(
                  title: Text('Off', style: theme.textTheme.bodyLarge),
                  value: 0,
                  groupValue: prefs.mode,
                  onChanged: (value) => ref.read(notificationPrefsProvider.notifier).setMode(value!),
                ),
                Divider(color: theme.dividerTheme.color),
                RadioListTile<int>(
                  title: Text('Mind M8 Smart Notification', style: theme.textTheme.bodyLarge),
                  value: 1,
                  groupValue: prefs.mode,
                  onChanged: (value) => ref.read(notificationPrefsProvider.notifier).setMode(value!),
                ),
                Divider(color: theme.dividerTheme.color),
                RadioListTile<int>(
                  title: Text('Custom', style: theme.textTheme.bodyLarge),
                  value: 2,
                  groupValue: prefs.mode,
                  onChanged: (value) => ref.read(notificationPrefsProvider.notifier).setMode(value!),
                ),
              ],
            ),
          ),
          if (prefs.mode == 2) ...[
            const SizedBox(height: 16),
            Card(
              color: theme.cardTheme.color,
              child: Column(
                children: [
                  SwitchListTile(
                    title: Text('Daily Reminder', style: theme.textTheme.bodyLarge),
                    value: prefs.dailyReminder,
                    onChanged: (value) => ref.read(notificationPrefsProvider.notifier).setDailyReminder(value),
                  ),
                  if (prefs.dailyReminder) ...[
                    Divider(color: theme.dividerTheme.color),
                    ListTile(
                      title: Text('Reminder Time', style: theme.textTheme.bodyLarge),
                      subtitle: Text(prefs.reminderTime.format(context), style: theme.textTheme.bodyMedium),
                      trailing: Icon(Icons.access_time, color: theme.colorScheme.onSurface),
                      onTap: () => _selectTime(context, ref),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}