import 'package:flutter/material.dart';
import 'package:roundtablezoo/core/constants/app_constants.dart';

/// The elliptical table area, built around the same circle
/// `RoundTableLayout` already seats characters on (research.md R1). The
/// vertical semi-axis equals [radius] — the top/bottom seat touches the
/// oval's edge rather than falling outside it (FR-005). The horizontal
/// semi-axis is wider than [radius] (FR-003: a flattened oval), but never
/// exceeds `AppConstants.tableSurfaceMaxWidthFraction` of [bounds]'s width
/// (clamp — Edge Cases: "stays within the allotted area").
Rect tableSurfaceRect({required Offset center, required double radius, required Size bounds}) {
  if (radius <= 0) {
    return Rect.zero;
  }
  final horizontalRadius = (radius / AppConstants.tableSurfaceFlattenRatio).clamp(
    0.0,
    bounds.width * AppConstants.tableSurfaceMaxWidthFraction / 2,
  );
  return Rect.fromCenter(center: center, width: horizontalRadius * 2, height: radius * 2);
}

/// Paints the table surface: a soft blurred shadow beneath a radially
/// gradiented oval, both derived from [center]/[radius] (research.md
/// R1–R4). Purely decorative — no semantics of its own; the caller wraps it
/// in `ExcludeSemantics` (research.md R6).
class TableSurfacePainter extends CustomPainter {
  const TableSurfacePainter({
    required this.center,
    required this.radius,
    required this.colorScheme,
  });

  final Offset center;
  final double radius;
  final ColorScheme colorScheme;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = tableSurfaceRect(center: center, radius: radius, bounds: size);
    if (rect.isEmpty) {
      return;
    }

    final shadowRect = rect.shift(const Offset(0, AppConstants.tableSurfaceShadowOffsetY));
    final shadowPaint = Paint()
      ..color = colorScheme.shadow.withValues(alpha: AppConstants.tableSurfaceShadowOpacity)
      ..maskFilter = const MaskFilter.blur(
        BlurStyle.normal,
        AppConstants.tableSurfaceShadowBlurSigma,
      );
    canvas.drawOval(shadowRect, shadowPaint);

    final gradientPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.3, -0.35),
        radius: 0.95,
        colors: [colorScheme.surfaceContainerHighest, colorScheme.primaryContainer],
      ).createShader(rect);
    canvas.drawOval(rect, gradientPaint);
  }

  @override
  bool shouldRepaint(covariant TableSurfacePainter oldDelegate) {
    return center != oldDelegate.center ||
        radius != oldDelegate.radius ||
        colorScheme != oldDelegate.colorScheme;
  }
}
