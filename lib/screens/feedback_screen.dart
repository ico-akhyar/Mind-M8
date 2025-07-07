import 'package:flutter/material.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:url_launcher/url_launcher.dart'; // For email/phone launching

// Add this at the bottom of app_drawer.dart
class FeedbackScreen extends StatelessWidget {
  const FeedbackScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Feedback & Suggestions'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            Text(
              'We\'d love to hear from you!',
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            Text(
              'For feedback and suggestions.',
              style: theme.textTheme.labelLarge,
            ),
            const SizedBox(height: 16),
            _buildContactCard(
              context,
              icon: FeatherIcons.mail,
              title: 'Email us',
              subtitle: 'oryvoai@gmail.com',
              onTap: () => _launchEmail(),
            ),
            const SizedBox(height: 12),
            _buildContactCard(
              context,
              icon: FeatherIcons.phone,
              title: 'Whatsapp us',
              subtitle: '+92 (320) 6313989',
              onTap: () => _launchPhone(),
            ),
            const Spacer(),
            const Divider(),
            const SizedBox(height: 8),
            Text(
              'MindM8 v1.0 -Beta',
              style: theme.textTheme.bodySmall,
            ),
            Text(
              '© 2025 Oryvo Team',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactCard(
      BuildContext context, {
        required IconData icon,
        required String title,
        required String subtitle,
        required VoidCallback onTap,
      }) {
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        onTap: onTap,
      ),
    );
  }

  void _launchEmail() async {
    // Implement email launch
    final uri = Uri.parse('mailto:oryvoai@gmail.com?subject=MindM8 Feedback');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _launchPhone() async {
    // Implement phone launch
    final uri = Uri.parse('tel:+923206313989');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }
}