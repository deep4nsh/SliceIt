import 'package:flutter/material.dart';
import '../utils/colors.dart';
import '../utils/text_styles.dart';
import '../services/auth_service.dart';
import 'signup_screen.dart';
import 'home_screen.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();

    return Scaffold(
      backgroundColor: AppColors.white,
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text("Welcome Back!", style: AppTextStyles.heading1),
            const SizedBox(height: 12),
            Text("Log in to continue using SliceIt", style: AppTextStyles.body),
            const SizedBox(height: 40),

            // Google Sign-In Button
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.oliveGreen,
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                final userCred = await authService.signInWithGoogle();
                if (userCred != null && context.mounted) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const HomeScreen()),
                  );
                }
              },
              icon: const Icon(Icons.g_mobiledata, size: 32),
              label: const Text("Sign in with Google",
                  style: TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w500,
                      color: Colors.white)),
            ),
            const SizedBox(height: 20),

            TextButton(
              onPressed: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const SignupScreen()));
              },
              child: const Text("Sign up with phone number",
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