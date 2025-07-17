import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import '../services/gpt_service.dart';
import '../models/journal_entry.dart';
import 'package:flutter/foundation.dart';
import '../providers/notification_prefs_provider.dart';
import 'package:firebase_core/firebase_core.dart';
import '../providers/server_time_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import '../models/notification_preferences.dart';
import 'package:workmanager/workmanager.dart';

final proactiveProvider = StateNotifierProvider<ProactiveNotifier, void>((ref) {
  return ProactiveNotifier.withRef(ref);
});

@pragma('vm:entry-point')
Future<void> proactiveNotificationCallback() async {
  debugPrint('🟡 [BACKGROUND TASK STARTED]');
  try {
    WidgetsFlutterBinding.ensureInitialized();

    // Initialize Firebase if needed
    try {
      await Firebase.initializeApp();
      debugPrint('🟡 Firebase initialized in background');
    } catch (e) {
      debugPrint('🟡 Firebase already initialized');
    }

    final prefs = await SharedPreferences.getInstance();
    debugPrint('SharedPreferences loaded');

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      debugPrint('No user logged in');
      return;
    }

    // Get notification preferences
    final prefsJson = prefs.getString('notification_preferences');
    if (prefsJson == null) {
      debugPrint('No notification preferences found');
      return;
    }

    final prefsMap = json.decode(prefsJson) as Map<String, dynamic>;
    final notificationPrefs = NotificationPreferences.fromMap(prefsMap);

    if (notificationPrefs.mode != 1) {
      debugPrint('Proactive mode is disabled');
      return;
    }

    // Only proceed if the app has been in background for at least 30 minutes
    final lastBackgroundTime = prefs.getInt('lastBackgroundTime');
    if (lastBackgroundTime != null) {
      final backgroundDuration = DateTime.now().difference(
          DateTime.fromMillisecondsSinceEpoch(lastBackgroundTime));
      if (backgroundDuration.inMinutes < 30) {
        debugPrint('App hasn\'t been in background long enough');
        return;
      }
    }

    // Execute the actual proactive check
    final notifier = ProactiveNotifier.manual(notificationPrefs);
    await notifier.checkForMissedProactiveNotification();

    debugPrint('=== PROACTIVE CALLBACK COMPLETED ===');
  } catch (e, stack) {
    debugPrint('Error in proactiveNotificationCallback: $e\n$stack');
  }
}

class ProactiveNotifier extends StateNotifier<void> {
  final Ref? ref;
  final NotificationPreferences? injectedPrefs;
  static final _notifications = FlutterLocalNotificationsPlugin();

  // Improved flag system
  bool _isCheckingForMissed = false;
  DateTime? _lastCheckTime;
  DateTime? _lastProactiveSentTime;
  final Random _random = Random();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  ProactiveNotifier.withRef(this.ref)
      : injectedPrefs = null,
        super(null) {
    _initNotifications();
  }

  ProactiveNotifier.manual(this.injectedPrefs)
      : ref = null,
        super(null) {
    _initNotifications();
  }

  NotificationPreferences get prefs {
    if (injectedPrefs != null) return injectedPrefs!;
    return ref!.read(notificationPrefsProvider);
  }

  Future<void> _initNotifications() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    await _notifications.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );
  }

  Future<void> _executeProactiveCheck(String userId) async {
    try {
      debugPrint('Executing proactive check for user: $userId');

      if (prefs.mode != 1) {
        debugPrint('Proactive mode is disabled');
        return;
      }

      // Initialize GPTService with retry
      int attempts = 0;
      bool initialized = false;

      while (!initialized && attempts < 3) {
        try {
          await GPTService().preInitialize();
          initialized = true;
        } catch (e) {
          debugPrint('Initialization attempt ${attempts + 1} failed: $e');
          await Future.delayed(Duration(seconds: 2));
          attempts++;
        }
      }

      if (!initialized) {
        throw Exception('Failed to initialize GPTService');
      }

      final messages = await _firestore
          .collection('users')
          .doc(userId)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .limit(5)
          .get();

      if (messages.docs.isEmpty) {
        debugPrint('No messages found for user');
        return;
      }

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

      final gptService = GPTService();
      final response = await gptService.generateProactiveMessage(lastMessages);

      debugPrint('GPT response: $response');

      if (response.isEmpty || response == '[NOACTION]') {
        debugPrint('No proactive message generated');
        return;
      }

      await sendProactiveNotification(response, userId);
      _lastProactiveSentTime = DateTime.now();
    } catch (e) {
      debugPrint('Error in _executeProactiveCheck: $e');
      // Auto-retry after delay if failed
      await Future.delayed(Duration(minutes: 5));
      rethrow;
    }
  }

  Future<void> sendProactiveNotification(String message, String userId) async {
    try {
      debugPrint('Attempting to send proactive message to Firestore');

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
      debugPrint('Firestore write successful: ${docRef.id}');

      await _firestore.collection('users').doc(userId).update({
        'lastProactive': FieldValue.serverTimestamp(),
      });

      // Send local notification
      const android = AndroidNotificationDetails(
        'proactive_channel',
        'Proactive Messages',
        importance: Importance.high,
        priority: Priority.high,
        enableVibration: true,
      );

      await _notifications.show(
        0,
        'MindM8 💭',
        message,
        const NotificationDetails(
          android: android,
          iOS: DarwinNotificationDetails(),
        ),
      );
      debugPrint('Local notification shown');

    } catch (e, stack) {
      debugPrint('Error in _sendProactiveNotification: $e\n$stack');
    }
  }

  Future<void> appWentToBackground() async {
    debugPrint('🟢 [1] APP WENT TO BACKGROUND');

    if (prefs.mode != 1) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    final sharedPrefs = await SharedPreferences.getInstance();
    await sharedPrefs.setInt('lastBackgroundTime', now);

    debugPrint('🟢 [2] Background time saved, no immediate task scheduled');
  }

  Future<void> appCameToForeground() async {
    final sharedPrefs = await SharedPreferences.getInstance();
    await sharedPrefs.remove('lastBackgroundTime');

    // Cancel both tasks
    await Workmanager().cancelByTag("immediateProactiveCheck");
    await Workmanager().cancelByTag("periodicProactiveCheck");
  }

  Future<bool> checkForMissedProactiveNotification() async {
    // Cooldown check - skip if we checked recently
    if (_isCheckingForMissed ||
        (_lastCheckTime != null &&
            DateTime.now().difference(_lastCheckTime!) < Duration(minutes: 10))) {
      debugPrint('Skipping check - too recent');
      return false;
    }

    _isCheckingForMissed = true;
    _lastCheckTime = DateTime.now();

    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (!userDoc.exists) return false;

      if (prefs.mode != 1) return false;

      final serverTime = await _getServerTime();
      final todayMidnight = DateTime(serverTime.year, serverTime.month, serverTime.day);

      final lastProactive = userDoc.data()?['lastProactive'] as Timestamp?;

      // New day check (always send)
      if (lastProactive == null || lastProactive.toDate().isBefore(todayMidnight)) {
        debugPrint('New day - sending proactive message');
        await _executeProactiveCheck(user.uid);
        return true;
      }

      // Randomized interval check (60-240 minutes)
      final minutesSinceLast = serverTime.difference(lastProactive.toDate()).inMinutes;
      final requiredWait = _getRandomInterval();
      debugPrint('Minutes since last: $minutesSinceLast (needs $requiredWait)');

      if (minutesSinceLast >= requiredWait) {
        debugPrint('Random interval reached - sending proactive message');
        await _executeProactiveCheck(user.uid);
        return true;
      }

      return false;
    } catch (e) {
      debugPrint('Error in checkForMissed: $e');
      return false;
    } finally {
      _isCheckingForMissed = false;
    }
  }

  int _getRandomInterval() {
    return 60 + _random.nextInt(180); // 60-240 minute range
  }

  Future<void> updateNotificationPreferences() async {
    if (prefs.mode != 1) {
      final sharedPrefs = await SharedPreferences.getInstance();
      await sharedPrefs.remove('lastBackgroundTime');
      await Workmanager().cancelByTag("immediateProactiveCheck");
    }
  }

  Future<DateTime> _getServerTime() async {
    if (ref == null) return DateTime.now();
    final offset = ref!.read(serverTimeOffsetProvider);
    return DateTime.now().add(offset);
  }
}