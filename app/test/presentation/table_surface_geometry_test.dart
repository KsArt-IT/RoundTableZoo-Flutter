import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roundtablezoo/core/constants/app_constants.dart';
import 'package:roundtablezoo/presentation/table/widgets/table_surface_painter.dart';

void main() {
  group('tableSurfaceRect', () {
    test('vertical semi-axis equals radius', () {
      const center = Offset(200, 300);
      const radius = 100.0;
      final rect = tableSurfaceRect(
        center: center,
        radius: radius,
        bounds: const Size(800, 800),
      );
      expect(rect.height / 2, radius);
    });

    test('horizontal semi-axis is radius / flattenRatio when it fits', () {
      const center = Offset(400, 400);
      const radius = 100.0;
      final rect = tableSurfaceRect(
        center: center,
        radius: radius,
        bounds: const Size(800, 800),
      );
      expect(rect.width / 2, closeTo(radius / AppConstants.tableSurfaceFlattenRatio, 1e-9));
    });

    test('horizontal semi-axis clamps to tableSurfaceMaxWidthFraction of bounds.width on a '
        'narrow screen', () {
      const center = Offset(60, 200);
      const radius = 100.0;
      const bounds = Size(120, 800);
      final rect = tableSurfaceRect(center: center, radius: radius, bounds: bounds);
      expect(
        rect.width / 2,
        closeTo(bounds.width * AppConstants.tableSurfaceMaxWidthFraction / 2, 1e-9),
      );
    });

    test('result is symmetric around center', () {
      const center = Offset(150, 250);
      const radius = 80.0;
      final rect = tableSurfaceRect(
        center: center,
        radius: radius,
        bounds: const Size(600, 600),
      );
      expect(rect.center, center);
    });

    test('radius <= 0 returns Rect.zero', () {
      expect(
        tableSurfaceRect(center: const Offset(10, 10), radius: 0, bounds: const Size(100, 100)),
        Rect.zero,
      );
      expect(
        tableSurfaceRect(center: const Offset(10, 10), radius: -5, bounds: const Size(100, 100)),
        Rect.zero,
      );
    });
  });

  group('TableSurfacePainter.shouldRepaint', () {
    const colorScheme = ColorScheme.light();
    const otherColorScheme = ColorScheme.dark();

    test('false when center, radius and colorScheme are unchanged', () {
      const oldDelegate = TableSurfacePainter(
        center: Offset(100, 100),
        radius: 50,
        colorScheme: colorScheme,
      );
      const newDelegate = TableSurfacePainter(
        center: Offset(100, 100),
        radius: 50,
        colorScheme: colorScheme,
      );
      expect(newDelegate.shouldRepaint(oldDelegate), isFalse);
    });

    test('true when center differs', () {
      const oldDelegate = TableSurfacePainter(
        center: Offset(100, 100),
        radius: 50,
        colorScheme: colorScheme,
      );
      const newDelegate = TableSurfacePainter(
        center: Offset(101, 100),
        radius: 50,
        colorScheme: colorScheme,
      );
      expect(newDelegate.shouldRepaint(oldDelegate), isTrue);
    });

    test('true when radius differs', () {
      const oldDelegate = TableSurfacePainter(
        center: Offset(100, 100),
        radius: 50,
        colorScheme: colorScheme,
      );
      const newDelegate = TableSurfacePainter(
        center: Offset(100, 100),
        radius: 51,
        colorScheme: colorScheme,
      );
      expect(newDelegate.shouldRepaint(oldDelegate), isTrue);
    });

    test('true when colorScheme differs', () {
      const oldDelegate = TableSurfacePainter(
        center: Offset(100, 100),
        radius: 50,
        colorScheme: colorScheme,
      );
      const newDelegate = TableSurfacePainter(
        center: Offset(100, 100),
        radius: 50,
        colorScheme: otherColorScheme,
      );
      expect(newDelegate.shouldRepaint(oldDelegate), isTrue);
    });
  });
}
