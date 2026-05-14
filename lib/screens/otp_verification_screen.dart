import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import '../utils/colors.dart';
import '../utils/text_styles.dart';
import '../widgets/custom_button.dart';
import 'main_shell.dart';

class OtpVerificationScreen extends StatefulWidget {
  final String verificationId;
  final String phoneNumber;

  const OtpVerificationScreen({
    super.key,
    required this.verificationId,
    required this.phoneNumber,
  });

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final TextEditingController _otpController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseDatabase _rtdb = FirebaseDatabase.instance;
  bool _isLoading = false;

  Future<void> _verifyOtpAndFinish() async {
    final code = _otpController.text.trim();
    if (code.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a valid 6-digit verification code")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: widget.verificationId,
        smsCode: code,
      );

      final user = _auth.currentUser;
      if (user != null) {
        // Link the verified phone credential to the signed-in Google account
        await user.linkWithCredential(credential);

        // Save authentication data to both Firestore and Realtime Database
        await _firestore.collection('users').doc(user.uid).set({
          'phoneNumber': widget.phoneNumber,
          'phoneVerified': true,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        await _rtdb.ref().child('users').child(user.uid).update({
          'phoneNumber': widget.phoneNumber,
          'phoneVerified': true,
          'updatedAt': DateTime.now().toIso8601String(),
        });

        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MainShell()),
        );
      } else {
        throw Exception("No authenticated user found.");
      }
    } catch (e) {
      debugPrint("OTP Verification failed: $e");
      if (mounted) {
        setState(() => _isLoading = false);
        String errorMessage = "Invalid OTP code. Please try again.";
        if (e is FirebaseAuthException && e.message != null) {
          errorMessage = e.message!;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceWhite,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.secondaryTeal.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.message_rounded,
                    size: 64,
                    color: AppColors.secondaryTeal,
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  "Enter OTP Code",
                  style: AppTextStyles.heading1,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  "Code sent via SMS to ${widget.phoneNumber}",
                  style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                TextField(
                  controller: _otpController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.heading2.copyWith(letterSpacing: 8),
                  decoration: InputDecoration(
                    counterText: "",
                    hintText: "••••••",
                    hintStyle: AppTextStyles.heading2.copyWith(
                      color: AppColors.textSecondary.withValues(alpha: 0.3),
                      letterSpacing: 8,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: AppColors.secondaryTeal),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: AppColors.primaryOrange, width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                CustomButton(
                  text: "Verify & Continue",
                  onPressed: _verifyOtpAndFinish,
                  isLoading: _isLoading,
                  backgroundColor: AppColors.primaryOrange,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
