import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../utils/colors.dart';
import '../utils/text_styles.dart';
import '../services/auth_service.dart';
import 'signup_screen.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final authService = AuthService();
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
            Text("Welcome Back!", style: AppTextStyles.heading1),
            const SizedBox(height: 12),
            Text("Log in to continue using SliceIt", style: AppTextStyles.body),
            const SizedBox(height: 40),

            // Google Sign-In Button
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
                        final userCred = await authService.signInWithGoogle();
                        if (userCred != null && mounted) {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (_) => const HomeScreen()),
                          );
                        } else if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Google Sign-In cancelled or failed")),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Google Sign-In failed. Please try again.")),
                          );
                        }
                      } finally {
                        if (mounted) {
                          setState(() => _isLoading = false);
                        }
                      }
                    },
                    icon: const FaIcon(FontAwesomeIcons.google, color: Colors.white),
                    label: Text("Sign in with Google", style: AppTextStyles.button),
                  ),
            const SizedBox(height: 20),

            TextButton(
              onPressed: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const SignupScreen()));
              },
              child: const Text("Don't have an account? Sign up",
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