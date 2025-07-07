import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../services/notification_service.dart';
import '../services/gpt_service.dart';
import '../models/journal_entry.dart';
import 'package:flutter/foundation.dart';
import '../providers/notification_prefs_provider.dart';
import '../providers/server_time_provider.dart';

final proactiveProvider = StateNotifierProvider<ProactiveNotifier, void>((ref) {
  return ProactiveNotifier(ref);
});

class ProactiveNotifier extends StateNotifier<void> {
  final Ref ref;

  ProactiveNotifier(this.ref) : super(null);

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  Future<void> checkForProactiveMessage() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final prefs = ref.read(notificationPrefsProvider);

      if (prefs.mode == 0) return;
      if (prefs.mode != 1) return;

      final messages = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .limit(5)
          .get();

      if (messages.docs.isEmpty) return;

      final lastMessages = messages.docs.map((doc) {
        final data = doc.data();
        return ChatMessage(
          id: doc.id,
          userId: data['userId'],
          role: data['role'] == 'user' ? MessageRole.user : MessageRole.ai,
          content: data['content'],
          timestamp: (data['timestamp'] as Timestamp).toDate(),
        );
      }).toList();

      if (prefs.mode == 1) {
        final gptService = GPTService();
        final response = await gptService.generateProactiveMessage(
            lastMessages);

        if (response.isEmpty || response == '[NOACTION]') return;

        await _sendProactiveNotification(response, user.uid);
      }
    } catch (e) {
      debugPrint('Error in checkForProactiveMessage: $e');
    }
  }

  Future<void> _sendProactiveNotification(String message, String userId) async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      final fcmToken = userDoc.get('fcmToken') as String?;
      if (fcmToken == null) return;

      await FirebaseFirestore.instance
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

      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .update({
        'lastProactive': FieldValue.serverTimestamp(),
      });

      await NotificationService.sendProactiveNotificationpost(
        token: fcmToken,
        message: message,
      );
    } catch (e, stack) {
      debugPrint('Error: $e\n$stack');
    }
  }

  Future<void> scheduleProactiveCheck() async {
    print("shedule");
    final user = _auth.currentUser;
    if (user == null) {
      print("no user");
      return;
    }

    try {
      final prefs = ref.read(notificationPrefsProvider);

      if (prefs.mode != 1) {  print("pref mode not matched ${prefs.mode}"); return;}
      if (prefs.mode == 1) { print("sheduling");
        final randomDelay = Duration(minutes: 15 + (DateTime
            .now()
            .millisecond % 45));
        await Future.delayed(randomDelay);
        if (_auth.currentUser != null) {
          await checkForProactiveMessage();
        }
        print("sheduled");
      }
    } catch (e) {
      debugPrint('Error in scheduleProactiveCheck: $e');
    }
  }

  Future<bool> checkForMissedProactiveNotification() async {
    final user = _auth.currentUser;
    if (user == null) return false;

    try {
      final userDoc = await _firestore
          .collection('users')
          .doc(user.uid)
          .get();

      if (!userDoc.exists) return false;

      final userData = userDoc.data() as Map<String, dynamic>?;
      final prefs = ref.read(notificationPrefsProvider);

      if(prefs.mode != 1) {  print("pref mode not matched ${prefs.mode}"); return false;}

      if (prefs.mode == 1) {
        final bool shouldSendNotification;
        final serverTime = await _getServerTime();

        if (userData == null || !userData.containsKey('lastProactive')) {
          shouldSendNotification = true;
        } else {
          final lastProactive = userDoc.get('lastProactive') as Timestamp?;
          shouldSendNotification = lastProactive == null ||
              serverTime.difference(lastProactive.toDate()).inMinutes > 120;
        }

        if (shouldSendNotification) {
          await checkForProactiveMessage();
          return true;
        }
      }
      return false;
    } catch (e) {
      debugPrint('Error in checkForMissedProactiveNotification: $e');
      return false;
    }
  }

  Future<DateTime> _getServerTime() async {
    final offset = ref.read(serverTimeOffsetProvider);
    return DateTime.now().add(offset);
  }
}