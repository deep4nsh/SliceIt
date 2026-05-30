import 'package:flutter/material.dart';
import '../utils/colors.dart';
import '../utils/app_spacing.dart';

class AppCard extends StatefulWidget {
  final Widget child;
  final Color? backgroundColor;
  final Color? borderColor;
  final EdgeInsets padding;
  final EdgeInsets margin;
  final double borderRadius;
  final VoidCallback? onTap;
  final bool interactive;

  const AppCard({
    required this.child,
    this.backgroundColor,
    this.borderColor,
    this.padding = const EdgeInsets.all(AppSpacing.cardPadding),
    this.margin = const EdgeInsets.only(bottom: AppSpacing.gapSm),
    this.borderRadius = AppSpacing.radiusMd,
    this.onTap,
    this.interactive = true,
    super.key,
  });

  @override
  State<AppCard> createState() => _AppCardState();
}

class _AppCardState extends State<AppCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bgColor = widget.backgroundColor ??
        (isDark ? AppColors.darkSurface1 : AppColors.lightSurface1);

    final borderColor = widget.borderColor ??
        (_isHovered ? AppColors.borderStrong : AppColors.borderDefault);

    return Container(
      margin: widget.margin,
      decoration: BoxDecoration(
        color: bgColor,
        border: Border.all(
          color: borderColor,
          width: 1,
        ),
        borderRadius: BorderRadius.circular(widget.borderRadius),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.interactive ? widget.onTap : null,
          onHover: widget.interactive
              ? (isHovered) => setState(() => _isHovered = isHovered)
              : null,
          borderRadius: BorderRadius.circular(widget.borderRadius),
          child: Padding(
            padding: widget.padding,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
