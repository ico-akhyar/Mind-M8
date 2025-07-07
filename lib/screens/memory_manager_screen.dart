// screens/memory_manager_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/personal_details.dart';
import '../providers/auth_provider.dart';

class MemoryManagerScreen extends ConsumerStatefulWidget {
  const MemoryManagerScreen({super.key});

  @override
  ConsumerState<MemoryManagerScreen> createState() => _MemoryManagerScreenState();
}

class _MemoryManagerScreenState extends ConsumerState<MemoryManagerScreen> {
  final Map<String, List<PersonalDetail>> _groupedDetails = {};
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadMemories();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadMemories() async {
    final user = ref.read(authProvider);
    if (user == null) return;

    setState(() => _isLoading = true);
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('details')
          .get();

      _groupedDetails.clear();
      for (final doc in snapshot.docs) {
        final detail = PersonalDetail.fromFirestore(doc, null);
        _groupedDetails.putIfAbsent(detail.category, () => []).add(detail);
      }

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load memories: $e')),
      );
    }
  }

  Future<void> _deleteMemory(String category, String docId) async {
    final user = ref.read(authProvider);
    if (user == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('details')
          .doc(docId)
          .delete();

      setState(() {
        _groupedDetails[category]?.removeWhere((d) => d.id == docId);
        if (_groupedDetails[category]?.isEmpty ?? false) {
          _groupedDetails.remove(category);
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Memory deleted')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete: $e')),
      );
    }
  }

  Future<void> _updateMemory(PersonalDetail detail) async {
    final user = ref.read(authProvider);
    if (user == null || detail.id == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('details')
          .doc(detail.id)
          .update(detail.toFirestore());

      setState(() {
        final categoryList = _groupedDetails[detail.category];
        if (categoryList != null) {
          final index = categoryList.indexWhere((d) => d.id == detail.id);
          if (index != -1) {
            categoryList[index] = detail;
          }
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Memory updated')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update: $e')),
      );
    }
  }

  void _showEditDialog(PersonalDetail detail) {
    final categoryController = TextEditingController(text: detail.category);
    final detailController = TextEditingController(text: detail.detail);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Memory'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: categoryController,
              decoration: const InputDecoration(
                labelText: 'Category',
                hintText: 'e.g., relationship, education',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: detailController,
              decoration: const InputDecoration(
                labelText: 'Detail',
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final updated = detail.copyWith(
                category: categoryController.text.trim(),
                detail: detailController.text.trim(),
                timestamp: DateTime.now(),
              );
              _updateMemory(updated);
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Widget _buildMemoryCard(PersonalDetail detail) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: ListTile(
        title: Text(detail.detail),
        subtitle: Text(
          'Updated: ${detail.timestamp.toString().split(' ')[0]}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit, size: 20),
              onPressed: () => _showEditDialog(detail),
            ),
            IconButton(
              icon: const Icon(Icons.delete, size: 20, color: Colors.red),
              onPressed: () => _showDeleteDialog(detail.category, detail.id!),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategorySection(String category, List<PersonalDetail> details) {
    final filteredDetails = details.where((detail) {
      return detail.detail.toLowerCase().contains(_searchQuery) ||
          detail.category.toLowerCase().contains(_searchQuery);
    }).toList();

    if (filteredDetails.isEmpty) return const SizedBox();

    return Card(
      margin: const EdgeInsets.all(8),
      child: ExpansionTile(
        title: Text(
          category.toUpperCase(),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        children: filteredDetails.map(_buildMemoryCard).toList(),
      ),
    );
  }

  void _showDeleteDialog(String category, String docId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Memory?'),
        content: const Text('This will permanently remove this detail from your memory.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteMemory(category, docId);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredCategories = _groupedDetails.entries.where((entry) {
      return entry.key.toLowerCase().contains(_searchQuery) ||
          entry.value.any((detail) =>
              detail.detail.toLowerCase().contains(_searchQuery));
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Memory'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadMemories,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search memories...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _groupedDetails.isEmpty
                ? const Center(child: Text('No memories found'))
                : ListView(
              children: filteredCategories.map((entry) {
                return _buildCategorySection(entry.key, entry.value);
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}