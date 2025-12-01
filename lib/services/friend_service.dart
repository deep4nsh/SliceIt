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
}
