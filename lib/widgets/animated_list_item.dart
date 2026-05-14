import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Highly efficient declarative list item transition component powered by flutter_animate.
/// Flawlessly injects sequential staggered entrance choreography without boilerplate controllers.
class AnimatedListItem extends StatelessWidget {
  final Widget child;
  final int index;
  final Duration duration;

  const AnimatedListItem({
    super.key,
    required this.child,
    required this.index,
    this.duration = const Duration(milliseconds: 400),
  });

  @override
  Widget build(BuildContext context) {
    // Smoothly stagger entrances with capped max delays to preserve responsiveness
    final effectiveDelay = (index * 40).clamp(0, 600).ms;

    return child
        .animate()
        .fade(
          duration: duration,
          delay: effectiveDelay,
          curve: Curves.easeOut,
        )
        .slideY(
          begin: 0.15,
          end: 0,
          duration: duration,
          delay: effectiveDelay,
          curve: Curves.easeOutCubic,
        );
  }
}
