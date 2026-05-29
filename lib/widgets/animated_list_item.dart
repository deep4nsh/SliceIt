import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Highly efficient declarative list item transition component powered by flutter_animate.
/// Entrance animation plays only once on initial render; subsequent rebuilds skip animation.
class AnimatedListItem extends StatefulWidget {
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
  State<AnimatedListItem> createState() => _AnimatedListItemState();
}

class _AnimatedListItemState extends State<AnimatedListItem> {
  bool _animated = false;

  @override
  Widget build(BuildContext context) {
    if (_animated) return widget.child;
    _animated = true;

    final effectiveDelay = (widget.index * 40).clamp(0, 600).ms;
    return widget.child
        .animate()
        .fade(
          duration: widget.duration,
          delay: effectiveDelay,
          curve: Curves.easeOut,
        )
        .slideY(
          begin: 0.15,
          end: 0,
          duration: widget.duration,
          delay: effectiveDelay,
          curve: Curves.easeOutCubic,
        );
  }
}
