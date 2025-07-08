import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/journal_entry.dart';
import '../services/gpt_service.dart';
import '../providers/auth_provider.dart';
import 'gpt_provider.dart';

final roastProvider = StateNotifierProvider<RoastNotifier, List<ChatMessage>>((ref) {
  return RoastNotifier(ref);
});

class RoastNotifier extends StateNotifier<List<ChatMessage>> {
  final Ref ref;

  RoastNotifier(this.ref) : super([]);

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  int _messageCountToday = 0;
  DateTime? _lastResetDate;
  GPTService? _gptService;
  String? _currentStreamingMessageId;
  bool _isTyping = false;
  bool get canRoastMore => _messageCountToday < 5;
  int get remainingRoastsToday => 5 - _messageCountToday;

  bool get isTyping => _isTyping;

  bool get hasEnoughData {
    _ensureGptServiceInitialized();
    if (!_gptService!.isInitialized) return false;
    final personalDetails = _gptService!.cachedPersonalDetails ?? '';
    final detailsList = personalDetails.split('\n').where((line) =>
    line
        .trim()
        .isNotEmpty).toList();
    return detailsList.length >= 3;
  }

  Future<void> initializeRoast() async {
    _ensureGptServiceInitialized();
    await Future.wait([
      _gptService!.initialize(),
      _checkDailyReset(),
      _loadRoastMessages(),
    ]);
  }

  void _ensureGptServiceInitialized() {
    _gptService ??= ref.read(gptServiceProvider);
  }

  void _updateStreamingMessage(String id, String content) {
    state =
        state
            .map((msg) => msg.id == id ? msg.copyWith(content: content) : msg)
            .toList();
  }

  String? _userId;

  void _ensureUserIdInitialized() {
    _userId ??= ref
        .read(authProvider)
        ?.uid;
  }


  Future<void> _checkDailyReset() async {
    _ensureUserIdInitialized();
    if (_userId == null) return;

    final tempDoc = _firestore.collection('users').doc(_userId!)
        .collection('temp_server_time').doc('check');

    await tempDoc.set({'timestamp': FieldValue.serverTimestamp()});
    final snapshot = await tempDoc.get();
    final serverTime = (snapshot.data()?['timestamp'] as Timestamp).toDate();

    await tempDoc.delete();

    final todayMidnight = DateTime(
        serverTime.year, serverTime.month, serverTime.day);

    final userDoc = await _firestore.collection('users').doc(_userId!).get();
    final data = userDoc.data();
    if (data == null) return;

    final Timestamp? lastResetTs = data['lastRoastReset'];
    final lastReset = lastResetTs?.toDate();
    final count = data['dailyRoastCount'] ?? 0;

    if (lastReset == null || lastReset.isBefore(todayMidnight)) {
      await _firestore.collection('users').doc(_userId!).update({
        'lastRoastReset': FieldValue.serverTimestamp(),
        'dailyRoastCount': 0,
      });
      _messageCountToday = 0;
      _lastResetDate = DateTime.now();
    } else {
      _messageCountToday = count;
      _lastResetDate = lastReset;
    }
  }

  Future<void> _loadRoastMessages() async {
    _ensureUserIdInitialized();
    if (_userId == null) return;

    final snapshot = await _firestore
        .collection('users')
        .doc(_userId!)
        .collection('roast_messages')
        .orderBy('timestamp', descending: false)
        .get();

    state = snapshot.docs.map((doc) => ChatMessage.fromFirestore(doc)).toList();
  }

  Future<void> deleteMessage(String messageId, String userId) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('roast_messages')
          .doc(messageId)
          .delete();

      state = state.where((message) => message.id != messageId).toList();
    } catch (e) {
      throw Exception('Failed to delete message: $e');
    }
  }

  Future<void> sendRoastBack(String message) async {
    if (_messageCountToday >= 5) return;

    _ensureUserIdInitialized();
    if (_userId == null) return;

    final optimisticMessage = ChatMessage(
      userId: _userId!,
      role: MessageRole.user,
      content: message,
      timestamp: DateTime.now(),
      isOptimistic: true,
    );
    state = [...state, optimisticMessage];

    await _firestore
        .collection('users')
        .doc(_userId!)
        .collection('roast_messages')
        .add({
      'userId': _userId!,
      'role': 'user',
      'content': message,
      'timestamp': FieldValue.serverTimestamp(),
    });

    await _firestore.collection('users').doc(_userId!).update({
      'dailyRoastCount': FieldValue.increment(1),
    });
    _messageCountToday++;
  }

  Future<void> sendAiRoast() async {
    if (_messageCountToday >= 5) return;

    _ensureUserIdInitialized();
    if (_userId == null) return;

    _ensureGptServiceInitialized();
    if (!_gptService!.isInitialized) {
      await _gptService!.initialize();
    }

    final personalization = _gptService!.cachedPersonalizationString ?? '';
    final personalDetails = _gptService!.cachedPersonalDetails ?? '';
    final detailsCount = personalDetails
        .split('\n')
        .where((line) =>
    line
        .trim()
        .isNotEmpty)
        .length;

    if (detailsCount < 3) {
      state = [...state, ChatMessage(
        userId: _userId!,
        role: MessageRole.ai,
        content: "Oh please, you're not even worth roasting! 😴\nActually, I don't know enough about you to roast you properly! "
            "Tell me more about yourself first! 😅",
        timestamp: DateTime.now(),
      )
      ];
      return;
    }

    final aiMsgId = _firestore
        .collection('users/$_userId/roast_messages')
        .doc()
        .id;
    final tempAiMsg = ChatMessage(
      id: aiMsgId,
      userId: _userId!,
      role: MessageRole.ai,
      content: '',
      timestamp: DateTime.now(),
      isOptimistic: true,
    );

    state = [...state, tempAiMsg];
    _currentStreamingMessageId = aiMsgId;
    _isTyping = true;

    try {
      String fullResponse = '';
      String buffer = '';
      final timer = Stopwatch()
        ..start();

      await for (final chunk in _gptService!.getRoastStream(
        prompt: '''
You're now in **ROAST MODE** – act like a savage, funny Gen Z friend who's got no filter 😈  
Your job: roast the user HARD but keep it playful (don't be genuinely mean).  
If the user's message is in **Roman Urdu**, reply in **Roman Urdu** too (same energy, same heat 🔥).  

**Rules:**
1. Roast must be savage, witty, and based on user's personal info.
2. Be funny, sarcastic, and Gen Z-ish. No fake kindness.
3. MAX 3 sentences only. Short and spicy.
4. Use emojis + Gen Z/Roman Urdu slang (depending on language).
5. You can also go somewhat off topic if details are insufficient maybe some personal like relationship or job etc.
6. End every roast with something like: *"Roast me back if you dare 😈"* But not same to same this line.

---  
**User Info:**  
$personalization  
$personalDetails  

---  
**Previous Roasts:**  
${state.map((msg) => '${msg.role == MessageRole.user ? "User" : "You"}: ${msg
            .content}').join('\n')}

---  
**Now roast the user based on their latest message. Make it personal, sarcastic, and short:**  
''',
      )) {
        buffer += chunk;
        fullResponse += chunk;

        if (timer.elapsedMilliseconds >= 120) {
          _updateStreamingMessage(aiMsgId, fullResponse);
          buffer = '';
          timer.reset();
        }
      }

      // Final flush (in case buffer is left)
      if (buffer.isNotEmpty) {
        _updateStreamingMessage(aiMsgId, fullResponse);
      }

      await _firestore
          .collection('users')
          .doc(_userId!)
          .collection('roast_messages')
          .doc(aiMsgId)
          .set({
        'userId': _userId!,
        'role': 'ai',
        'content': fullResponse,
        'timestamp': FieldValue.serverTimestamp(),
      });

      state = state.map((msg) =>
      msg.id == aiMsgId ? msg.copyWith(
          isOptimistic: false) : msg).toList();
    } catch (e) {
      state = state.where((msg) => msg.id != aiMsgId).toList();
      rethrow;
    } finally {
      _currentStreamingMessageId = null;
      _isTyping = false;
    }
  }
}

