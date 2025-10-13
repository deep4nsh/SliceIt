import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  /// 🔹 Google Sign-In
  Future<UserCredential?> signInWithGoogle() async {
    try {
      debugPrint("AuthService: Starting Google Sign-In...");

      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        debugPrint("AuthService: Google Sign-In cancelled by user");
        return null;
      }

      final GoogleSignInAuthentication googleAuth =
      await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);

      debugPrint("AuthService: Google Sign-In successful, saving user data...");
      await _saveUser(userCredential.user!);

      return userCredential;
    } catch (e) {
      debugPrint("AuthService: Google Sign-In Error: $e");
      return null;
    }
  }

  /// 🔹 Save user info to Firestore AND Realtime Database
  Future<void> _saveUser(User user) async {
    try {
      // Firestore
      await _firestore.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'name': user.displayName ?? '',
        'email': user.email ?? '',
        'photoUrl': user.photoURL ?? '',
        'createdAt': FieldValue.serverTimestamp(),
        'lastSignIn': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Realtime Database
      await _database.child('users').child(user.uid).set({
        'uid': user.uid,
        'name': user.displayName ?? '',
        'email': user.email ?? '',
        'photoUrl': user.photoURL ?? '',
        'createdAt': ServerValue.timestamp,
        'lastSignIn': ServerValue.timestamp,
      });

      debugPrint("AuthService: User data saved successfully");
    } catch (e) {
      debugPrint("AuthService: Error saving user data: $e");
    }
  }

  /// 🔹 Logout
  Future<void> signOut() async {
    await _auth.signOut();
    await _googleSignIn.signOut();
  }

  /// 🔹 Current User
  User? get currentUser => _auth.currentUser;
}