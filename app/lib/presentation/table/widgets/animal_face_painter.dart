import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:roundtablezoo/presentation/table/widgets/animal_shape.dart';
import 'package:roundtablezoo/presentation/table/widgets/talk_pose.dart';

/// Draws one animal — whichever [AnimalShape] it is handed — for one
/// [TalkPose].
///
/// Vector, not a raster asset or a Lottie file, for the same reason the
/// table surface is a `CustomPainter` (`specs/006-table-surface-render`): it
/// scales to any seat size and takes its colors from the character config
/// and the current `ColorScheme`, so it needs no light/dark variants and no
/// licensing.
///
/// One painter for every animal on purpose. A cat lying on its side and a
/// sitting dog differ only in the numbers inside [AnimalShape] — the
/// drawing steps (trunk, legs, head, face) are the same, and so is all of
/// the movement, which arrives already solved in [TalkPose].
class AnimalFacePainter extends CustomPainter {
  AnimalFacePainter({
    required ValueListenable<TalkPose> pose,
    required this.shape,
    required this.mirrored,
    required this.color,
    required this.surface,
    required this.ink,
  }) : _pose = pose,
       super(repaint: pose);

  final AnimalShape shape;

  /// Draw the animal facing right instead of left. Applied to the whole
  /// figure, after the fit — every shape in [AnimalShape] is authored
  /// facing left and mirrored here rather than duplicated.
  final bool mirrored;

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

  /// [TalkPose.headBob] is a fraction of the avatar's size; this turns it
  /// into [AnimalShape.design] units.
  static const double _bobUnits = 70;

  /// [TalkPose.tailSway] in [AnimalShape.design] units.
  static const double _swayUnits = 5.5;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final pose = _pose.value;
    const design = AnimalShape.design;
    final k = math.min(size.width / design.width, size.height / design.height);

    canvas
      ..save()
      ..translate(
        (size.width - design.width * k) / 2,
        (size.height - design.height * k) / 2,
      )
      ..scale(k);

    if (mirrored) {
      // Flip about the design space's own middle, after the fit: every
      // shape is authored facing left, and a seat on the table's left half
      // has to face the other way.
      canvas
        ..translate(design.width, 0)
        ..scale(-1, 1);
    }

    _paintTail(canvas, pose);
    for (final leg in shape.legs.where((leg) => leg.behind)) {
      _paintPart(canvas, leg);
    }
    _paintTrunk(canvas, pose);
    for (final leg in shape.legs.where((leg) => !leg.behind)) {
      _paintPart(canvas, leg);
    }
    _paintHead(canvas, pose);

    canvas.restore();
  }

  /// The character color faded toward the surface by [tone] — 1 is the
  /// color itself, 0 is the bare surface.
  Color _fill(double tone) => Color.lerp(surface, color, tone) ?? color;

  Paint _outline([double strokeWidth = 2.4]) => Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = strokeWidth;

  void _paintTail(Canvas canvas, TalkPose pose) {
    final tail = shape.tail;
    final k = pose.tailSway * _swayUnits;
    final x = tail.from.dx;
    final y = tail.from.dy;
    final length = tail.length == 0 ? 32.0 : tail.length;

    canvas.save();
    if (tail.rotationDegrees != 0) {
      canvas
        ..translate(x, y)
        ..rotate(tail.rotationDegrees * math.pi / 180)
        ..translate(-x, -y);
    }

    // A tapering tail is a mass and gets filled; the other two are lines
    // and get stroked.
    var filled = false;
    final path = Path()..moveTo(x, y);

    switch (tail.style) {
      case TailStyle.taper:
        // A crocodile's tail is a wedge that narrows to the tip, which a
        // stroke of constant width cannot give.
        filled = true;
        path
          ..reset()
          ..moveTo(x, y - 10)
          ..quadraticBezierTo(x + length / 2, y - 12 + k * 0.6, x + length, y - 4 + k * 1.4)
          ..quadraticBezierTo(x + length / 2, y + 6 + k * 0.6, x, y + 10)
          ..close();
      case TailStyle.flat:
        // Sweeps sideways rather than upward; `rise` decides whether the
        // tip lifts (a cat's) or hangs (a hippo's stub).
        path.cubicTo(
          x + length * 0.37,
          y + 3 + k * 0.3,
          x + length * 0.75,
          y + 2 + k * 0.7,
          x + length,
          y + tail.rise + k * 1.1,
        );
      case TailStyle.curl:
        final f = length / 32;
        path
          ..cubicTo(
            x + 18 * f,
            y + (2 + k * 0.3) * f,
            x + 25 * f,
            y + (-12 + k) * f,
            x + 15 * f,
            y + (-22 + k * 1.3) * f,
          )
          ..cubicTo(
            x + 10 * f,
            y + (-27 + k * 1.5) * f,
            x + 3 * f,
            y + (-25 + k * 1.6) * f,
            x + 2 * f,
            y + (-20 + k * 1.6) * f,
          );
    }

    if (filled) {
      canvas
        ..drawPath(path, Paint()..color = _fill(0.62))
        ..drawPath(path, _outline());
    } else {
      canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = tail.width
          ..strokeCap = StrokeCap.round,
      );
    }

    canvas.restore();
  }

  void _paintTrunk(Canvas canvas, TalkPose pose) {
    canvas
      ..save()
      // Breathing stretches the trunk about the line the animal rests on. The
      // legs are painted outside this transform on purpose — a stretching paw
      // is the fastest way to make a drawn animal look like rubber.
      ..translate(0, shape.breathAnchorY)
      ..scale(1, pose.bodyBreath)
      ..translate(0, -shape.breathAnchorY);

    _paintPart(canvas, shape.torso);
    final haunch = shape.haunch;
    if (haunch != null) _paintPart(canvas, haunch);
    for (final spike in shape.ridge) {
      final path = _polygon([
        Offset(spike.dx - 5, spike.dy + 5),
        Offset(spike.dx, spike.dy - 5),
        Offset(spike.dx + 5, spike.dy + 5),
      ]);
      canvas
        ..drawPath(path, Paint()..color = _fill(0.62))
        ..drawPath(path, _outline(2));
    }

    canvas.restore();
  }

  void _paintPart(Canvas canvas, AnimalPart part) {
    canvas.save();
    if (part.rotationDegrees != 0) {
      canvas
        ..translate(part.center.dx, part.center.dy)
        ..rotate(part.rotationDegrees * math.pi / 180)
        ..translate(-part.center.dx, -part.center.dy);
    }

    canvas
      ..drawOval(part.rect, Paint()..color = _fill(part.tone))
      ..drawOval(part.rect, _outline(part.strokeWidth))
      ..restore();
  }

  void _paintHead(Canvas canvas, TalkPose pose) {
    canvas
      ..save()
      ..translate(shape.headAnchor.dx, shape.headAnchor.dy + pose.headBob * _bobUnits)
      ..rotate(pose.tiltDegrees * math.pi / 180)
      ..scale(shape.headScale * pose.scale)
      // The face below is written around the head's own center, (50, 54).
      ..translate(-50, -54);

    // Pointed and round ears belong behind the skull; floppy ones hang over
    // its sides and have to be painted after it. A crocodile has neither.
    if (shape.ears == EarStyle.pointed || shape.ears == EarStyle.round) {
      _paintEars(canvas, pose);
    }
    canvas
      ..drawCircle(const Offset(50, 54), shape.skullRadius, Paint()..color = _fill(0.45))
      ..drawCircle(const Offset(50, 54), shape.skullRadius, _outline(3));
    if (shape.ears == EarStyle.floppy) _paintEars(canvas, pose);

    final snout = shape.snout;
    if (snout != null) _paintPart(canvas, snout);
    for (final nostril in shape.nostrils) {
      canvas.drawOval(
        Rect.fromCenter(center: nostril, width: 6.8, height: 5.2),
        Paint()..color = Color.lerp(color, ink, 0.35) ?? color,
      );
    }

    final jaw = shape.jaw;
    if (jaw != null) _paintJaw(canvas, pose, jaw);

    _paintEyes(canvas, pose);
    if (shape.nose != NoseStyle.none) _paintNose(canvas);
    if (shape.mouth != null) _paintMouth(canvas, pose);
    if (shape.whiskers) _paintWhiskers(canvas, pose);

    canvas.restore();
  }

  void _paintJaw(Canvas canvas, TalkPose pose, JawShape jaw) {
    final teeth = Paint()..color = surface;

    canvas
      ..save()
      ..translate(jaw.hinge.dx, jaw.hinge.dy)
      // Negative degrees drop the muzzle's front edge — see [JawShape].
      ..rotate((jaw.restDegrees + pose.mouthOpen * jaw.swingDegrees) * math.pi / 180)
      ..translate(-jaw.hinge.dx, -jaw.hinge.dy);

    final lower = Path()
      ..moveTo(43, 63)
      ..lineTo(3, 63)
      ..quadraticBezierTo(-6, 63, -6, 69)
      ..quadraticBezierTo(-6, 75, 4, 75)
      ..lineTo(43, 75)
      ..close();
    canvas
      ..drawPath(lower, Paint()..color = _fill(0.5))
      ..drawPath(lower, _outline());
    for (final x in const [5.0, 15.0, 25.0, 35.0]) {
      canvas.drawPath(_polygon([Offset(x - 2.6, 63), Offset(x + 2.6, 63), Offset(x, 57.5)]), teeth);
    }
    canvas.restore();

    // The upper jaw is part of the skull and never moves.
    final upper = Path()
      ..moveTo(43, 48)
      ..lineTo(1, 48)
      ..quadraticBezierTo(-9, 48, -9, 55)
      ..quadraticBezierTo(-9, 62, 1, 62)
      ..lineTo(43, 62)
      ..close();
    canvas
      ..drawPath(upper, Paint()..color = _fill(0.62))
      ..drawPath(upper, _outline());
    for (final x in const [1.0, 11.0, 21.0, 31.0]) {
      canvas.drawPath(_polygon([Offset(x - 2.6, 61), Offset(x + 2.6, 61), Offset(x, 67)]), teeth);
    }

    // One nostril, not two: from the side only the near one shows.
    canvas.drawCircle(
      const Offset(-3, 53),
      1.6,
      Paint()..color = Color.lerp(color, ink, 0.35) ?? color,
    );
  }

  void _paintEars(Canvas canvas, TalkPose pose) {
    // Each ear style swings about a different point: a pointed ear at its
    // base, a floppy one where it hangs from, and a round one about the
    // skull — rotating a circle about its own center shows nothing.
    final (left, right, pivotY) = switch (shape.ears) {
      EarStyle.pointed => (35.0, 65.0, 34.0),
      EarStyle.floppy => (30.0, 70.0, 27.0),
      EarStyle.round => (34.0, 66.0, 40.0),
      EarStyle.none => (0.0, 0.0, 0.0),
    };

    _paintEar(canvas, pose, pivot: Offset(left, pivotY), sign: -1);
    _paintEar(canvas, pose, pivot: Offset(right, pivotY), sign: 1);
  }

  void _paintEar(Canvas canvas, TalkPose pose, {required Offset pivot, required double sign}) {
    canvas
      ..save()
      ..translate(pivot.dx, pivot.dy)
      ..rotate(sign * pose.earTwistDegrees * math.pi / 180)
      ..translate(-pivot.dx, -pivot.dy);

    final left = sign < 0;
    switch (shape.ears) {
      case EarStyle.pointed:
        final outer = left
            ? const [Offset(29, 34), Offset(33, 13), Offset(49, 26)]
            : const [Offset(71, 34), Offset(67, 13), Offset(51, 26)];
        final inner = left
            ? const [Offset(33, 32), Offset(35, 20), Offset(44, 28)]
            : const [Offset(67, 32), Offset(65, 20), Offset(56, 28)];
        canvas
          ..drawPath(_polygon(outer), Paint()..color = color)
          ..drawPath(_polygon(inner), Paint()..color = _fill(0.18));
      case EarStyle.round:
        // Tiny ears peeking over the skull.
        final center = Offset(left ? 34 : 66, 26);
        canvas
          ..drawCircle(center, 8, Paint()..color = _fill(0.85))
          ..drawCircle(center, 8, _outline(2));
      case EarStyle.none:
        break;
      case EarStyle.floppy:
        final path = Path();
        if (left) {
          path
            ..moveTo(32, 27)
            ..cubicTo(15, 25, 11, 50, 19, 64)
            ..cubicTo(25, 75, 38, 71, 37, 58)
            ..cubicTo(36, 45, 38, 33, 32, 27);
        } else {
          path
            ..moveTo(68, 27)
            ..cubicTo(85, 25, 89, 50, 81, 64)
            ..cubicTo(75, 75, 62, 71, 63, 58)
            ..cubicTo(64, 45, 62, 33, 68, 27);
        }
        path.close();
        canvas
          ..drawPath(path, Paint()..color = _fill(0.85))
          ..drawPath(path, _outline(2));
      case EarStyle.none:
        // TODO: Handle this case.
        throw UnimplementedError();
    }

    canvas.restore();
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
    final y = shape.eyesY;

    for (final cx in const [39.0, 61.0]) {
      if (shape.eyeBumps) {
        canvas
          ..drawCircle(Offset(cx, y - 1), 7.5, Paint()..color = _fill(0.45))
          ..drawCircle(Offset(cx, y - 1), 7.5, _outline(2));
      }
      canvas.drawOval(
        Rect.fromCenter(center: Offset(cx, y), width: 8.4, height: height * 2),
        paint,
      );
      if (pose.eyeOpen > 0.5) {
        canvas.drawCircle(Offset(cx + 1.6, y - 2), 1.4, Paint()..color = surface);
      }
    }
  }

  void _paintNose(Canvas canvas) {
    final paint = Paint()..color = Color.lerp(color, ink, 0.35) ?? color;
    switch (shape.nose) {
      case NoseStyle.triangle:
        canvas.drawPath(
          _polygon(const [Offset(46.5, 59), Offset(53.5, 59), Offset(50, 62.5)]),
          paint,
        );
      case NoseStyle.round:
        canvas.drawOval(
          Rect.fromCenter(center: const Offset(50, 64), width: 11, height: 8.4),
          paint,
        );
      case NoseStyle.none:
        break;
    }
  }

  void _paintMouth(Canvas canvas, TalkPose pose) {
    final open = pose.mouthOpen;
    final spec = shape.mouth!;
    final mouth = Rect.fromCenter(
      center: Offset(50, spec.y),
      width: (spec.width + 1.6 * open) * 2,
      height: (0.9 + spec.openHeight * open) * 2,
    );
    canvas.drawOval(mouth, Paint()..color = ink);

    final tongue = math.max(0.0, (open - 0.35) * 5);
    if (tongue <= 0) return;

    canvas
      ..save()
      // Clipped to the mouth so the tongue can never spill onto the chin.
      ..clipPath(Path()..addOval(mouth))
      ..drawOval(
        Rect.fromCenter(center: Offset(50, spec.y + 2.4 * open), width: 6, height: tongue * 2),
        Paint()..color = Color.lerp(color, const Color(0xFFE08B9B), 0.75) ?? color,
      )
      ..restore();
  }

  void _paintWhiskers(Canvas canvas, TalkPose pose) {
    final paint = Paint()
      ..color = (Color.lerp(color, ink, 0.35) ?? color).withValues(alpha: 0.75)
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;

    canvas
      ..save()
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
  bool shouldRepaint(AnimalFacePainter oldDelegate) =>
      oldDelegate.shape != shape ||
      oldDelegate.mirrored != mirrored ||
      oldDelegate.color != color ||
      oldDelegate.surface != surface ||
      oldDelegate.ink != ink ||
      oldDelegate._pose != _pose;

  /// The animal is decorative: `CharacterAvatar` already announces the
  /// seat's name and state, and a second node here would only repeat it.
  @override
  bool shouldRebuildSemantics(AnimalFacePainter oldDelegate) => false;
}
