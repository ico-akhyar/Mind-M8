import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PaymentDialog extends StatefulWidget {
  final String method; // JazzCash, EasyPaisa, Bank Transfer
  final String plan; // Monthly, Annual

  const PaymentDialog({
    super.key,
    required this.method,
    required this.plan,
  });

  @override
  State<PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<PaymentDialog> {
  final TextEditingController _accountNameController = TextEditingController();
  final TextEditingController _paymentAccountController = TextEditingController();
  final TextEditingController _transactionIdController = TextEditingController();
  bool _isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('${widget.plan} - ${widget.method} Payment'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildInstructions(widget.method),
            const SizedBox(height: 20),
            TextField(
              controller: _accountNameController,
              decoration: const InputDecoration(
                labelText: 'Your Account Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _paymentAccountController,
              decoration: InputDecoration(
                labelText: widget.method == 'Bank Transfer'
                    ? 'Your Bank Account Number'
                    : 'Your Mobile Number',
                border: const OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _transactionIdController,
              decoration: const InputDecoration(
                labelText: 'Transaction ID/Reference Number',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isSubmitting ? null : _submitPayment,
          child: _isSubmitting
              ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
              : const Text('Submit Payment'),
        ),
      ],
    );
  }

  Widget _buildInstructions(String method) {
    if (method == 'JazzCash') {
      return const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Payment Instructions:'),
          Text(
              '1. Send Rs. 500 to JazzCash: 0320-6313989\nAccount Title: Ikhiar Ahmed'),
          Text('2. Enter your details below'),
        ],
      );
    } else if (method == 'EasyPaisa') {
      return const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Payment Instructions:'),
          Text(
              '1. Send Rs. 500 to EasyPaisa: 0320-6313989\nAccount Title: Ikhiar Ahmed'),
          Text('2. Enter your details below'),
        ],
      );
    } else {
      return const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Payment Instructions:'),
          Text('Transfer to:'),
          Text('Bank: Meezan Bank'),
          Text('Account Title: Akhyar Ahmad'),
          Text('Account #: 9821 0111325860'),
          Text('IBAN: PK64MEZN0098210111325860'),
          SizedBox(height: 8),
          Text('2. Enter your details below'),
        ],
      );
    }
  }

  Future<void> _submitPayment() async {
    final accountName = _accountNameController.text.trim();
    final paymentAccount = _paymentAccountController.text.trim();
    final transactionId = _transactionIdController.text.trim();

    if (accountName.isEmpty || paymentAccount.isEmpty ||
        transactionId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all the fields')),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isSubmitting = true);

    try {
      await FirebaseFirestore.instance.collection('paymentRequests').add({
        'userId': user.uid,
        'plan': widget.plan,
        'method': widget.method,
        'accountName': accountName,
        'paymentAccount': paymentAccount,
        'transactionId': transactionId,
        'status': 'pending',
        'requestedAt': FieldValue.serverTimestamp(),
        // Use FieldValue instead of Timestamp
        'amount': widget.plan == 'Monthly' ? 500 : 5000,
      });

      if (mounted) {
        Navigator.pop(context); // Close dialog
        Navigator.pop(context); // Go back to plans screen
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(
              '${widget.plan} payment submitted for verification')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }
}