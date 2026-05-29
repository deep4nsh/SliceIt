import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../utils/app_spacing.dart';
import '../utils/colors.dart';
import '../utils/text_styles.dart';

enum ButtonVariant {
  primary,
  secondary,
  outline,
  ghost,
}

/// A highly polished interactive button component tailored to the minimalist
/// dark-first design system. Supports animated loading states, rich micro-interactions,
/// and variant-based responsive styling.
class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final Color? backgroundColor;
  final Color? textColor;
  final double? width;
  final double height;
  final double borderRadius;
  final ButtonVariant variant;

  const CustomButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.isLoading = false,
    this.icon,
    this.backgroundColor,
    this.textColor,
    this.width,
    this.height = 44.0,
    this.borderRadius = AppSpacing.radiusButton,
    this.variant = ButtonVariant.primary,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Resolve variant styling mapped to unified design tokens
    Color resolvedBg;
    Color resolvedText;
    BorderSide resolvedBorder = BorderSide.none;

    switch (variant) {
      case ButtonVariant.primary:
        resolvedBg = backgroundColor ?? AppColors.primaryAccent;
        resolvedText = textColor ?? Colors.white;
        break;
      case ButtonVariant.secondary:
        resolvedBg = backgroundColor ?? (isDark ? AppColors.darkSurface2 : AppColors.lightSurface2);
        resolvedText = textColor ?? (isDark ? Colors.white : AppColors.textDarkPrimary);
        resolvedBorder = BorderSide(
          color: isDark ? AppColors.darkSurfaceBorder : AppColors.lightSurfaceBorder,
          width: 1,
        );
        break;
      case ButtonVariant.outline:
        resolvedBg = Colors.transparent;
        resolvedText = textColor ?? (isDark ? AppColors.secondaryAccent : AppColors.primaryAccent);
        resolvedBorder = BorderSide(color: resolvedText, width: 1);
        break;
      case ButtonVariant.ghost:
        resolvedBg = Colors.transparent;
        resolvedText = textColor ?? (isDark ? Colors.white : AppColors.textDarkPrimary);
        break;
    }

    final isDisabled = onPressed == null || isLoading;

    Widget buttonContent = ElevatedButton(
      onPressed: isDisabled ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: resolvedBg,
        foregroundColor: resolvedText,
        disabledBackgroundColor: resolvedBg.withValues(alpha: 0.4),
        disabledForegroundColor: resolvedText.withValues(alpha: 0.6),
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          side: resolvedBorder,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16),
      ),
      child: isLoading
          ? Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(resolvedText),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Processing...',
                  style: AppTextStyles.label.copyWith(
                    color: resolvedText,
                    letterSpacing: 0.5,
                  ),
                ).animate(onPlay: (c) => c.repeat(reverse: true)).fade(begin: 0.5, end: 1.0),
              ],
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, color: resolvedText, size: 20),
                  const SizedBox(width: 12),
                ],
                Flexible(
                  child: Text(
                    text,
                    style: AppTextStyles.button.copyWith(
                      color: resolvedText,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
    );

    // Inject subtle entrance / reactive interaction layer
    return SizedBox(
      width: width ?? double.infinity,
      height: height,
      child: buttonContent,
    );
  }
}
