import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/journal_entry.dart';
import '../services/gpt_service.dart';
import '../providers/server_time_provider.dart';
import '../providers/auth_provider.dart';
import 'dart:async';

final typingStateProvider = StateProvider<bool>((ref) => false);
final chatProvider = StateNotifierProvider<ChatNotifier, List<ChatMessage>>((ref) {
  return ChatNotifier(ref);
});

class MessageLimitInfo {
  final int used;
  final int max;

  MessageLimitInfo(this.used, this.max);

  int get remaining => max - used;
  bool get limitReached => used >= max;
}

class ChatNotifier extends StateNotifier<List<ChatMessage>> {
  final Ref ref;
  ChatNotifier(this.ref) : super([]);

  void clearMessages() {
    state = [];
    _lastDoc = null;
  }

  void addOptimisticUserMessage(String message) {
    final optimisticMessage = ChatMessage(
      userId: ref.read(authProvider)?.uid ?? 'temp',
      role: MessageRole.user,
      content: message,
      timestamp: DateTime.now(),
      isOptimistic: true,
    );
    state = [...state, optimisticMessage];
  }

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoadingMore = false;
  DocumentSnapshot? _lastDoc;
  static const int _messageLimit = 30;

  Future<void> handleProactiveNotification(String message, String userId) async {
    if (state.any((m) => m.content == message)) return;

    final aiMsg = ChatMessage(
      userId: userId,
      role: MessageRole.ai,
      content: message,
      timestamp: DateTime.now(),
      isProactive: true,
    );

    final docRef = await _firestore
        .collection('users')
        .doc(userId)
        .collection('messages')
        .add({
      'userId': userId,
      'role': 'ai',
      'content': message,
      'timestamp': FieldValue.serverTimestamp(),
      'isProactive': true,
    });

    state = [...state, aiMsg.copyWith(id: docRef.id)];
  }

  Future<void> _updateUserDoc(String userId, {String? lastMessage}) async {
    final userDoc = _firestore.collection('users').doc(userId);
    await userDoc.set({
      'lastActive': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      if (lastMessage != null) 'lastMessagePreview': lastMessage,
    }, SetOptions(merge: true));
  }

  Future<void> fetchInitialMessages(String userId, {bool isPremium = false}) async {
    try {
      // Keep existing optimistic and proactive messages
      final existingMessages = state.where((msg) =>
      msg.isOptimistic || msg.isProactive).toList();

      // Remove limit to load all messages initially
      final query = _firestore
          .collection('users')
          .doc(userId)
          .collection('messages')
          .orderBy('timestamp', descending: false);

      final snapshot = await query.get();
      _lastDoc = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;

      // Create a map of existing messages for quick lookup
      final existingMessageMap = {for (var msg in existingMessages) msg.id: msg};

      // Merge new messages with existing ones
      final newMessages = snapshot.docs
          .map((doc) => ChatMessage.fromFirestore(doc))
          .where((msg) => !existingMessageMap.containsKey(msg.id))
          .toList();

      state = [...existingMessages, ...newMessages]
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    } catch (e) {
      print('Error fetching messages: $e');
      throw Exception('Failed to fetch messages: $e');
    }
  }

  Future<void> deleteMessage(String messageId, String userId) async {
    try {
      final batch = _firestore.batch();
      final messagesRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('messages');

      final messageIndex = state.indexWhere((msg) => msg.id == messageId);
      if (messageIndex == -1) return;
      final message = state[messageIndex];

      batch.delete(messagesRef.doc(messageId));

      if (message.role == MessageRole.user &&
          messageIndex + 1 < state.length) {
        final nextMessage = state[messageIndex + 1];
        if (nextMessage.role == MessageRole.ai) {
          batch.delete(messagesRef.doc(nextMessage.id));
        }
      } else if (message.role == MessageRole.ai &&
          messageIndex > 0) {
        final prevMessage = state[messageIndex - 1];
        if (prevMessage.role == MessageRole.user) {
          batch.delete(messagesRef.doc(prevMessage.id));
        }
      }

      await batch.commit();

      state = state.where((msg) => msg.id != messageId &&
          (message.role == MessageRole.user
              ? msg.id != state[messageIndex + 1 < state.length
              ? messageIndex + 1
              : messageIndex].id
              : msg.id != state[messageIndex - 1 >= 0
              ? messageIndex - 1
              : messageIndex].id)).toList();
    } catch (e) {
      print('Error deleting message: $e');
      throw Exception('Failed to delete message');
    }
  }

  Future<void> loadMoreMessages(String userId, {bool isPremium = false}) async {
    if (_isLoadingMore || _lastDoc == null) return;
    _isLoadingMore = true;

    try {
      final query = _firestore
          .collection('users')
          .doc(userId)
          .collection('messages')
          .orderBy('timestamp', descending: false)
          .startAfterDocument(_lastDoc!)
          .limit(_messageLimit);

      final snapshot = await query.get();
      if (snapshot.docs.isNotEmpty) {
        _lastDoc = snapshot.docs.last;

        // Create a map of existing messages for quick lookup
        final existingMessages = {for (var msg in state) msg.id: msg};

        final newMessages = snapshot.docs
            .map((doc) => ChatMessage.fromFirestore(doc))
            .where((msg) => !existingMessages.containsKey(msg.id))
            .toList();

        // Insert at beginning instead of appending
        state = [...newMessages, ...state];
      }
    } catch (e) {
      print('Error loading more messages: $e');
    } finally {
      _isLoadingMore = false;
    }
  }

  Future<DateTime> getServerTimeReference() async {
    final offset = ref.read(serverTimeOffsetProvider);
    return DateTime.now().add(offset);
  }

  Future<MessageLimitInfo> getMessageLimitInfo(String userId, bool isPremium) async {
    try {
      final serverTime = await getServerTimeReference();
      final startOfDay = DateTime(serverTime.year, serverTime.month, serverTime.day);

      final userDoc = await _firestore.collection('users').doc(userId).get();
      final userData = userDoc.data() ?? {};

      final Timestamp? lastResetTs = userData['lastMessageCountReset'];
      final lastReset = lastResetTs?.toDate();
      final count = userData['dailyMessageCount'] ?? 0;

      // If it's a new day, update the document and return 0 count
      if (lastReset == null || lastReset.isBefore(startOfDay)) {
        await _firestore.collection('users').doc(userId).update({
          'lastMessageCountReset': FieldValue.serverTimestamp(),
          'dailyMessageCount': 0,
        });
        return MessageLimitInfo(0, isPremium ? 50 : 10);
      }

      return MessageLimitInfo(count, isPremium ? 50 : 10);
    } catch (e) {
      print('Error getting message count: $e');
      return MessageLimitInfo(0, isPremium ? 50 : 10);
    }
  }

  Future<void> sendMessage({
    required String userId,
    required String message,
    required bool isPremium,
  }) async {
    final stopwatch = Stopwatch()..start();
    print('Stopwatch Started');

    try {
      // Pre-check limits
      // final limitInfo = await getMessageLimitInfo(userId, isPremium);
      // if (limitInfo.limitReached) {
      //   state = state.where((msg) => !msg.isOptimistic).toList();
      //   throw Exception('Daily message limit reached');
      // }

      print('Initialized GPT: ${stopwatch.elapsed.inMilliseconds}ms');
      stopwatch.reset();

      // Prepare messages
      final userMsgId = _firestore.collection('users/$userId/messages').doc().id;
      final aiMsgId = _firestore.collection('users/$userId/messages').doc().id;

      print('Collected Ids: ${stopwatch.elapsed.inMilliseconds}ms');
      stopwatch.reset();

      // Create optimistic messages
      final userMsg = ChatMessage(
        id: userMsgId,
        userId: userId,
        role: MessageRole.user,
        content: message,
        timestamp: DateTime.now(),
      );

      print('Created optimistic user msg: ${stopwatch.elapsed.inMilliseconds}ms');
      stopwatch.reset();

      final tempAiMsg = ChatMessage(
        id: aiMsgId,
        userId: userId,
        role: MessageRole.ai,
        content: '',
        timestamp: DateTime.now(),
        isOptimistic: true,
      );

      print('Created temp AI msg: ${stopwatch.elapsed.inMilliseconds}ms');
      stopwatch.reset();

      // Update state optimistically
      state = [...state.where((msg) => !msg.isOptimistic), userMsg, tempAiMsg];

      print('Updated state optimistically: ${stopwatch.elapsed.inMilliseconds}ms');
      stopwatch.reset();

      // Initialize GPT service
      final gptService = GPTService();
      if (!gptService.isInitialized) {
        await gptService.initialize();
      }

      print('Initialized/skipped GPT service: ${stopwatch.elapsed.inMilliseconds}ms');
      stopwatch.reset();

      // Start Firestore transaction
      final batch = _firestore.batch();

      // Add user message
      batch.set(
          _firestore.collection('users').doc(userId).collection('messages').doc(userMsgId),
          {
            'userId': userId,
            'role': 'user',
            'content': message,
            'timestamp': FieldValue.serverTimestamp(),
          }
      );

      print('Firebase transaction batched: ${stopwatch.elapsed.inMilliseconds}ms');
      stopwatch.reset();

      // Update user document with message count (without await .get())
      final now = await getServerTimeReference();
      final todayMidnight = DateTime(now.year, now.month, now.day);

      final userRef = _firestore.collection('users').doc(userId);
      final lastResetField = 'lastMessageCountReset';

      // Use transaction-free safe merge logic
      batch.set(userRef, {
        'lastActive': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'lastMessagePreview': message,
        'dailyMessageCount': FieldValue.increment(1),
        lastResetField: FieldValue.serverTimestamp(), // always updates, acceptable if you're not doing precise reset logic here
      }, SetOptions(merge: true));

      print('Created batch for user doc: ${stopwatch.elapsed.inMilliseconds}ms');
      stopwatch.reset();

      // 🚀 Fire off batch.commit() but don't await yet
      final batchFuture = batch.commit();

      // Start personal details extraction in parallel
      final personalDetailsFuture = _extractAndSavePersonalDetails(userId, message);

      // 🧠 GPT streaming while Firestore is committing in background
      String fullResponse = '';
      await for (final chunk in gptService.getResponseStream(
        prompt: message,
        messageHistory: state.length > 5 ? state.sublist(state.length - 5) : state,
        userId: userId,
      )) {
        fullResponse += chunk;

        // Update state immediately on every chunk
        state = state.map((msg) =>
        msg.id == aiMsgId ? msg.copyWith(content: fullResponse) : msg
        ).toList();
      }

      print('Got gpt response in chunks: ${stopwatch.elapsed.inMilliseconds}ms');
      stopwatch.reset();

      // ✅ Finalize GPT message (you can parallelize this too if you're feeling spicy)
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('messages')
          .doc(aiMsgId)
          .set({
        'userId': userId,
        'role': 'ai',
        'content': fullResponse,
        'timestamp': FieldValue.serverTimestamp(),
      });

      print('Finalized AI response: ${stopwatch.elapsed.inMilliseconds}ms');
      stopwatch.reset();

      // ✅ Now wait for batch.commit() if it hasn't already finished
      await batchFuture;

      // Wait for personal details extraction to complete (if not already)
      await personalDetailsFuture;

      print('Batch committed (awaited after GPT): ${stopwatch.elapsed.inMilliseconds}ms');
      stopwatch.reset();

      // Update state
      state = state.map((msg) =>
      msg.id == aiMsgId ? msg.copyWith(isOptimistic: false) : msg
      ).toList();

      print('Added ai msg to list: ${stopwatch.elapsed.inMilliseconds}ms');
      stopwatch.reset();

    } catch (e) {
      state = state.where((msg) => !msg.isOptimistic).toList();
      rethrow;
    }
  }

  Future<void> _extractAndSavePersonalDetails(String userId, String message) async {
    try {
      final gptService = GPTService();
      final details = await gptService.extractPersonalDetails(message);

      if (details != null && details.isNotEmpty) {
        final detail = details.entries.first;
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('details')
            .add({
          'category': detail.key,
          'detail': detail.value,
          'timestamp': FieldValue.serverTimestamp(),
        });

        // Clear cache to force refresh on next message
        final gptService = GPTService();
        gptService.forceRefreshCache();
      }
    } catch (e) {
      print('Error extracting/saving personal details: $e');
      // Fail silently - this shouldn't affect the main message flow
    }
  }

  Future<int> getMessageCountToday(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      final serverTime = await getServerTimeReference();

      final data = doc.data();
      if (data == null) return 0;

      final count = data['dailyMessageCount'] ?? 0;
      final Timestamp? lastResetTs = data['lastMessageCountReset'];
      final lastReset = lastResetTs?.toDate();
      final todayMidnight = DateTime(serverTime.year, serverTime.month, serverTime.day);

      if (lastReset == null || lastReset.isBefore(todayMidnight)) {
        return 0;
      }

      return count;
    } catch (e) {
      print('Error getting message count from user doc: $e');
      return 0;
    }
  }
}