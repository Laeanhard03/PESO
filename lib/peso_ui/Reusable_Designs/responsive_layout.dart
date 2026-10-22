import 'package:flutter/material.dart';

/// Width class for responsive PESO layouts, measured in logical pixels.
enum PesoLayoutClass { compact, medium, expanded }

const double pesoCompactBreakpoint = 600;
const double pesoExpandedBreakpoint = 1024;

/// Column count and card width for the PESO listing grids.
///
/// Desktop (>= 1080 logical px of content) shows three cards per row, tablets
/// two, phones one. Cards share the available width, so no row can overflow the
/// container the way a fixed 330px card did.
({int columns, double cardWidth}) pesoListingGrid({
  required double availableWidth,
  required double spacing,
  double threeColumnMinWidth = 1080,
  double twoColumnMinWidth = 620,
}) {
  final safeWidth = availableWidth < 0 ? 0.0 : availableWidth;
  final columns = safeWidth >= threeColumnMinWidth
      ? 3
      : safeWidth >= twoColumnMinWidth
      ? 2
      : 1;
  final cardWidth = (safeWidth - (spacing * (columns - 1))) / columns;
  return (columns: columns, cardWidth: cardWidth < 0 ? 0.0 : cardWidth);
}

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
            child: Padding(padding: padding, child: child),
          ),
        );
      },
    );
  }
}
