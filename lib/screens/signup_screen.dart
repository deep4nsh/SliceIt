import 'package:flutter/material.dart';
import '../utils/colors.dart';
import '../utils/text_styles.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';
import 'phone_verification_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final AuthService authService = AuthService();
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text("Create Account", style: AppTextStyles.heading1),
            const SizedBox(height: 12),
            Text("Sign up with Google to get started", style: AppTextStyles.body),
            const SizedBox(height: 40),

            // Google Sign-Up Button
            _isLoading
                ? CircularProgressIndicator(color: AppColors.oliveGreen)
                : ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.oliveGreen,
                      minimumSize: const Size(double.infinity, 56),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () async {
                      setState(() => _isLoading = true);
                      
                      try {
                        debugPrint("Starting Google Sign-In...");
                        final userCred = await authService.signInWithGoogle();
                        debugPrint("Google Sign-In completed. UserCred: ${userCred != null ? 'Success' : 'Null'}");
                        
                        if (userCred != null && mounted) {
                          debugPrint("Navigating to PhoneVerificationScreen...");
                          // After successful Google signup, go to phone verification
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (_) => const PhoneVerificationScreen()),
                          );
                        } else if (mounted) {
                          debugPrint("Google Sign-In was cancelled or failed");
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Google Sign-Up cancelled or failed")),
                          );
                        }
                      } catch (e) {
                        debugPrint("Google Sign-In error: $e");
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text("Google Sign-Up failed: ${e.toString()}")),
                          );
                        }
                      } finally {
                        if (mounted) {
                          setState(() => _isLoading = false);
                        }
                      }
                    },
                    icon: const Icon(Icons.g_mobiledata, size: 32, color: Colors.white),
                    label: Text("Sign up with Google", style: AppTextStyles.button),
                  ),
            const SizedBox(height: 20),
            
            TextButton(
              onPressed: () {
                Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const LoginScreen()));
              },
              child: const Text("Already have an account? Sign in",
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
