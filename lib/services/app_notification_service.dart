import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/app_notification.dart';

class AppNotificationService {
  static final AppNotificationService _instance = AppNotificationService._internal();

  factory AppNotificationService() {
    return _instance;
  }

  AppNotificationService._internal();

  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  Stream<List<AppNotification>> getNotifications(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => AppNotification.fromFirestore(doc)).toList());
  }

  Future<void> markAllRead(String uid) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(uid)
          .collection('notifications')
          .where('isRead', isEqualTo: false)
          .get();

      for (var doc in snapshot.docs) {
        await doc.reference.update({'isRead': true});
      }
    } catch (e) {
      debugPrint('Error marking all notifications as read: $e');
    }
  }

  Future<void> markRead(String uid, String notifId) async {
    try {
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('notifications')
          .doc(notifId)
          .update({'isRead': true});
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
    }
  }

  Future<int> getUnreadCount(String uid) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(uid)
          .collection('notifications')
          .where('isRead', isEqualTo: false)
          .count()
          .get();
      return snapshot.count;
    } catch (e) {
      debugPrint('Error getting unread count: $e');
      return 0;
    }
  }

  static Future<void> writeNotification(
    String toUid, {
    required String type,
    required String title,
    required String body,
    String? relatedId,
    String? actionUserName,
    double? amount,
  }) async {
    try {
      final firestore = FirebaseFirestore.instance;
      await firestore
          .collection('users')
          .doc(toUid)
          .collection('notifications')
          .add({
        'type': type,
        'title': title,
        'body': body,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
        'relatedId': relatedId,
        'actionUserName': actionUserName,
        'amount': amount,
      });
    } catch (e) {
      debugPrint('Error writing notification: $e');
    }
  }
}
