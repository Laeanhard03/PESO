import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'design_tokens.dart';

/// A static, low-contrast contour and grain overlay for branded green surfaces.
/// It is deliberately paint-only: no image assets, animation, blur, or hit testing.
enum PesoGreenTextureTone { dark, brand, pale }

class PesoGreenTextureOverlay extends StatelessWidget {
  const PesoGreenTextureOverlay({
    super.key,
    this.tone = PesoGreenTextureTone.dark,
    this.intensity = 1,
  });

  final PesoGreenTextureTone tone;
  final double intensity;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _PesoGreenTexturePainter(tone: tone, intensity: intensity),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _PesoGreenTexturePainter extends CustomPainter {
  const _PesoGreenTexturePainter({required this.tone, required this.intensity});

  final PesoGreenTextureTone tone;
  final double intensity;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0 || intensity <= 0) return;

    final pale = tone == PesoGreenTextureTone.pale;
    final dark = tone == PesoGreenTextureTone.dark;
    final lineBase = pale ? PesoTokens.brandGreenDark : Colors.white;
    final lineOpacity = pale
        ? 0.052
        : dark
        ? 0.095
        : 0.075;
    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = lineBase.withValues(alpha: lineOpacity * intensity);

    // Two off-canvas organic contour clusters create depth without a repeated
    // geometric tile or a busy pattern behind small text.
    final anchors = <Offset>[
      Offset(size.width * 0.98, size.height * 0.08),
      Offset(size.width * 0.04, size.height * 0.96),
    ];

    for (var cluster = 0; cluster < anchors.length; cluster++) {
      final center = anchors[cluster];
      for (var ring = 0; ring < 7; ring++) {
        final rx = math.max(42.0, size.width * (0.105 + ring * 0.027));
        final ry = math.max(34.0, size.height * (0.16 + ring * 0.038));
        final drift = (cluster == 0 ? 1.0 : -1.0) * ring * 1.8;
        final path = Path()
          ..moveTo(center.dx - rx * 0.78, center.dy - ry * 0.08)
          ..cubicTo(
            center.dx - rx * 1.12,
            center.dy - ry * 0.70 + drift,
            center.dx - rx * 0.28,
            center.dy - ry * 1.10,
            center.dx + rx * 0.34,
            center.dy - ry * 0.80,
          )
          ..cubicTo(
            center.dx + rx * 1.02,
            center.dy - ry * 0.47,
            center.dx + rx * 1.08,
            center.dy + ry * 0.30,
            center.dx + rx * 0.48,
            center.dy + ry * 0.77,
          )
          ..cubicTo(
            center.dx - rx * 0.08,
            center.dy + ry * 1.12,
            center.dx - rx * 1.04,
            center.dy + ry * 0.62,
            center.dx - rx * 0.78,
            center.dy - ry * 0.08,
          )
          ..close();
        canvas.drawPath(path, linePaint);
      }
    }

    // Sparse micro-grain gives large flat fields a tactile finish. The dots
    // are intentionally faint and deterministic so every screen is stable.
    final grainPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = lineBase.withValues(alpha: (pale ? 0.035 : 0.028) * intensity);
    for (var y = 14.0; y < size.height; y += 27) {
      for (var x = 14.0; x < size.width; x += 27) {
        final gx = (x / 27).round();
        final gy = (y / 27).round();
        if ((gx * 3 + gy * 5) % 4 == 0) {
          canvas.drawCircle(Offset(x, y), 0.65, grainPaint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PesoGreenTexturePainter oldDelegate) =>
      oldDelegate.tone != tone || oldDelegate.intensity != intensity;
}

/// Places the texture behind interactive content while preserving the existing
/// layout, hit testing, and text contrast of the wrapped child.
class PesoGreenTextureLayer extends StatelessWidget {
  const PesoGreenTextureLayer({
    super.key,
    required this.child,
    this.tone = PesoGreenTextureTone.dark,
    this.intensity = 1,
    this.enabled = true,
  });

  final Widget child;
  final PesoGreenTextureTone tone;
  final double intensity;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    if (!enabled || intensity <= 0) return child;
    return Stack(
      fit: StackFit.passthrough,
      children: [
        Positioned.fill(
          child: PesoGreenTextureOverlay(tone: tone, intensity: intensity),
        ),
        child,
      ],
    );
  }
}
