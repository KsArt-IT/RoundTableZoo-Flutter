import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:roundtablezoo/presentation/table/widgets/talk_pose.dart';

/// Draws the cat — lying on its side, talking — for one [TalkPose].
///
/// Vector, not a raster asset or a Lottie file, for the same reason the
/// table surface is a `CustomPainter` (`specs/006-table-surface-render`): it
/// scales to any seat size and takes its colors from the character config
/// and the current `ColorScheme`, so it needs no light/dark variants and no
/// licensing.
///
/// Everything is laid out in a fixed [_design] space and scaled to whatever
/// box the widget gets, so the numbers below read as proportions of the cat
/// rather than device pixels. The head keeps a 0..100 space of its own,
/// scaled into place by [_headScale] — that is why the face geometry is
/// written around a circle at (50, 54) that no longer exists as a disc.
class CatFacePainter extends CustomPainter {
  CatFacePainter({
    required ValueListenable<TalkPose> pose,
    required this.color,
    required this.surface,
    required this.ink,
  }) : _pose = pose,
       super(repaint: pose);

  /// The character's own color (`characters.json` → `colorHex`). Outlines
  /// use it at full strength; fills are it faded toward [surface].
  final Color color;

  /// What the seat sits on — the fills are mixed toward it so a colored
  /// animal never turns into one flat blob.
  final Color surface;

  /// Eyes, mouth and whiskers. From the `ColorScheme`, not from the
  /// character color, so contrast holds in both themes.
  final Color ink;

  final ValueListenable<TalkPose> _pose;

  /// The space the cat is drawn in: wider than tall, because it is lying
  /// down. Fitted into the widget's box, centered.
  static const Size _design = Size(158, 112);

  static const double _headScale = 0.82;
  static const Offset _headAnchor = Offset(42, 40);

  /// [TalkPose.headBob] is a fraction of the avatar's size; this turns it
  /// into [_design] units.
  static const double _bobUnits = 70;

  /// [TalkPose.tailSway] in [_design] units.
  static const double _swayUnits = 5.5;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final pose = _pose.value;
    final k = math.min(size.width / _design.width, size.height / _design.height);

    canvas..save()
    ..translate(
      (size.width - _design.width * k) / 2,
      (size.height - _design.height * k) / 2,
    )
    ..scale(k);

    _paintTail(canvas, pose);
    _paintTrunk(canvas, pose);
    _paintLegs(canvas);
    _paintHead(canvas, pose);

    canvas.restore();
  }

  /// The character color faded toward the surface by [t] — 1 is the color
  /// itself, 0 is the bare surface.
  Color _fill(double t) => Color.lerp(surface, color, t) ?? color;

  Paint get _outline => Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.4;

  void _paintTail(Canvas canvas, TalkPose pose) {
    final k = pose.tailSway * _swayUnits;
    final path = Path()
      ..moveTo(126, 68)
      ..cubicTo(144, 70 + k * 0.3, 151, 56 + k, 141, 46 + k * 1.3)
      ..cubicTo(136, 41 + k * 1.5, 129, 43 + k * 1.6, 128, 48 + k * 1.6);

    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..strokeCap = StrokeCap.round,
    );
  }

  void _paintTrunk(Canvas canvas, TalkPose pose) {
    canvas..save()
    // Breathing stretches the trunk vertically about the belly line. The
    // legs are painted outside this transform on purpose — a stretching paw
    // is the fastest way to make a drawn animal look like rubber.
    ..translate(86, 78)
    ..scale(1, pose.bodyBreath)
    ..translate(-86, -78);

    final fill = Paint()..color = _fill(0.62);

    canvas..save()
    ..translate(86, 70)
    ..rotate(-5 * math.pi / 180)
    ..translate(-86, -70);
    final torso = Rect.fromCenter(center: const Offset(86, 70), width: 76, height: 32);
    canvas..drawOval(torso, fill)
    ..drawOval(torso, _outline)
    ..restore();

    final haunch = Rect.fromCenter(center: const Offset(114, 65), width: 32, height: 30);
    canvas..drawOval(haunch, fill)
    ..drawOval(haunch, _outline)
    ..restore();
  }

  void _paintLegs(Canvas canvas) {
    // Far foreleg first and a shade deeper, so the near one reads as closer.
    _paintLeg(canvas, const Offset(58, 80), 34, 10, 4, _fill(0.46), 1.8);
    _paintLeg(canvas, const Offset(52, 87), 36, 11, 6, _fill(0.30), 2);
    _paintLeg(canvas, const Offset(124, 79), 18, 10, 0, _fill(0.30), 2);
  }

  void _paintLeg(
    Canvas canvas,
    Offset center,
    double width,
    double height,
    double degrees,
    Color fill,
    double strokeWidth,
  ) {
    canvas..save()
    ..translate(center.dx, center.dy)
    ..rotate(degrees * math.pi / 180)
    ..translate(-center.dx, -center.dy);

    final rect = Rect.fromCenter(center: center, width: width, height: height);
    canvas..drawOval(rect, Paint()..color = fill)
    ..drawOval(rect, _outline..strokeWidth = strokeWidth)
    ..restore();
  }

  void _paintHead(Canvas canvas, TalkPose pose) {
    canvas..save()
    ..translate(_headAnchor.dx, _headAnchor.dy + pose.headBob * _bobUnits)
    ..rotate(pose.tiltDegrees * math.pi / 180)
    ..scale(_headScale * pose.scale)
    // The face below is written around the head's own center, (50, 54).
    ..translate(-50, -54);

    _paintEars(canvas, pose);
    canvas..drawCircle(const Offset(50, 54), 30, Paint()..color = _fill(0.45))
    ..drawCircle(const Offset(50, 54), 30, _outline..strokeWidth = 3);
    _paintEyes(canvas, pose);
    _paintNose(canvas);
    _paintMouth(canvas, pose);
    _paintWhiskers(canvas, pose);

    canvas.restore();
  }

  void _paintEars(Canvas canvas, TalkPose pose) {
    _paintEar(
      canvas,
      pose,
      outer: const [Offset(29, 34), Offset(33, 13), Offset(49, 26)],
      inner: const [Offset(33, 32), Offset(35, 20), Offset(44, 28)],
      pivot: const Offset(35, 34),
      sign: -1,
    );
    _paintEar(
      canvas,
      pose,
      outer: const [Offset(71, 34), Offset(67, 13), Offset(51, 26)],
      inner: const [Offset(67, 32), Offset(65, 20), Offset(56, 28)],
      pivot: const Offset(65, 34),
      sign: 1,
    );
  }

  void _paintEar(
    Canvas canvas,
    TalkPose pose, {
    required List<Offset> outer,
    required List<Offset> inner,
    required Offset pivot,
    required double sign,
  }) {
    canvas..save()
    ..translate(pivot.dx, pivot.dy)
    ..rotate(sign * pose.earTwistDegrees * math.pi / 180)
    ..translate(-pivot.dx, -pivot.dy)

    ..drawPath(_polygon(outer), Paint()..color = color)
    ..drawPath(_polygon(inner), Paint()..color = _fill(0.18))

    ..restore();
  }

  Path _polygon(List<Offset> points) {
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    return path..close();
  }

  void _paintEyes(Canvas canvas, TalkPose pose) {
    final paint = Paint()..color = ink;
    // A blink is the eyelid coming down, not the eye shrinking: the width
    // stays put and only the height collapses.
    final height = math.max(0.7, 5.2 * pose.eyeOpen);

    for (final cx in const [39.0, 61.0]) {
      canvas.drawOval(
        Rect.fromCenter(center: Offset(cx, 49), width: 8.4, height: height * 2),
        paint,
      );
      if (pose.eyeOpen > 0.5) {
        canvas.drawCircle(Offset(cx + 1.6, 47), 1.4, Paint()..color = surface);
      }
    }
  }

  void _paintNose(Canvas canvas) => canvas.drawPath(
    _polygon(const [Offset(46.5, 59), Offset(53.5, 59), Offset(50, 62.5)]),
    Paint()..color = Color.lerp(color, ink, 0.35) ?? color,
  );

  void _paintMouth(Canvas canvas, TalkPose pose) {
    final open = pose.mouthOpen;
    final mouth = Rect.fromCenter(
      center: const Offset(50, 68),
      width: (5 + 1.6 * open) * 2,
      height: (0.9 + 6.2 * open) * 2,
    );
    canvas.drawOval(mouth, Paint()..color = ink);

    final tongue = math.max(0.0, (open - 0.35) * 5);
    if (tongue <= 0) return;

    canvas..save()
    // Clipped to the mouth so the tongue can never spill onto the chin.
    ..clipPath(Path()..addOval(mouth))
    ..drawOval(
      Rect.fromCenter(
        center: Offset(50, 68 + 2.4 * open),
        width: 6,
        height: tongue * 2,
      ),
      Paint()..color = Color.lerp(color, const Color(0xFFE08B9B), 0.75) ?? color,
    )
    ..restore();
  }

  void _paintWhiskers(Canvas canvas, TalkPose pose) {
    final paint = Paint()
      ..color = (Color.lerp(color, ink, 0.35) ?? color).withValues(alpha: 0.75)
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;

    canvas..save()
    // Whiskers lag behind the ears — a quarter of the twist, same sign, so
    // the whole muzzle reads as one movement.
    ..translate(50, 62)
    ..rotate(pose.earTwistDegrees * 0.25 * math.pi / 180)
    ..translate(-50, -62);

    for (final side in const [-1.0, 1.0]) {
      for (var i = 0; i < 2; i++) {
        canvas.drawLine(
          Offset(50 + side * 7, 62 + i * 4),
          Offset(50 + side * 26, 58 + i * 8),
          paint,
        );
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(CatFacePainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.surface != surface ||
      oldDelegate.ink != ink ||
      oldDelegate._pose != _pose;

  /// The cat is decorative: `CharacterAvatar` already announces the seat's
  /// name and state, and a second node here would only repeat it.
  @override
  bool shouldRebuildSemantics(CatFacePainter oldDelegate) => false;
}
