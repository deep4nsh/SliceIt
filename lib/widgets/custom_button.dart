import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
/// tactile bouncy feedback, and a periodic sweeping shiny shimmer.
class CustomButton extends StatefulWidget {
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
  final bool isShiny;

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
    this.isShiny = true,
  });

  @override
  State<CustomButton> createState() => _CustomButtonState();
}

class _CustomButtonState extends State<CustomButton> with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;

  late AnimationController _shimmerController;
  late Animation<double> _shimmerAnimation;

  @override
  void initState() {
    super.initState();

    // Subtle scale feedback on tap (scales down slightly to 0.96)
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 80),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeOut),
    );

    // Diagonal sweeping metallic shimmer reflection animation
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _shimmerAnimation = Tween<double>(begin: -2.0, end: 2.0).animate(
      CurvedAnimation(parent: _shimmerController, curve: Curves.easeInOutCubic),
    );

    // Periodic sweep loop: 1.4s sweep, 2.6s pause (4s total interval)
    _shimmerController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        Future.delayed(const Duration(milliseconds: 2600), () {
          if (mounted && widget.isShiny && widget.onPressed != null && !widget.isLoading) {
            _shimmerController.forward(from: 0.0);
          }
        });
      }
    });

    if (widget.isShiny && widget.onPressed != null && !widget.isLoading) {
      _shimmerController.forward();
    }
  }

  @override
  void didUpdateWidget(CustomButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    final isCurrentlyActive = widget.onPressed != null && !widget.isLoading;
    final wasActive = oldWidget.onPressed != null && !oldWidget.isLoading;

    if (widget.isShiny && isCurrentlyActive && (!wasActive || !oldWidget.isShiny)) {
      if (!_shimmerController.isAnimating) {
        _shimmerController.forward(from: 0.0);
      }
    } else if (!isCurrentlyActive || !widget.isShiny) {
      _shimmerController.stop();
    }
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _shimmerController.dispose();
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

    // Resolve variant styling mapped to unified design tokens
    Color resolvedBg;
    Color resolvedText;
    BorderSide resolvedBorder = BorderSide.none;

    switch (widget.variant) {
      case ButtonVariant.primary:
        resolvedBg = widget.backgroundColor ?? AppColors.primaryAccent;
        resolvedText = widget.textColor ?? Colors.white;
        break;
      case ButtonVariant.secondary:
        resolvedBg = widget.backgroundColor ?? (isDark ? AppColors.darkSurface2 : AppColors.lightSurface2);
        resolvedText = widget.textColor ?? (isDark ? Colors.white : AppColors.textDarkPrimary);
        resolvedBorder = BorderSide(
          color: isDark ? AppColors.darkSurfaceBorder : AppColors.lightSurfaceBorder,
          width: 1,
        );
        break;
      case ButtonVariant.outline:
        resolvedBg = Colors.transparent;
        resolvedText = widget.textColor ?? (isDark ? AppColors.secondaryAccent : AppColors.primaryAccent);
        resolvedBorder = BorderSide(color: resolvedText, width: 1);
        break;
      case ButtonVariant.ghost:
        resolvedBg = Colors.transparent;
        resolvedText = widget.textColor ?? (isDark ? Colors.white : AppColors.textDarkPrimary);
        break;
    }

    final isDisabled = widget.onPressed == null || widget.isLoading;
    final buttonColor = isDisabled ? resolvedBg.withValues(alpha: 0.4) : resolvedBg;
    final textColor = isDisabled ? resolvedText.withValues(alpha: 0.6) : resolvedText;

    Widget childContent = widget.isLoading
        ? Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2.0,
                  valueColor: AlwaysStoppedAnimation<Color>(textColor),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Processing...',
                style: AppTextStyles.label.copyWith(
                  color: textColor,
                  letterSpacing: 0.5,
                ),
              ).animate(onPlay: (c) => c.repeat(reverse: true)).fade(begin: 0.5, end: 1.0),
            ],
          )
        : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, color: textColor, size: 18),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(
                  widget.text,
                  style: AppTextStyles.button.copyWith(
                    color: textColor,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          );

    return SizedBox(
      width: widget.width ?? double.infinity,
      height: widget.height,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          decoration: BoxDecoration(
            color: buttonColor,
            borderRadius: BorderRadius.circular(widget.borderRadius),
            border: resolvedBorder != BorderSide.none
                ? Border.all(color: resolvedBorder.color, width: resolvedBorder.width)
                : null,
            boxShadow: widget.variant == ButtonVariant.primary && !isDisabled
                ? [
                    BoxShadow(
                      color: resolvedBg.withValues(alpha: 0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            child: Stack(
              children: [
                // Shimmer Overlay for Shiny Premium effect
                if (widget.isShiny && !isDisabled && (widget.variant == ButtonVariant.primary || widget.variant == ButtonVariant.secondary))
                  Positioned.fill(
                    child: AnimatedBuilder(
                      animation: _shimmerAnimation,
                      builder: (context, child) {
                        return Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment(_shimmerAnimation.value, -1.0),
                              end: Alignment(_shimmerAnimation.value + 1.0, 1.0),
                              colors: [
                                Colors.white.withValues(alpha: 0.0),
                                Colors.white.withValues(alpha: 0.02),
                                Colors.white.withValues(alpha: 0.22),
                                Colors.white.withValues(alpha: 0.02),
                                Colors.white.withValues(alpha: 0.0),
                              ],
                              stops: const [0.0, 0.35, 0.5, 0.65, 1.0],
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                // Interactive tap area
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: isDisabled
                        ? null
                        : () {
                            _scaleController.reverse();
                            widget.onPressed!();
                          },
                    onTapDown: isDisabled ? null : _onTapDown,
                    onTapCancel: isDisabled ? null : _onTapCancel,
                    borderRadius: BorderRadius.circular(widget.borderRadius),
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: childContent,
                      ),
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

