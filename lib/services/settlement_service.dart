import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';
import '../models/settlement_model.dart';
import 'app_notification_service.dart';
import 'cloudinary_service.dart';

class SettlementService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final CloudinaryService _cloudinary = CloudinaryService();

  Future<String> recordSettlement({
    required String groupId,
    required String toUserUid,
    required double amount,
    String? note,
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) throw Exception('User not logged in');

    final settlement = Settlement(
      id: '', // Will be set by Firestore
      groupId: groupId,
      fromUserUid: currentUser.uid,
      toUserUid: toUserUid,
      amount: amount,
      settledAt: DateTime.now(),
      note: note,
      isSettled: true,
    );

    try {
      final docRef = await _firestore
          .collection('groups')
          .doc(groupId)
          .collection('settlements')
          .add(settlement.toMap());

      await AppNotificationService.writeNotification(
        toUserUid,
        type: 'settlement',
        title: 'Payment received',
        body: '${currentUser.displayName ?? "Someone"} settled ₹${amount.toStringAsFixed(2)}',
        relatedId: groupId,
        actionUserName: currentUser.displayName,
        amount: amount,
      );

      return docRef.id;
    } catch (e) {
      throw Exception('Failed to record settlement: $e');
    }
  }

  Future<String?> addProofToSettlement({
    required String groupId,
    required String settlementId,
    required File proofImage,
    required Function(double) onProgress,
  }) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) throw Exception('User not logged in');

      // Upload to Cloudinary
      final url = await _cloudinary.uploadSettlementProof(
        proofImage,
        onProgress: onProgress,
      );

      if (url == null) {
        throw Exception('Failed to upload.');
      }

      // Update settlement with proof URL
      await _firestore
          .collection('groups')
          .doc(groupId)
          .collection('settlements')
          .doc(settlementId)
          .update({
            'proofUrl': url,
          });

      return url;
    } catch (e) {
      throw Exception('Failed to upload proof: $e');
    }
  }

  Stream<List<Settlement>> getGroupSettlements(String groupId, {int? limit}) {
    Query<Map<String, dynamic>> query = _firestore
        .collection('groups')
        .doc(groupId)
        .collection('settlements')
        .orderBy('settledAt', descending: true);

    if (limit != null) {
      query = query.limit(limit);
    }

    return query.snapshots().map((snapshot) => snapshot.docs
        .map((doc) => Settlement.fromMap(doc.data() as Map<String, dynamic>, doc.id))
        .toList());
  }

  Stream<List<Settlement>> getUserSettlements(String groupId, {int? limit}) {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return Stream.value([]);

    Query<Map<String, dynamic>> query = _firestore
        .collection('groups')
        .doc(groupId)
        .collection('settlements')
        .where('fromUserUid', isEqualTo: userId)
        .orderBy('settledAt', descending: true);

    if (limit != null) {
      query = query.limit(limit);
    }

    return query.snapshots().map((snapshot) => snapshot.docs
        .map((doc) => Settlement.fromMap(doc.data() as Map<String, dynamic>, doc.id))
        .toList());
  }

  Future<void> updateSettlementNote({
    required String groupId,
    required String settlementId,
    required String note,
  }) async {
    try {
      await _firestore
          .collection('groups')
          .doc(groupId)
          .collection('settlements')
          .doc(settlementId)
          .update({
            'note': note,
          });
    } catch (e) {
      throw Exception('Failed to update note: $e');
    }
  }

  Future<void> deleteSettlement({
    required String groupId,
    required String settlementId,
  }) async {
    try {
      await _firestore
          .collection('groups')
          .doc(groupId)
          .collection('settlements')
          .doc(settlementId)
          .delete();
    } catch (e) {
      throw Exception('Failed to delete settlement: $e');
    }
  }
}
