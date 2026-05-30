import 'package:flutter/material.dart';

/// Apple-level refined motion system
/// All animations should be purposeful and subtle
class AppMotion {
  // ==========================================
  // ANIMATION DURATIONS
  // ==========================================

  /// Instant feedback for user interactions (button press, toggle)
  static const Duration quickInteraction = Duration(milliseconds: 150);

  /// Standard interaction (card hover, state change)
  static const Duration standardInteraction = Duration(milliseconds: 200);

  /// Significant transition (screen change, modal open)
  static const Duration significantTransition = Duration(milliseconds: 300);

  /// Page entry animation (initial page load)
  static const Duration pageEntry = Duration(milliseconds: 400);

  // ==========================================
  // ANIMATION CURVES
  // ==========================================

  /// Quick deceleration (responsive, then slowing)
  static const Curve quickCurve = Curves.easeOut;

  /// Standard smooth deceleration
  static const Curve standardCurve = Curves.easeOutCubic;

  /// Dramatic entry (more motion)
  static const Curve entryCurve = Curves.easeOutCubic;

  /// Quick exit (fast disappear)
  static const Curve exitCurve = Curves.easeInCubic;

  // ==========================================
  // ANIMATION SPECIFICATIONS
  // ==========================================

  /// Button press animation (subtle scale + opacity)
  static const _ButtonPressSpec = (
    duration: Duration(milliseconds: 150),
    curve: Curves.easeOut,
    scaleEnd: 0.95,
    opacityEnd: 0.8,
  );

  /// Card interaction animation (shadow + color)
  static const _CardInteractionSpec = (
    duration: Duration(milliseconds: 200),
    curve: Curves.easeOutCubic,
  );

  /// List item entry (fade + slide)
  static const _ListItemEntrySpec = (
    duration: Duration(milliseconds: 300),
    curve: Curves.easeOutCubic,
    staggerInterval: Duration(milliseconds: 50),
  );

  /// Screen transition (fade only)
  static const _ScreenTransitionSpec = (
    duration: Duration(milliseconds: 300),
    curve: Curves.easeOutCubic,
  );

  /// Loading spinner (continuous)
  static const _LoadingSpinnerSpec = (
    duration: Duration(milliseconds: 1000),
    curve: Curves.linear,
  );

  /// Success state animation (brief celebration)
  static const _SuccessStateSpec = (
    duration: Duration(milliseconds: 400),
    curve: Curves.easeOut,
  );

  /// Modal open/close
  static const _ModalSpec = (
    duration: Duration(milliseconds: 300),
    curve: Curves.easeOutCubic,
  );

  /// Snackbar enter/exit
  static const _SnackbarSpec = (
    duration: Duration(milliseconds: 250),
    curve: Curves.easeOut,
  );

  // ==========================================
  // ANIMATION HELPERS
  // ==========================================

  /// Get staggered delay for list items
  /// Use: delay: AppMotion.getStaggerDelay(index)
  static Duration getStaggerDelay(int index) {
    return Duration(milliseconds: 50 * index);
  }

  /// Get easing curve by type
  static Curve getCurve(String type) {
    return switch (type) {
      'quick' => quickCurve,
      'standard' => standardCurve,
      'entry' => entryCurve,
      'exit' => exitCurve,
      _ => standardCurve,
    };
  }

  /// Get duration by type
  static Duration getDuration(String type) {
    return switch (type) {
      'quick' => quickInteraction,
      'standard' => standardInteraction,
      'significant' => significantTransition,
      'entry' => pageEntry,
      _ => standardInteraction,
    };
  }
}

// ==========================================
// ANIMATION WIDGET HELPERS
// ==========================================

/// Smooth fade transition widget
class FadeInWidget extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final Curve curve;

  const FadeInWidget({
    required this.child,
    this.duration = const Duration(milliseconds: 300),
    this.curve = Curves.easeOut,
    super.key,
  });

  @override
  State<FadeInWidget> createState() => _FadeInWidgetState();
}

class _FadeInWidgetState extends State<FadeInWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: widget.duration, vsync: this);
    _animation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: widget.curve),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(opacity: _animation, child: widget.child);
  }
}

/// Smooth slide + fade transition widget
class SlideInWidget extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final Curve curve;
  final Offset beginOffset;

  const SlideInWidget({
    required this.child,
    this.duration = const Duration(milliseconds: 300),
    this.curve = Curves.easeOutCubic,
    this.beginOffset = const Offset(0, 0.1),
    super.key,
  });

  @override
  State<SlideInWidget> createState() => _SlideInWidgetState();
}

class _SlideInWidgetState extends State<SlideInWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: widget.duration, vsync: this);

    _slideAnimation = Tween<Offset>(begin: widget.beginOffset, end: Offset.zero)
        .animate(CurvedAnimation(parent: _controller, curve: widget.curve));

    _fadeAnimation = Tween<double>(begin: 0, end: 1)
        .animate(CurvedAnimation(parent: _controller, curve: widget.curve));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(position: _slideAnimation, child: widget.child),
    );
  }
}

/// Scale animation widget (for buttons, etc)
class ScaleInWidget extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final Curve curve;
  final double beginScale;

  const ScaleInWidget({
    required this.child,
    this.duration = const Duration(milliseconds: 200),
    this.curve = Curves.easeOut,
    this.beginScale = 0.9,
    super.key,
  });

  @override
  State<ScaleInWidget> createState() => _ScaleInWidgetState();
}

class _ScaleInWidgetState extends State<ScaleInWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: widget.duration, vsync: this);

    _scaleAnimation =
        Tween<double>(begin: widget.beginScale, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: widget.curve),
    );

    _fadeAnimation = Tween<double>(begin: 0, end: 1)
        .animate(CurvedAnimation(parent: _controller, curve: widget.curve));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: ScaleTransition(scale: _scaleAnimation, child: widget.child),
    );
  }
}
