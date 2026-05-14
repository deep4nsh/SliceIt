import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../utils/colors.dart';
import '../utils/text_styles.dart';
import '../utils/app_spacing.dart';
import '../services/auth_service.dart';
import '../widgets/custom_button.dart';
import '../widgets/mesh_background.dart';
import 'signup_screen.dart';
import 'main_shell.dart';

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
                // Logo or Icon placeholder
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: (isDark ? AppColors.secondaryAccent : AppColors.primaryAccent).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.account_balance_wallet_rounded,
                    size: 64,
                    color: isDark ? AppColors.secondaryAccent : AppColors.primaryAccent,
                  ),
                ),
                const SizedBox(height: 40),
                Text(
                  "Welcome Back!",
                  style: AppTextStyles.h1.copyWith(
                    color: isDark ? AppColors.textLightPrimary : AppColors.textDarkPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  "Log in to continue using SliceIt",
                  style: AppTextStyles.bodyL.copyWith(
                    color: (isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary)
                        .withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 60),

                // Google Sign-In Button
                if (_isLoading)
                  const CircularProgressIndicator()
                else
                  CustomButton(
                    text: "Sign in with Google",
                    icon: FontAwesomeIcons.google,
                    variant: ButtonVariant.primary,
                    onPressed: () async {
                      setState(() => _isLoading = true);

                      try {
                        final userCred = await authService.signInWithGoogle();
                        if (userCred != null && context.mounted) {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (_) => const MainShell()),
                          );
                        } else if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text("Google Sign-In cancelled or failed", style: AppTextStyles.bodyM),
                              backgroundColor: AppColors.warning,
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text("Google Sign-In failed. Please try again.", style: AppTextStyles.bodyM),
                              backgroundColor: AppColors.error,
                            ),
                          );
                        }
                      } finally {
                        if (mounted) {
                          setState(() => _isLoading = false);
                        }
                      }
                    },
                  ),
                const SizedBox(height: 24),

                TextButton(
                  onPressed: () {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const SignupScreen()));
                  },
                  child: RichText(
                    text: TextSpan(
                      style: AppTextStyles.bodyM.copyWith(
                        color: isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary,
                      ),
                      children: [
                        const TextSpan(text: "Don't have an account? "),
                        TextSpan(
                          text: "Sign up",
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