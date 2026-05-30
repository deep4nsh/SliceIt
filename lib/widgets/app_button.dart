import 'package:flutter/material.dart';
import '../utils/colors.dart';
import '../utils/text_styles.dart';
import '../utils/app_spacing.dart';

enum ButtonVariant { primary, secondary, tertiary, danger }
enum ButtonSize { small, medium, large }

class AppButton extends StatefulWidget {
  final String label;
  final VoidCallback onPressed;
  final ButtonVariant variant;
  final ButtonSize size;
  final IconData? icon;
  final bool isLoading;
  final bool isDisabled;
  final double? width;

  const AppButton({
    required this.label,
    required this.onPressed,
    this.variant = ButtonVariant.primary,
    this.size = ButtonSize.medium,
    this.icon,
    this.isLoading = false,
    this.isDisabled = false,
    this.width,
    super.key,
  });

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> {
  bool _isPressed = false;

  Color _getBackgroundColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (widget.isDisabled) {
      return isDark
          ? AppColors.darkSurface2.withValues(alpha: 0.5)
          : AppColors.lightSurface2.withValues(alpha: 0.5);
    }

    if (_isPressed && widget.variant == ButtonVariant.primary) {
      return AppColors.primaryActive;
    }

    return switch (widget.variant) {
      ButtonVariant.primary => AppColors.primary,
      ButtonVariant.secondary => isDark ? AppColors.darkSurface1 : AppColors.lightSurface2,
      ButtonVariant.tertiary => Colors.transparent,
      ButtonVariant.danger => AppColors.error,
    };
  }

  Color _getTextColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (widget.isDisabled) {
      return AppColors.textTertiary;
    }

    return switch (widget.variant) {
      ButtonVariant.primary => AppColors.textPrimary,
      ButtonVariant.secondary => AppColors.textPrimary,
      ButtonVariant.tertiary => AppColors.primary,
      ButtonVariant.danger => AppColors.textPrimary,
    };
  }

  Color _getBorderColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (widget.variant == ButtonVariant.secondary) {
      return widget.isDisabled
          ? AppColors.borderSubtle
          : isDark
              ? AppColors.borderDefault
              : AppColors.lightSurfaceBorder;
    }

    return Colors.transparent;
  }

  double _getHeight() {
    return switch (widget.size) {
      ButtonSize.small => 36.0,
      ButtonSize.medium => 44.0,
      ButtonSize.large => 52.0,
    };
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final height = _getHeight();
    final bgColor = _getBackgroundColor(context);
    final textColor = _getTextColor(context);
    final borderColor = _getBorderColor(context);

    return SizedBox(
      height: height,
      width: widget.width,
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          border: borderColor != Colors.transparent
              ? Border.all(color: borderColor, width: 1)
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.isDisabled || widget.isLoading ? null : widget.onPressed,
            onTapDown: (_) => setState(() => _isPressed = true),
            onTapCancel: () => setState(() => _isPressed = false),
            onTapUp: (_) => setState(() => _isPressed = false),
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: AppSpacing.buttonPaddingH,
                vertical: AppSpacing.buttonPaddingV,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.isLoading)
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(textColor),
                      ),
                    )
                  else if (widget.icon != null) ...[
                    Icon(
                      widget.icon,
                      size: 20,
                      color: textColor,
                    ),
                    const SizedBox(width: 8),
                  ],
                  Flexible(
                    child: Text(
                      widget.label,
                      style: AppTextStyles.label.copyWith(color: textColor),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
