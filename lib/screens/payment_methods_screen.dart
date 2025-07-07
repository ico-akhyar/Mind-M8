import 'package:flutter/material.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'paymentdialog.dart';

class PaymentMethodsScreen extends StatelessWidget {
  final String plan;

  const PaymentMethodsScreen({super.key, required this.plan});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Payment for $plan'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Plan summary
            _buildPlanSummary(context),
            const SizedBox(height: 32),

            // Payment Methods
            Text(
              'Select Payment Method',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            _buildPaymentMethods(context),

            // Footer note
            const SizedBox(height: 32),
            _buildFooterNote(context),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanSummary(BuildContext context) {
    final theme = Theme.of(context);
    final price = plan == 'Monthly' ? 'Rs. 500' : 'Rs. 5,000';

    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              FeatherIcons.creditCard,
              size: 24,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  plan,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  price,
                  style: theme.textTheme.bodyLarge,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentMethods(BuildContext context) {
    return Column(
      children: [
        _buildPaymentMethod(
          context,
          icon: Icons.phone_android,
          label: 'JazzCash',
          onTap: () {
            _showPaymentDialog(context, 'JazzCash');
          },
        ),
        const SizedBox(height: 12),
        _buildPaymentMethod(
          context,
          icon: Icons.phone_iphone,
          label: 'EasyPaisa',
          onTap: () {
            _showPaymentDialog(context, 'EasyPaisa');
          },
        ),
        const SizedBox(height: 12),
        _buildPaymentMethod(
          context,
          icon: Icons.account_balance,
          label: 'Bank Transfer',
          onTap: () {
            _showPaymentDialog(context, 'Bank Transfer');
          },
        ),
      ],
    );
  }

  void _showPaymentDialog(BuildContext context, String method) {
    showDialog(
      context: context,
      builder: (_) => PaymentDialog(
        method: method,
        plan: plan,
      ),
    );
  }

  Widget _buildPaymentMethod(
      BuildContext context, {
        required IconData icon,
        required String label,
        required VoidCallback onTap,
      }) {
    final theme = Theme.of(context);

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: theme.colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                icon,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 16),
              Text(
                label,
                style: theme.textTheme.bodyLarge,
              ),
              const Spacer(),
              Icon(
                Icons.chevron_right,
                color: theme.colorScheme.onSurface.withOpacity(0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFooterNote(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Text(
          'Manual Verification Process',
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'After payment submission, our team will manually verify your transaction '
              'within 24 hours. You\'ll receive a confirmation email once your premium '
              'access is activated.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.7),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}