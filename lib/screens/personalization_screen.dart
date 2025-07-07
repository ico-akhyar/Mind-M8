import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../providers/auth_provider.dart';
import '../services/gpt_service.dart';

class PersonalizationScreen extends ConsumerStatefulWidget {
  const PersonalizationScreen({super.key});

  @override
  ConsumerState<PersonalizationScreen> createState() => _PersonalizationScreenState();
}

class _PersonalizationScreenState extends ConsumerState<PersonalizationScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _ageController;
  late TextEditingController _occupationController;
  late TextEditingController _bioController;
  String? _gender;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _ageController = TextEditingController();
    _occupationController = TextEditingController();
    _bioController = TextEditingController();
    _loadUserData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _occupationController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final user = ref.read(authProvider);
    if (user == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('personalization')
        .doc('details')
        .get();

    if (doc.exists) {
      setState(() {
        _nameController.text = doc.data()?['name'] ?? '';
        _ageController.text = doc.data()?['age']?.toString() ?? '';
        _occupationController.text = doc.data()?['occupation'] ?? '';
        _bioController.text = doc.data()?['bio'] ?? '';
        _gender = doc.data()?['gender'];
      });
    }
  }

  Future<void> _savePersonalization() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final user = ref.read(authProvider);
    if (user == null) return;

    final data = {
      if (_nameController.text.isNotEmpty) 'name': _nameController.text,
      if (_ageController.text.isNotEmpty) 'age': int.tryParse(_ageController.text),
      if (_occupationController.text.isNotEmpty) 'occupation': _occupationController.text,
      if (_bioController.text.isNotEmpty) 'bio': _bioController.text,
      if (_gender != null) 'gender': _gender,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('personalization')
          .doc('details')
          .set(data, SetOptions(merge: true));

      if (mounted) {
        final gptService = GPTService();
        gptService.forceRefreshCache();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Personalization saved!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Personalize M8'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Name',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.8),
                ),
              ),
              const SizedBox(height: 4),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                ),
                maxLength: 20,
                validator: (value) {
                  if (value != null && value.length > 20) {
                    return 'Name too long';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Text(
                'Gender',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.8),
                ),
              ),
              const SizedBox(height: 4),
              DropdownButtonFormField<String>(
                value: _gender,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                items: const [
                  DropdownMenuItem(value: 'male', child: Text('Male')),
                  DropdownMenuItem(value: 'female', child: Text('Female')),
                  DropdownMenuItem(value: 'other', child: Text('Other')),
                  DropdownMenuItem(value: 'prefer-not-to-say', child: Text('Prefer not to say')),
                ],
                onChanged: (value) => setState(() => _gender = value),
                hint: const Text('Select gender'),
              ),
              const SizedBox(height: 16),
              Text(
                'Age',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.8),
                ),
              ),
              const SizedBox(height: 4),
              TextFormField(
                controller: _ageController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value != null && value.isNotEmpty) {
                    final age = int.tryParse(value);
                    if (age == null || age < 13 || age > 99) {
                      return 'Enter valid age (13-99)';
                    }
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Text(
                'Occupation',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.8),
                ),
              ),
              const SizedBox(height: 4),
              TextFormField(
                controller: _occupationController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                ),
                maxLength: 20,
                validator: (value) {
                  if (value != null && value.length > 20) {
                    return 'Occupation too long';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Text(
                'Bio (100 chars max)',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.8),
                ),
              ),
              const SizedBox(height: 4),
              TextFormField(
                controller: _bioController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                ),
                maxLength: 100,
                maxLines: 3,
                validator: (value) {
                  if (value != null && value.length > 100) {
                    return 'Bio too long';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _savePersonalization,
                  child: _isLoading
                      ? const CircularProgressIndicator()
                      : const Text('Save Personalization'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}