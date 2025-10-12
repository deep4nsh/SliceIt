import 'package:flutter/material.dart';
import '../utils/colors.dart';
import '../utils/text_styles.dart';
import '../services/auth_service.dart';
import 'home_screen.dart';

class OtpVerificationScreen extends StatefulWidget {
  final String verificationId;
  
  const OtpVerificationScreen({
    super.key,
    required this.verificationId,
  });

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final _otpController = TextEditingController();
  final AuthService _authService = AuthService();
  bool _isLoading = false;

  // 🔹 Verify OTP
  Future<void> _verifyOtp() async {
    final otp = _otpController.text.trim();
    if (otp.isEmpty) {
      _showSnackBar("Enter OTP");
      return;
    }

    setState(() => _isLoading = true);

    try {
      final userCredential = await _authService.verifyOtp(
        widget.verificationId,
        otp,
      );
      if (userCredential != null && mounted) {
        _showSnackBar("Phone verified successfully ✅");
        Navigator.pushReplacement(
          context, 
          MaterialPageRoute(builder: (_) => const HomeScreen())
        );
      } else {
        _showSnackBar("Invalid OTP ❌");
      }
    } catch (e) {
      _showSnackBar("Invalid OTP ❌");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // 🔹 SnackBar Helper
  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        title: Text("OTP Verification", style: AppTextStyles.heading2.copyWith(color: AppColors.white)),
        centerTitle: true,
        backgroundColor: AppColors.oliveGreen,
        foregroundColor: AppColors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "Enter the OTP sent to your phone",
              style: AppTextStyles.heading1,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              "Please check your SMS messages",
              style: AppTextStyles.body,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            
            TextField(
              controller: _otpController,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                letterSpacing: 8,
              ),
              decoration: InputDecoration(
                labelText: "Enter OTP",
                labelStyle: AppTextStyles.body,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.oliveGreen, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 30),
            
            _isLoading
                ? CircularProgressIndicator(color: AppColors.oliveGreen)
                : ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.oliveGreen,
                      minimumSize: const Size(double.infinity, 56),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: _verifyOtp,
                    child: Text("Verify OTP", style: AppTextStyles.button),
                  ),
          ],
        ),
      ),
    );
  }
}