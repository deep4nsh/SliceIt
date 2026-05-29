import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/friend_model.dart';

class FriendService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Search for users by email
  Future<List<Friend>> searchUsers(String emailQuery) async {
    if (emailQuery.isEmpty) return [];

    final querySnapshot = await _firestore
        .collection('users')
        .where('email', isGreaterThanOrEqualTo: emailQuery)
        .where('email', isLessThan: '${emailQuery}z')
        .limit(10)
        .get();

    final currentUserEmail = _auth.currentUser?.email;

    return querySnapshot.docs
        .map((doc) => Friend.fromMap(doc.data()))
        .where((friend) => friend.email != currentUserEmail)
        .toList();
  }

  // Add a friend
  Future<void> addFriend(Friend friend) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('friends')
        .doc(friend.uid)
        .set(friend.toMap());
  }

  // Get friends stream
  Stream<List<Friend>> getFriendsStream() {
    final user = _auth.currentUser;
    if (user == null) return const Stream.empty();

    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('friends')
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Friend.fromMap(doc.data())).toList());
  }

  // Search for multiple users by emails
  Future<List<Friend>> searchUsersByEmails(List<String> emails) async {
    if (emails.isEmpty) return [];

    final currentUserEmail = _auth.currentUser?.email;
    final uniqueEmails = emails.toSet().toList();

    final results = <Friend>[];

    // Batch by 10 (Firestore whereIn limit)
    for (int i = 0; i < uniqueEmails.length; i += 10) {
      final batch = uniqueEmails.skip(i).take(10).toList();

      final querySnapshot = await _firestore
          .collection('users')
          .where('email', whereIn: batch)
          .get();

      for (var doc in querySnapshot.docs) {
        final friend = Friend.fromMap(doc.data());
        if (friend.email != currentUserEmail) {
          results.add(friend);
        }
      }
    }

    return results;
  }
}
