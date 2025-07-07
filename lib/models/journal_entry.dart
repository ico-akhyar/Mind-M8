import 'package:cloud_firestore/cloud_firestore.dart';

enum MessageRole { user, ai }

class ChatMessage {
  final String? id;
  final String userId;
  final MessageRole role;
  final String content;
  final DateTime timestamp;
  final bool isProactive;
  final bool isOptimistic;

  ChatMessage({
    this.id,
    required this.userId,
    required this.role,
    required this.content,
    required this.timestamp,
    this.isProactive = false,
    this.isOptimistic = false,
  });

  Map<String, dynamic> toJson() => {
    'userId': userId,
    'role': role == MessageRole.user ? 'user' : 'ai',
    'content': content,
    'timestamp': timestamp.toIso8601String(),
    'isProactive': isProactive,
    'isOptimistic': isOptimistic,
  };

  factory ChatMessage.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    DateTime timestamp;
    if (data['timestamp'] is Timestamp) {
      timestamp = (data['timestamp'] as Timestamp).toDate();
    } else {
      timestamp = DateTime.parse(data['timestamp'] as String);
    }
    return ChatMessage(
      id: doc.id,
      userId: data['userId'] as String,
      role: data['role'] == 'user' ? MessageRole.user : MessageRole.ai,
      content: data['content'] as String,
      timestamp: timestamp,
      isProactive: data['isProactive'] ?? false,
      isOptimistic: data['isOptimistic'] ?? false,
    );
  }

  ChatMessage copyWith({
    String? id,
    String? userId,
    MessageRole? role,
    String? content,
    DateTime? timestamp,
    bool? isProactive,
    bool? isOptimistic,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      role: role ?? this.role,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      isProactive: isProactive ?? this.isProactive,
      isOptimistic: isOptimistic ?? this.isOptimistic,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is ChatMessage &&
              runtimeType == other.runtimeType &&
              id == other.id &&
              userId == other.userId &&
              role == other.role &&
              content == other.content &&
              timestamp == other.timestamp &&
              isProactive == other.isProactive &&
              isOptimistic == other.isOptimistic;

  @override
  int get hashCode =>
      id.hashCode ^
      userId.hashCode ^
      role.hashCode ^
      content.hashCode ^
      timestamp.hashCode ^
      isProactive.hashCode ^
      isOptimistic.hashCode;

  @override
  String toString() {
    return 'ChatMessage{id: $id, userId: $userId, role: $role, content: $content, '
        'timestamp: $timestamp, isProactive: $isProactive, isOptimistic: $isOptimistic}';
  }
}