import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../providers/auth_provider.dart';
import 'premium_plans_screen.dart';

class SubscriptionStatusScreen extends ConsumerWidget {
  const SubscriptionStatusScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Subscription Status'),
        centerTitle: true,
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection('users')
            .doc(user?.uid)
            .get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('No subscription data found'));
          }

          final userData = snapshot.data!.data() as Map<String, dynamic>;
          final isPremium = userData['isPremium'] == true;
          final premiumPlan = userData['premiumPlan'] ?? '';
          final premiumSince = userData['premiumSince'] as Timestamp?;
          final premiumExpiry = userData['premiumExpiry'] as Timestamp?;
          final dailyMessageCount = userData['dailyMessageCount'] ?? 0;
          final lastReset = userData['lastMessageCountReset'] as Timestamp?;

          final messageLimit = isPremium ? 50 : 10;
          final remainingMessages = messageLimit - dailyMessageCount;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
                children: [
                // Subscription Status Card
                Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                  Row(
                  children: [
                  Icon(
                  isPremium ? Icons.star : Icons.star_border,
                    color: isPremium
                        ? Colors.amber
                        : theme.colorScheme.onSurface.withOpacity(0.5),
                    size: 30,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    isPremium ? 'Premium Member' : 'Free Plan',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  ],
                ),
                const SizedBox(height: 20),
                if (isPremium) ...[
            _buildStatusItem(
            context,
            icon: Icons.credit_card,
            label: 'Plan',
            value: premiumPlan,
          ),
          const Divider(height: 30),
          _buildStatusItem(
          context,
          icon: Icons.calendar_today,
          label: 'Started On',
          value: premiumSince != null
          ? DateFormat('MMM d, y').format(premiumSince.toDate())
              : 'N/A',
          ),
          const Divider(height: 30),
          _buildStatusItem(
          context,
          icon: Icons.event_available,
          label: 'Expires On',
          value: premiumExpiry != null
          ? DateFormat('MMM d, y').format(premiumExpiry.toDate())
              : 'N/A',
          ),
          const Divider(height: 30),
                  _buildStatusItem(
                    context,
                    icon: Icons.access_time,
                    label: 'Time Remaining',
                    value: premiumExpiry != null
                        ? _formatRemainingTime(premiumExpiry.toDate())
                        : 'N/A',
                  ),
          ] else ...[
          Text(
          'Upgrade to unlock premium features',
          style: theme.textTheme.bodyLarge?.copyWith(
          color: theme.colorScheme.onSurface.withOpacity(0.7),
          ),
          ),
          const SizedBox(height: 20),
          FilledButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const PremiumPlansScreen()),
            );

          },
          child: const Text('Upgrade Now'),
          ),
                ],
          ],
          ),
          ),
          ),
          const SizedBox(height: 20),

          // Daily Usage Card
          Card(
          elevation: 4,
          shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
          children: [
          Text(
          'Daily Usage',
          style: theme.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.bold,
          ),
          ),
          const SizedBox(height: 16),
          LinearProgressIndicator(
          value: dailyMessageCount / messageLimit,
          backgroundColor: theme.colorScheme.surfaceVariant,
          color: isPremium
          ? theme.colorScheme.primary
              : Colors.orange,
          minHeight: 10,
          borderRadius: BorderRadius.circular(5),
          ),
          const SizedBox(height: 16),
          Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
          Text(
          'Messages Used',
          style: theme.textTheme.bodyMedium,
          ),
          Text(
          '$dailyMessageCount/$messageLimit',
          style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.bold,
          ),
          ),
          ],
          ),
          const SizedBox(height: 8),
          Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
          Text(
          'Messages Remaining',
          style: theme.textTheme.bodyMedium,
          ),
          Text(
          '$remainingMessages',
          style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.bold,
          color: remainingMessages > 0
          ? theme.colorScheme.primary
              : theme.colorScheme.error,
          ),
          ),
          ],
          ),
          const SizedBox(height: 8),
          if (lastReset != null) ...[
          const Divider(height: 30),
          _buildStatusItem(
          context,
          icon: Icons.refresh,
          label: 'Resets On',
          value: DateFormat('MMM d, y').format(
          lastReset.toDate().add(const Duration(days: 1)),
          ),
          )
          ],
          ],
          ),
          ),
          ),
          ],
          ),
          );
        },
      ),
    );
  }

  // Add this new helper method to the class:
  String _formatRemainingTime(DateTime expiryDate) {
    final now = DateTime.now();
    if (expiryDate.isBefore(now)) return 'Expired';

    final difference = expiryDate.difference(now);
    final days = difference.inDays;
    final hours = difference.inHours.remainder(24);

    if (days > 0 && hours > 0) {
      return '$days days $hours hours';
    } else if (days > 0) {
      return '$days days';
    } else if (hours > 0) {
      return '$hours hours';
    } else {
      final minutes = difference.inMinutes.remainder(60);
      return '$minutes minutes';
    }
  }

  Widget _buildStatusItem(
      BuildContext context, {
        required IconData icon,
        required String label,
        required String value,
      }) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Icon(
          icon,
          color: theme.colorScheme.primary,
          size: 24,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}