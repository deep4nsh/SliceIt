import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import '../models/settlement_model.dart';

class SettlementService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

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

      return docRef.id;
    } catch (e) {
      throw Exception('Failed to record settlement: $e');
    }
  }

  Future<String?> addProofToSettlement({
    required String groupId,
    required String settlementId,
    required File proofImage,
  }) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) throw Exception('User not logged in');

      final fileName = 'settlement_proof_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = _storage
          .ref()
          .child('settlements')
          .child(groupId)
          .child(settlementId)
          .child(fileName);

      await ref.putFile(proofImage);
      final url = await ref.getDownloadURL();

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

  Stream<List<Settlement>> getGroupSettlements(String groupId) {
    return _firestore
        .collection('groups')
        .doc(groupId)
        .collection('settlements')
        .orderBy('settledAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Settlement.fromMap(doc.data(), doc.id))
            .toList());
  }

  Stream<List<Settlement>> getUserSettlements(String groupId) {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return Stream.value([]);

    return _firestore
        .collection('groups')
        .doc(groupId)
        .collection('settlements')
        .where('fromUserUid', isEqualTo: userId)
        .orderBy('settledAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Settlement.fromMap(doc.data(), doc.id))
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
