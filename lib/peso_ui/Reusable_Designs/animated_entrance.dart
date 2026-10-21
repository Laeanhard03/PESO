import 'dart:async';

import 'package:flutter/material.dart';

/// Small fade-and-rise entrance used by landing-page sections.
/// The delay is cancellable so a disposed page does not leave timers behind.
class AnimatedEntrance extends StatefulWidget {
  const AnimatedEntrance({
    super.key,
    required this.child,
    this.delay = 0,
    this.duration = const Duration(milliseconds: 320),
    this.beginOffset = const Offset(0, 0.035),
  });

  final Widget child;
  final int delay;
  final Duration duration;
  final Offset beginOffset;

  @override
  State<AnimatedEntrance> createState() => _AnimatedEntranceState();
}

class _AnimatedEntranceState extends State<AnimatedEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<Offset> _position;
  Timer? _delayTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _configureAnimations();
    _scheduleEntrance();
  }

  void _configureAnimations() {
    final curve = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _opacity = curve;
    _position = Tween<Offset>(
      begin: widget.beginOffset,
      end: Offset.zero,
    ).animate(curve);
  }

  void _scheduleEntrance() {
    _delayTimer?.cancel();
    if (widget.delay <= 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_controller.isAnimating) _controller.forward();
      });
    } else {
      _delayTimer = Timer(Duration(milliseconds: widget.delay), () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void didUpdateWidget(covariant AnimatedEntrance oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.duration != widget.duration ||
        oldWidget.beginOffset != widget.beginOffset) {
      _controller.duration = widget.duration;
      _controller.value = 0;
      _configureAnimations();
      _scheduleEntrance();
    } else if (oldWidget.delay != widget.delay) {
      _controller.value = 0;
      _scheduleEntrance();
    }
  }

  @override
  void dispose() {
    _delayTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) return widget.child;
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(position: _position, child: widget.child),
    );
  }
}