// Update settings_screen.dart
import 'package:flutter/material.dart';
import 'memory_manager_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/theme_provider.dart';
import 'notifications_screen.dart';
import 'personalization_screen.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  void _launchEmail() async {
    final uri = Uri.parse('mailto:oryvoai@gmail.com?subject=MindM8 Feedback');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _launchPhone() async {
    final uri = Uri.parse('tel:+923206313989');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDarkMode = ref.watch(themeProvider) == ThemeMode.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Settings',
          style: theme.textTheme.titleLarge,
        ),
        backgroundColor: theme.appBarTheme.backgroundColor,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: theme.cardTheme.color,
            child: Column(
              children: [

                Divider(
                  color: theme.dividerTheme.color,
                  height: 1,
                ),
                SwitchListTile(
                  title: Text(
                    'Dark Mode',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  value: isDarkMode,
                  onChanged: (value) {
                    ref.read(themeProvider.notifier).toggleTheme(value);
                  },
                ),
                Divider(
                  color: theme.dividerTheme.color,
                  height: 1,
                ),
                ListTile(
                  title: Text(
                    'Personalize M8',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  trailing: Icon(
                    Icons.chevron_right,
                    color: theme.colorScheme.onSurface,
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const PersonalizationScreen(),
                      ),
                    );
                  },
                ),
                ListTile(
                  title: Text(
                    'Notifications',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  trailing: Icon(
                    Icons.chevron_right,
                    color: theme.colorScheme.onSurface,
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const NotificationsScreen(),
                      ),
                    );
                  },
                ),
                ListTile(
                  title: Text(
                    'Manage Memory',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  trailing: Icon(
                    Icons.chevron_right,
                    color: theme.colorScheme.onSurface,
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const MemoryManagerScreen(),
                      ),
                    );
                  },
                ),

                ListTile(
                  title: Text(
                    'Feedback & Suggestions',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  trailing: Icon(
                    Icons.chevron_right,
                    color: theme.colorScheme.onSurface,
                  ),
                  onTap: () {
                    showModalBottomSheet(
                      context: context,
                      builder: (context) => Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'We\'d love to hear from you!',
                              style: theme.textTheme.headlineSmall,
                            ),
                            const SizedBox(height: 16),
                            ListTile(
                              leading: const Icon(Icons.email),
                              title: const Text('Email us'),
                              subtitle: const Text('oryvoai@gmail.com'),
                              onTap: _launchEmail,
                            ),
                            ListTile(
                              leading: const Icon(Icons.phone),
                              title: const Text('Whatsapp us'),
                              subtitle: const Text('+92 (320) 6313989'),
                              onTap: _launchPhone,
                            ),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}