import 'package:flutter/material.dart';
import '../utils/app_spacing.dart';
import '../utils/colors.dart';

/// Highly stylized container with support for customized elevation,
/// and border styles adapted to the minimalist professional finance design system.
class ModernCard extends StatelessWidget {
  final Widget child;
  final Color? color;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final double? width;
  final double? height;
  final Gradient? gradient;
  final double? radius;

  const ModernCard({
    super.key,
    required this.child,
    this.color,
    this.padding,
    this.margin,
    this.onTap,
    this.width,
    this.height,
    this.gradient,
    this.radius,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    // Automatic fallback to responsive surface tokens
    final cardColor = color ?? (isDark ? AppColors.darkSurface1 : AppColors.lightSurface1);
    final cardRadius = radius ?? AppSpacing.radiusLg;

    return Container(
      width: width,
      height: height,
      margin: margin ?? const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: gradient == null ? cardColor : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(cardRadius),
        border: Border.all(
          color: isDark ? AppColors.darkSurfaceBorder : AppColors.lightSurfaceBorder,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: (isDark ? Colors.black : AppColors.textDarkPrimary)
                .withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(cardRadius),
          child: Padding(
            padding: padding ?? const EdgeInsets.all(AppSpacing.screenPadding),
            child: child,
          ),
        ),
      ),
    );
  }
}
