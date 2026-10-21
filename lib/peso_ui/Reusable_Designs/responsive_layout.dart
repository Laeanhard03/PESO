import 'package:flutter/material.dart';

/// Width class for responsive PESO layouts, measured in logical pixels.
enum PesoLayoutClass { compact, medium, expanded }

const double pesoCompactBreakpoint = 600;
const double pesoExpandedBreakpoint = 1024;

/// Classifies available logical width into the shared PESO layout tiers.
PesoLayoutClass classifyPesoWidth(double width) {
  if (width < pesoCompactBreakpoint) return PesoLayoutClass.compact;
  if (width < pesoExpandedBreakpoint) return PesoLayoutClass.medium;
  return PesoLayoutClass.expanded;
}

/// Centers content and protects it from stretching beyond [maxWidth].
///
/// The widget deliberately constrains width only; its parent owns height and
/// scrolling, so it can be used inside pages, dialogs, and dashboard panels.
class ResponsiveContent extends StatelessWidget {
  const ResponsiveContent({
    super.key,
    required this.child,
    this.maxWidth = 1200,
    this.padding = const EdgeInsets.all(16),
    this.alignment = Alignment.topCenter,
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry padding;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : maxWidth;
        final contentWidth = availableWidth < maxWidth
            ? availableWidth
            : maxWidth;

        return Align(
          alignment: alignment,
          child: SizedBox(
            width: contentWidth,
            child: Padding(
              padding: padding,
              child: child,
            ),
          ),
        );
      },
    );
  }
}
