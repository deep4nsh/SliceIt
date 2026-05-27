import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:sliceit/main.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();

  factory NotificationService() {
    return _instance;
  }

  NotificationService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  RemoteMessage? _lastNotification;

  Future<void> initializeNotifications() async {
    try {
      debugPrint('🔔 Initializing Firebase Cloud Messaging...');

      // Request notification permissions (iOS)
      NotificationSettings settings = await _firebaseMessaging.requestPermission(
        alert: true,
        announcement: true,
        badge: true,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      debugPrint('🔔 Permission status: ${settings.authorizationStatus}');

      // Get and save FCM token
      String? token = await _firebaseMessaging.getToken();
      debugPrint('🔔 FCM Token: $token');

      if (token == null) {
        debugPrint('⚠️  WARNING: FCM Token is null!');
      } else {
        // Save FCM token to Firestore
        await _saveFCMToken(token);
      }

    // Handle foreground messages
    debugPrint('🔔 Setting up foreground message listener...');
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('🔔 Foreground message received!');
      debugPrint('🔔 Message ID: ${message.messageId}');
      debugPrint('🔔 Message data: ${message.data}');
      debugPrint('🔔 Notification: ${message.notification?.title} - ${message.notification?.body}');

      _lastNotification = message;
      _showNotificationDialog(message);
    }, onError: (error) {
      debugPrint('❌ Error in foreground message listener: $error');
    });

    // Handle background message
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Handle notification when app is opened from terminated state
    FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        debugPrint('🔔 App opened from terminated state via notification: ${message.notification?.title}');
        _lastNotification = message;
        _handleNotificationTap(message);
        // Show notification info after a brief delay to ensure UI is ready
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showNotificationInfoDialog(message);
        });
      } else if (_lastNotification != null) {
        debugPrint('🔔 Showing cached notification');
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showNotificationInfoDialog(_lastNotification!);
        });
      } else {
        debugPrint('🔔 App opened normally (no initial notification)');
      }
    });

    // Handle notification when app is opened from background
    debugPrint('🔔 Setting up message opened app listener...');
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('🔔 Notification tapped: ${message.notification?.title}');
      _handleNotificationTap(message);
    });

    debugPrint('✅ Firebase Cloud Messaging initialized successfully!');
    } catch (e) {
      debugPrint('❌ Error initializing FCM: $e');
    }
  }

  void _showNotificationDialog(RemoteMessage message) {
    final context = navigatorKey.currentContext;
    if (context != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (message.notification?.title != null)
                Text(
                  message.notification!.title!,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              if (message.notification?.body != null)
                Text(message.notification!.body!),
            ],
          ),
          duration: const Duration(seconds: 5),
        ),
      );
    }
    debugPrint('Showing notification: ${message.notification?.title}');
  }

  void _handleNotificationTap(RemoteMessage message) {
    // Handle navigation based on notification data
    final data = message.data;
    debugPrint('Handling notification tap with data: $data');
  }

  void _showNotificationInfoDialog(RemoteMessage message) {
    final context = navigatorKey.currentContext;
    if (context != null && context.mounted) {
      showDialog(
        context: context,
        builder: (BuildContext context) => AlertDialog(
          title: Text(message.notification?.title ?? 'Notification'),
          content: Text(message.notification?.body ?? 'No message body'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  Future<String?> getFCMToken() async {
    return await _firebaseMessaging.getToken();
  }

  Future<void> _saveFCMToken(String token) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .set({
              'fcmToken': token,
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
        debugPrint('✅ FCM token saved to Firestore');
      }
    } catch (e) {
      debugPrint('❌ Error saving FCM token: $e');
    }
  }
}

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('🔔 Background message handler triggered!');
  debugPrint('🔔 Message ID: ${message.messageId}');
  debugPrint('🔔 Message data: ${message.data}');
  debugPrint('🔔 Notification: ${message.notification?.title} - ${message.notification?.body}');
}
