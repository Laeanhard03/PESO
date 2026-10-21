import 'package:flutter/material.dart';

import 'design_tokens.dart';

/// An inexpensive glass-inspired surface: translucent layers, not a live blur.
/// Safe for scrolling lists, low-powered phones, and Flutter Web.
class PesoGlassSurface extends StatelessWidget {
  const PesoGlassSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(24),
    this.margin = EdgeInsets.zero,
    this.radius = 24,
    this.elevated = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final double radius;
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFFFFF), Color(0xF8F5FAF7)],
        ),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: const Color(0xFFDCE9E1)),
        boxShadow: elevated
            ? const [
                BoxShadow(
                  color: Color(0x10173E31),
                  blurRadius: 24,
                  offset: Offset(0, 9),
                ),
              ]
            : const [
                BoxShadow(
                  color: Color(0x08173E31),
                  blurRadius: 12,
                  offset: Offset(0, 3),
                ),
              ],
      ),
      child: child,
    );
  }
}

/// Shared branded introduction across a job seeker's dashboard tabs.
/// Decoration is entirely static, with no continuous animation or shader blur.
class PesoPageHeader extends StatelessWidget {
  const PesoPageHeader({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
    required this.eyebrow,
    this.detail,
  });

  final String title;
  final String description;
  final IconData icon;
  final String eyebrow;
  final Widget? detail;

  @override
  Widget build(BuildContext context) {
    final compact =
        MediaQuery.sizeOf(context).width < PesoTokens.breakpointCompact;
    return RepaintBoundary(
      child: Container(
        width: double.infinity,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(compact ? 23 : 30),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF173D30), Color(0xFF236349), Color(0xFF397B5D)],
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x24183E2F),
              blurRadius: 24,
              offset: Offset(0, 11),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              right: compact ? -102 : -50,
              top: compact ? -78 : -116,
              child: Container(
                width: compact ? 210 : 310,
                height: compact ? 210 : 310,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0x30FFFFFF),
                    width: 1.5,
                  ),
                  color: const Color(0x0CFFFFFF),
                ),
              ),
            ),
            Positioned(
              right: compact ? -18 : 70,
              bottom: compact ? -126 : -155,
              child: Container(
                width: compact ? 210 : 300,
                height: compact ? 210 : 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0x1DFFFFFF),
                    width: 1.5,
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(compact ? 22 : 36),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0x1DFFFFFF),
                      border: Border.all(color: const Color(0x30FFFFFF)),
                      borderRadius: BorderRadius.circular(40),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon, size: 16, color: const Color(0xFFD8F4E0)),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            eyebrow.toUpperCase(),
                            style: const TextStyle(
                              color: Color(0xFFE5F7E9),
                              fontWeight: FontWeight.w800,
                              fontSize: 11,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    title,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: compact ? 28 : 38,
                      height: 1.12,
                      letterSpacing: -0.7,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 710),
                    child: Text(
                      description,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.87),
                        fontSize: compact ? 14 : 16,
                        height: 1.55,
                      ),
                    ),
                  ),
                  if (detail != null) ...[const SizedBox(height: 22), detail!],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A small, responsive count indicator for page headers.
class PesoHeaderPill extends StatelessWidget {
  const PesoHeaderPill({super.key, required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0x1CFFFFFF),
        border: Border.all(color: const Color(0x32FFFFFF)),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: const Color(0xFFD7F4DF)),
          const SizedBox(width: 7),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Runs only on pointer hover; idle cards have no active ticker.
class PesoHoverLift extends StatefulWidget {
  const PesoHoverLift({super.key, required this.child, this.enabled = true});

  final Widget child;
  final bool enabled;

  @override
  State<PesoHoverLift> createState() => _PesoHoverLiftState();
}

class _PesoHoverLiftState extends State<PesoHoverLift> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return MouseRegion(
      onEnter: (_) {
        if (widget.enabled && !reduceMotion) setState(() => _hovering = true);
      },
      onExit: (_) {
        if (_hovering) setState(() => _hovering = false);
      },
      child: AnimatedSlide(
        duration: reduceMotion ? Duration.zero : PesoTokens.durationNormal,
        curve: Curves.easeOutCubic,
        offset: _hovering ? const Offset(0, -0.018) : Offset.zero,
        child: widget.child,
      ),
    );
  }
}
