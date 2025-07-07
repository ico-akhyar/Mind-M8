import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class NotificationService {
  static final _firebaseMessaging = FirebaseMessaging.instance;
  static final _notifications = FlutterLocalNotificationsPlugin();

  static final _androidChannel = const AndroidNotificationDetails(
    'high_importance_channel',
    'Important Notifications',
    importance: Importance.max,
    priority: Priority.high,
    showWhen: true,
  );

  static final _iosChannel = const DarwinNotificationDetails(
    presentAlert: true,
    presentBadge: true,
    presentSound: true,
  );

  // Initialize the notification service
  static Future<void> init() async {
    // Request permissions
    await _firebaseMessaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    // Initialize local notifications
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    await _notifications.initialize(
      const InitializationSettings(android: android, iOS: ios),
      onDidReceiveNotificationResponse: (details) {
        final payload = details.payload;
        if (payload != null) {
          try {
            final data = json.decode(payload) as Map<String, dynamic>;
            if (data['type'] == 'proactive') {
              _handleProactiveNotification(data);
            }
          } catch (e) {
            debugPrint('Error parsing notification payload: $e');
          }
        }
      },
    );

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(showForegroundNotification);

    // Handle background messages
    FirebaseMessaging.onBackgroundMessage(_handleBackgroundMessage);
  }

  // Setup for interacted messages
  static Future<void> setupInteractedMessage() async {
    // Handle notification when app is opened from terminated state
    RemoteMessage? initialMessage = await _firebaseMessaging
        .getInitialMessage();
    if (initialMessage != null) {
      _handleNotification(initialMessage);
    }

    // Handle notification when app is in background
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotification);
  }

  // Get device token
  static Future<String?> get deviceToken async {
    return await _firebaseMessaging.getToken();
  }

  // Handle notification tap
  static void _handleNotification(RemoteMessage message) {
    if (message.data['type'] == 'proactive') {
      final userId = message.data['userId'];
      final content = message.data['message'];
      if (userId != null && content != null) {
        _handleProactiveNotification(message.data);
      }
    }
  }

  // Handle proactive notifications
  static void _handleProactiveNotification(Map<String, dynamic> data) {
    final userId = data['userId'];
    final message = data['message'];

    if (userId != null && message != null) {
      debugPrint(
          'Proactive notification tapped - User: $userId, Message: $message');
      // In a real app, you would navigate to the chat screen here
    }
  }

  // Show foreground notification
  static Future<void> showForegroundNotification(RemoteMessage message) async {
    final notification = message.notification;
    final data = message.data;

    if (notification != null) {
      await _notifications.show(
        message.hashCode,
        notification.title ?? 'Mind M8',
        notification.body ?? 'New message',
        NotificationDetails(
          android: _androidChannel,
          iOS: _iosChannel,
        ),
        payload: json.encode(data),
      );
    }
  }

  // Handle background messages
  static Future<void> _handleBackgroundMessage(RemoteMessage message) async {
    if (message.notification != null) {
      await showForegroundNotification(message);
    }

    // Handle data payload
    if (message.data.isNotEmpty) {
      debugPrint('Background message data: ${message.data}');
    }
  }

  // Helper to show local notification directly
  static Future<void> showLocalNotification({
    required String title,
    required String body,
    Map<String, dynamic>? payload,
  }) async {
    await _notifications.show(
      DateTime
          .now()
          .millisecondsSinceEpoch,
      title,
      body,
      NotificationDetails(
        android: _androidChannel,
        iOS: _iosChannel,
      ),
      payload: payload != null ? json.encode(payload) : null,
    );
  }


// Used to send proactive push via your Node.js backend
  static Future<void> sendProactiveNotificationpost({
    required String token,
    required String message,
  }) async {
    final url = Uri.parse(
        'https://mindm8-push-backend.vercel.app/api/sendPush');

    final payload = {
      'token': token,
      'title': 'MindM8 💭',
      'body': message,
    };

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      debugPrint('Notification API Response: ${response.body}');
    } catch (e) {
      debugPrint('Error sending notification: $e');
    }
  }
}