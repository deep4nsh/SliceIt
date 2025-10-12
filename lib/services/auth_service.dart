import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // 🔹 Google Sign-In
  Future<UserCredential?> signInWithGoogle() async {
    try {
      debugPrint("AuthService: Starting Google Sign-In...");
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        debugPrint("AuthService: Google sign-in was cancelled");
        return null;
      }

      debugPrint("AuthService: Getting authentication...");
      final GoogleSignInAuthentication googleAuth =
      await googleUser.authentication;

      debugPrint("AuthService: Creating Firebase credential...");
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      debugPrint("AuthService: Signing in with Firebase...");
      final userCredential = await _auth.signInWithCredential(credential);

      debugPrint("AuthService: Saving user data...");
      await _saveUser(userCredential.user!);

      debugPrint("AuthService: Google Sign-In completed successfully");
      return userCredential;
    } catch (e) {
      debugPrint("AuthService: Google Sign-In Error: $e");
      return null;
    }
  }

  // 🔹 Phone Auth — send OTP
  Future<void> verifyPhoneNumber(
      String phoneNumber,
      Function(String) codeSent,
      Function(FirebaseAuthException) verificationFailed) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: (PhoneAuthCredential credential) async {
        await _auth.signInWithCredential(credential);
      },
      verificationFailed: verificationFailed,
      codeSent: (String verificationId, int? resendToken) {
        codeSent(verificationId);
      },
      codeAutoRetrievalTimeout: (String verificationId) {},
      timeout: const Duration(seconds: 60),
    );
  }

  // 🔹 OTP verification
  Future<UserCredential?> verifyOtp(
      String verificationId, String smsCode) async {
    try {
      final credential = PhoneAuthProvider.credential(
          verificationId: verificationId, smsCode: smsCode);
      final userCredential = await _auth.signInWithCredential(credential);
      await _saveUser(userCredential.user!);
      return userCredential;
    } catch (e) {
      debugPrint("OTP Verification Error: $e");
      return null;
    }
  }

  // 🔹 Save user to Firestore AND Realtime Database
  Future<void> _saveUser(User user) async {
    try {
      debugPrint("AuthService: Saving user to Firestore...");
      
      // Save to Firestore
      await _firestore.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'name': user.displayName ?? '',
        'email': user.email ?? '',
        'phone': user.phoneNumber ?? '',
        'photoUrl': user.photoURL ?? '',
        'createdAt': FieldValue.serverTimestamp(),
        'lastSignIn': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      debugPrint("AuthService: Firestore save completed successfully");

      // Save to Realtime Database
      debugPrint("AuthService: Saving user to Realtime Database...");
      await _database.child('users').child(user.uid).set({
        'uid': user.uid,
        'name': user.displayName ?? '',
        'email': user.email ?? '',
        'phone': user.phoneNumber ?? '',
        'photoUrl': user.photoURL ?? '',
        'createdAt': ServerValue.timestamp,
        'lastSignIn': ServerValue.timestamp,
      });
      debugPrint("AuthService: Realtime Database save completed successfully");
      
    } catch (e) {
      debugPrint("AuthService: Error saving user data: $e");
      
      // Don't throw error for database save failures
      // User authentication was successful, just log the database error
      if (e.toString().contains('NOT_FOUND') || e.toString().contains('database does not exist')) {
        debugPrint("AuthService: Database not set up yet. Please create Firestore database in Firebase Console.");
      }
      // Don't rethrow - allow authentication to succeed even if database save fails
    }
  }

  // 🔹 Logout
  Future<void> signOut() async {
    await _auth.signOut();
    await _googleSignIn.signOut();
  }
}
