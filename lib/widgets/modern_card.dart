import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/app_spacing.dart';
import '../utils/colors.dart';

/// Highly stylized container with support for customized elevation,
/// and border styles adapted to the minimalist professional finance design system.
/// Adds tactile responsive bouncy feedback and light haptic impact on tap.
class ModernCard extends StatefulWidget {
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
  State<ModernCard> createState() => _ModernCardState();
}

class _ModernCardState extends State<ModernCard> with SingleTickerProviderStateMixin {
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 90),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.975).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    _scaleController.forward();
    HapticFeedback.lightImpact();
  }

  void _onTapCancel() {
    _scaleController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    // Automatic fallback to responsive surface tokens
    final cardColor = widget.color ?? (isDark ? AppColors.darkSurface1 : AppColors.lightSurface1);
    final cardRadius = widget.radius ?? AppSpacing.radiusCard;

    Widget cardWidget = Container(
      width: widget.width,
      height: widget.height,
      margin: widget.margin ?? const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: widget.gradient == null ? cardColor : null,
        gradient: widget.gradient,
        borderRadius: BorderRadius.circular(cardRadius),
        border: Border.all(
          color: (isDark ? AppColors.darkSurfaceBorder : AppColors.lightSurfaceBorder)
              .withValues(alpha: 0.4),
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: (isDark ? Colors.black : AppColors.textDarkPrimary)
                .withValues(alpha: isDark ? 0.08 : 0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
            spreadRadius: 0,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(cardRadius),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap != null
                ? () {
                    _scaleController.reverse();
                    widget.onTap!();
                  }
                : null,
            onTapDown: widget.onTap != null ? _onTapDown : null,
            onTapCancel: widget.onTap != null ? _onTapCancel : null,
            borderRadius: BorderRadius.circular(cardRadius),
            child: Padding(
              padding: widget.padding ?? const EdgeInsets.all(AppSpacing.cardPadding),
              child: widget.child,
            ),
          ),
        ),
      ),
    );

    if (widget.onTap == null) {
      return cardWidget;
    }

    return ScaleTransition(
      scale: _scaleAnimation,
      child: cardWidget,
    );
  }
}

