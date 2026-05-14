import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../utils/colors.dart';
import '../utils/text_styles.dart';
import '../utils/app_spacing.dart';
import '../services/auth_service.dart';
import '../widgets/custom_button.dart';
import '../widgets/mesh_background.dart';
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return MeshBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.accentViolet.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.person_add_rounded,
                    size: 64,
                    color: AppColors.accentViolet,
                  ),
                ),
                const SizedBox(height: 40),
                Text(
                  "Create Account",
                  style: AppTextStyles.h1.copyWith(
                    color: isDark ? AppColors.textLightPrimary : AppColors.textDarkPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  "Sign up with Google to get started",
                  style: AppTextStyles.bodyL.copyWith(
                    color: (isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary)
                        .withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 60),

                // Google Sign-Up Button
                if (_isLoading)
                  const CircularProgressIndicator()
                else
                  CustomButton(
                    text: "Sign up with Google",
                    icon: FontAwesomeIcons.google,
                    variant: ButtonVariant.primary,
                    onPressed: () async {
                      setState(() => _isLoading = true);

                      try {
                        final userCred = await authService.signInWithGoogle();
                        if (!context.mounted) return;
                        if (userCred != null) {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (_) => const PhoneVerificationScreen()),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text("Google Sign-Up cancelled or failed", style: AppTextStyles.bodyM),
                              backgroundColor: AppColors.warning,
                            ),
                          );
                        }
                      } catch (e) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text("Google Sign-Up failed. Please try again.", style: AppTextStyles.bodyM),
                            backgroundColor: AppColors.error,
                          ),
                        );
                      } finally {
                        if (mounted) setState(() => _isLoading = false);
                      }
                    },
                  ),
                const SizedBox(height: 24),

                TextButton(
                  onPressed: () {
                    Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const LoginScreen()));
                  },
                  child: RichText(
                    text: TextSpan(
                      style: AppTextStyles.bodyM.copyWith(
                        color: isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary,
                      ),
                      children: [
                        const TextSpan(text: "Already have an account? "),
                        TextSpan(
                          text: "Sign in",
                          style: TextStyle(
                            color: isDark ? AppColors.secondaryAccent : AppColors.primaryAccent,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}