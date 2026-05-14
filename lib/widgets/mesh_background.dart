import 'package:flutter/material.dart';
import '../utils/colors.dart';

/// Clean, professional background container suitable for a finance app.
class MeshBackground extends StatelessWidget {
  final Widget child;
  final bool animate;

  const MeshBackground({
    super.key,
    required this.child,
    this.animate = true, // Kept for backwards compatibility but not used
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      color: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      child: child,
    );
  }
}
