import 'package:flutter/material.dart';
import '../utils/colors.dart';
import '../utils/text_styles.dart';
import '../services/auth_service.dart';
import 'otp_verification_screen.dart';
import 'home_screen.dart';

class PhoneVerificationScreen extends StatefulWidget {
  const PhoneVerificationScreen({super.key});

  @override
  State<PhoneVerificationScreen> createState() => _PhoneVerificationScreenState();
}

class _PhoneVerificationScreenState extends State<PhoneVerificationScreen> {
  final TextEditingController phoneController = TextEditingController();
  final AuthService authService = AuthService();
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        title: Text("Phone Verification", style: AppTextStyles.heading2.copyWith(color: AppColors.white)),
        centerTitle: true,
        backgroundColor: AppColors.oliveGreen,
        foregroundColor: AppColors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text("Verify Your Phone Number", style: AppTextStyles.heading1),
            const SizedBox(height: 12),
            Text(
              "We need to verify your phone number to complete your account setup",
              style: AppTextStyles.body,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            
            TextField(
              controller: phoneController,
              decoration: InputDecoration(
                labelText: "Enter phone number",
                labelStyle: AppTextStyles.body,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.oliveGreen, width: 2),
                ),
                prefixText: '+91 ',
                prefixStyle: const TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w500,
                  fontSize: 16,
                ),
              ),
              keyboardType: TextInputType.phone,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 16,
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
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () async {
                      final phoneText = phoneController.text.trim();
                      if (phoneText.isEmpty || phoneText.length < 10) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Please enter a valid phone number")));
                        return;
                      }
                      
                      setState(() => _isLoading = true);
                      
                      String phone = '+91$phoneText';
                      await authService.verifyPhoneNumber(phone, (verificationId) {
                        setState(() => _isLoading = false);
                        if (mounted) {
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => OtpVerificationScreen(
                                      verificationId: verificationId)));
                        }
                      }, (e) {
                        setState(() => _isLoading = false);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(e.message ?? "Error sending OTP")));
                        }
                      });
                    },
                    child: Text("Send OTP", style: AppTextStyles.button),
                  ),
            const SizedBox(height: 20),
            
            TextButton(
              onPressed: () {
                // Skip phone verification and go directly to home
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const HomeScreen()),
                  (route) => false,
                );
              },
              child: const Text("Skip for now",
                  style: TextStyle(
                      color: AppColors.darkBlueGray,
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w500)),
            ),
          ],
        ),
      ),
    );
  }
}