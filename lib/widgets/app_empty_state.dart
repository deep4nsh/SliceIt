import 'package:flutter/material.dart';
import '../utils/colors.dart';
import '../utils/text_styles.dart';
import '../utils/app_spacing.dart';
import 'app_button.dart' show AppButton;

class AppEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onActionPressed;
  final Color? iconColor;

  const AppEmptyState({
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onActionPressed,
    this.iconColor,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.gapLg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 64,
              color: iconColor ?? AppColors.textTertiary,
            ),
            const SizedBox(height: AppSpacing.gapMd),
            Text(
              title,
              style: AppTextStyles.h3.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.gapSm),
                child: Text(
                  subtitle!,
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.textTertiary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            if (actionLabel != null && onActionPressed != null)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.gapLg),
                child: AppButton(
                  label: actionLabel!,
                  onPressed: onActionPressed!,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
