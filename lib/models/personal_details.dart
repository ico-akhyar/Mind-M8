// models/personal_detail.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class PersonalDetail {
  final String? id;
  final String category;
  final String detail;
  final DateTime timestamp;
  final List<String> examples;

  PersonalDetail({
    this.id,
    required this.category,
    required this.detail,
    required this.timestamp,
    required this.examples,
  });

  PersonalDetail copyWith({
    String? category,
    String? detail,
    DateTime? timestamp,
    List<String>? examples,
  }) {
    return PersonalDetail(
      id: id,
      category: category ?? this.category,
      detail: detail ?? this.detail,
      timestamp: timestamp ?? this.timestamp,
      examples: examples ?? this.examples,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'category': category,
      'detail': detail,
      'timestamp': Timestamp.fromDate(timestamp),
      'examples': examples,
    };
  }

  factory PersonalDetail.fromMap(Map<String, dynamic> map) {
    return PersonalDetail(
      id: map['id'],
      category: (map['category'] as String?) ?? 'other',
      detail: (map['detail'] as String?) ?? '',
      timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      examples: List<String>.from(map['examples'] as List? ?? []),
    );
  }

  factory PersonalDetail.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> snapshot,
      SnapshotOptions? options,
      ) {
    final data = snapshot.data() ?? {};

    print('category value: ${data['category']} (${data['category']?.runtimeType})');


    return PersonalDetail(
      id: snapshot.id,
      category: (data['category'] as String?) ?? 'other',
      detail: (data['detail'] as String?) ?? '',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      examples: List<String>.from(data['examples'] as List? ?? []),
    );
  }

  Map<String, dynamic> toFirestore() {
    return toMap();
  }
}