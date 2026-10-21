import 'dart:async';

import 'package:flutter/material.dart';

import 'design_tokens.dart';

/// PESO JobKonek logo system with three variations:
/// - Full lockup (logo + wordmark + optional tagline)
/// - Icon only (for compact spaces)
/// - Animated entrance (for hero/landing)
class PesoLogo extends StatelessWidget {
  /// Variation A: Full brand lockup with logo, wordmark, and optional tagline.
  const PesoLogo.full({
    super.key,
    this.size = PesoTokens.logoSizeMedium,
    this.showTagline = false,
    this.tagline = 'Your gateway to local opportunities',
    this.logoAsset = 'lib/assets/peso_app_icon.png',
    this.wordmark = 'PESO JobKonek',
    this.wordmarkStyle,
    this.taglineStyle,
    this.logoToTextGap,
    this.maxWidth,
  }) : backgroundColor = null,
       containerRadius = null,
       containerPadding = null,
       showBackground = true,
       delay = Duration.zero,
       duration = PesoTokens.logoEntranceDuration,
       curve = PesoTokens.logoEntranceCurve,
       initialScale = 1.0;

  /// Variation B: Icon-only logo for compact spaces.
  const PesoLogo.icon({
    super.key,
    this.size = PesoTokens.logoSizeSmall,
    this.logoAsset = 'lib/assets/peso_app_icon.png',
    this.backgroundColor,
    this.containerRadius,
    this.containerPadding,
    this.showBackground = true,
  }) : showTagline = false,
       tagline = 'Your gateway to local opportunities',
       wordmark = '',
       wordmarkStyle = null,
       taglineStyle = null,
       logoToTextGap = null,
       maxWidth = null,
       delay = Duration.zero,
       duration = PesoTokens.logoEntranceDuration,
       curve = PesoTokens.logoEntranceCurve,
       initialScale = 1.0;

  /// Variation C: Animated entrance logo for hero sections.
  const PesoLogo.animated({
    super.key,
    this.size = PesoTokens.logoSizeHero,
    this.logoAsset = 'lib/assets/peso_app_icon.png',
    this.delay = const Duration(milliseconds: 100),
    this.duration = PesoTokens.logoEntranceDuration,
    this.curve = PesoTokens.logoEntranceCurve,
    this.initialScale = PesoTokens.logoEntranceInitialScale,
  }) : showTagline = false,
       tagline = 'Your gateway to local opportunities',
       wordmark = '',
       wordmarkStyle = null,
       taglineStyle = null,
       logoToTextGap = null,
       maxWidth = null,
       backgroundColor = null,
       containerRadius = null,
       containerPadding = null,
       showBackground = true;

  // Common properties
  final double size;
  final String logoAsset;

  // Full lockup properties
  final bool showTagline;
  final String tagline;
  final String wordmark;
  final TextStyle? wordmarkStyle;
  final TextStyle? taglineStyle;
  final double? logoToTextGap;
  final double? maxWidth;

  // Icon-only properties
  final Color? backgroundColor;
  final double? containerRadius;
  final double? containerPadding;
  final bool showBackground;

  // Animated properties
  final Duration delay;
  final Duration duration;
  final Curve curve;
  final double initialScale;

  @override
  Widget build(BuildContext context) {
    // Variation C: Animated entrance
    if (delay.inMilliseconds > 0 ||
        duration != PesoTokens.logoEntranceDuration ||
        initialScale != 1.0) {
      return _AnimatedLogo(
        size: size,
        logoAsset: logoAsset,
        delay: delay,
        duration: duration,
        curve: curve,
        initialScale: initialScale,
      );
    }

    // Variation A: Full lockup
    if (wordmark.isNotEmpty) {
      return _FullLockup(
        size: size,
        logoAsset: logoAsset,
        showTagline: showTagline,
        tagline: tagline,
        wordmark: wordmark,
        wordmarkStyle: wordmarkStyle,
        taglineStyle: taglineStyle,
        logoToTextGap: logoToTextGap ?? (size > 56 ? 16 : 12),
        maxWidth: maxWidth,
      );
    }

    // Variation B: Icon only
    return _IconOnly(
      size: size,
      logoAsset: logoAsset,
      backgroundColor: backgroundColor ?? PesoTokens.brandGreenLight,
      containerRadius: containerRadius ?? PesoTokens.radiusContainer,
      containerPadding: containerPadding ?? (size >= 72 ? 16 : 12),
      showBackground: showBackground,
    );
  }
}

/// Full brand lockup: logo + wordmark + optional tagline.
class _FullLockup extends StatelessWidget {
  const _FullLockup({
    required this.size,
    required this.logoAsset,
    required this.showTagline,
    required this.tagline,
    required this.wordmark,
    required this.wordmarkStyle,
    required this.taglineStyle,
    required this.logoToTextGap,
    required this.maxWidth,
  });

  final double size;
  final String logoAsset;
  final bool showTagline;
  final String tagline;
  final String wordmark;
  final TextStyle? wordmarkStyle;
  final TextStyle? taglineStyle;
  final double logoToTextGap;
  final double? maxWidth;

  @override
  Widget build(BuildContext context) {
    final isLarge = size >= 56;
    final theme = Theme.of(context);

    final logoWidget = Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.1),
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipOval(
        child: Image.asset(
          logoAsset,
          width: size * 0.8,
          height: size * 0.8,
          fit: BoxFit.contain,
        ),
      ),
    );

    final textColumn = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          wordmark,
          style:
              wordmarkStyle ??
              PesoTokens.headlineSmall.copyWith(
                fontSize: isLarge ? 24 : 20,
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface,
              ),
        ),
        if (showTagline && tagline.isNotEmpty) ...[
          SizedBox(height: isLarge ? 4 : 2),
          Text(
            tagline,
            style:
                taglineStyle ??
                PesoTokens.bodySmall.copyWith(
                  fontSize: isLarge ? 13 : 11,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ],
    );

    final content = Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        logoWidget,
        SizedBox(width: logoToTextGap),
        textColumn,
      ],
    );

    if (maxWidth != null) {
      return ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth!),
        child: content,
      );
    }

    return content;
  }
}

/// Icon-only logo with optional background container.
class _IconOnly extends StatelessWidget {
  const _IconOnly({
    required this.size,
    required this.logoAsset,
    required this.backgroundColor,
    required this.containerRadius,
    required this.containerPadding,
    required this.showBackground,
    this.circularBackground = false,
    this.imageScale = 1.0,
  });

  final double size;
  final String logoAsset;
  final Color backgroundColor;
  final double containerRadius;
  final double containerPadding;
  final bool showBackground;
  final bool circularBackground;
  final double imageScale;

  @override
  Widget build(BuildContext context) {
    final logo = SizedBox(
      width: size,
      height: size,
      child: ClipOval(
        child: Transform.scale(
          scale: imageScale,
          child: Image.asset(
            logoAsset,
            width: size,
            height: size,
            fit: BoxFit.cover,
          ),
        ),
      ),
    );

    if (!showBackground) return logo;

    return Container(
      width: size + containerPadding * 2,
      height: size + containerPadding * 2,
      padding: EdgeInsets.all(containerPadding),
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: circularBackground ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: circularBackground
            ? null
            : BorderRadius.circular(containerRadius),
      ),
      child: logo,
    );
  }
}

/// Animated entrance logo for hero sections.
class _AnimatedLogo extends StatefulWidget {
  const _AnimatedLogo({
    required this.size,
    required this.logoAsset,
    required this.delay,
    required this.duration,
    required this.curve,
    required this.initialScale,
  });

  final double size;
  final String logoAsset;
  final Duration delay;
  final Duration duration;
  final Curve curve;
  final double initialScale;

  @override
  State<_AnimatedLogo> createState() => _AnimatedLogoState();
}

class _AnimatedLogoState extends State<_AnimatedLogo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _opacityAnimation;
  Timer? _entranceTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: widget.duration, vsync: this);
    _scaleAnimation = Tween<double>(
      begin: widget.initialScale,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: widget.curve));
    _opacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: widget.curve));

    _entranceTimer = Timer(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _entranceTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        const heroLogoInset = 16.0;
        return Opacity(
          opacity: _opacityAnimation.value.clamp(0.0, 1.0),
          child: Transform.scale(
            scale: _scaleAnimation.value,
            child: _IconOnly(
              size: widget.size + heroLogoInset * 2,
              logoAsset: widget.logoAsset,
              backgroundColor: PesoTokens.brandGreenLight,
              containerRadius: PesoTokens.radiusContainer,
              containerPadding: 0,
              showBackground: true,
              circularBackground: true,
              imageScale: 1.3,
            ),
          ),
        );
      },
    );
  }
}
