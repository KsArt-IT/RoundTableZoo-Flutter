import 'package:flutter/material.dart';
import 'package:roundtablezoo/domain/value_objects/face_shape.dart';

/// How one animal's ears are built. Not a cosmetic flag: pointed ears are
/// painted *behind* the head, floppy ones hang over its sides and so are
/// painted in front of it — and a crocodile has none at all.
enum EarStyle { pointed, floppy, none }

/// A tail that curls upward (a cat's, at rest on its side), one that lies
/// on the ground and sweeps (a sitting dog's), or one drawn as a filled
/// wedge because it is a mass rather than a line (a crocodile's).
enum TailStyle { curl, flat, taper }

enum NoseStyle { triangle, round, none }

/// One rounded part of a body — torso, haunch, leg or paw.
@immutable
class AnimalPart {
  const AnimalPart({
    required this.center,
    required this.size,
    required this.tone,
    this.rotationDegrees = 0,
    this.strokeWidth = 2.4,
  });

  final Offset center;
  final Size size;

  /// How far the fill is pushed from the seat's surface toward the
  /// character's color: 1 is the color itself, 0 the bare surface. Parts
  /// further from the viewer get a higher tone, which is the only depth
  /// cue a flat drawing has.
  final double tone;

  final double rotationDegrees;
  final double strokeWidth;

  Rect get rect => Rect.fromCenter(center: center, width: size.width, height: size.height);
}

@immutable
class TailShape {
  const TailShape({
    required this.style,
    required this.from,
    required this.width,
    this.gain = 1,
    this.length = 0,
  });

  final TailStyle style;
  final Offset from;

  /// Stroke width. Ignored by [TailStyle.taper], which is filled.
  final double width;

  /// Multiplies both the speed and the width of the sweep — a dog's tail
  /// works harder than a cat's.
  final double gain;

  /// [TailStyle.taper] only: how far the wedge reaches from [from].
  final double length;
}

@immutable
class MouthShape {
  const MouthShape({required this.y, required this.width, required this.openHeight});

  final double y;
  final double width;

  /// How far the mouth opens at `mouthOpen == 1`.
  final double openHeight;
}

/// A muzzle built as two slabs on a hinge, for an animal whose mouth cannot
/// be an ellipse.
@immutable
class JawShape {
  const JawShape({
    required this.hinge,
    required this.restDegrees,
    required this.swingDegrees,
  });

  /// The corner where the two jaws meet. Putting it anywhere inside the
  /// lower slab swings that slab's own back edge up into the skull.
  final Offset hinge;

  /// Angle the closed jaw already sits at, so it still reads as a jaw and
  /// not as a slab tucked under the skull.
  final double restDegrees;

  /// Added at `mouthOpen == 1`.
  ///
  /// **Both angles are negative on purpose.** The muzzle points left, and a
  /// positive (clockwise) rotation lifts everything left of the hinge — so
  /// a positive swing closes the mouth into the skull instead of opening
  /// it. This sign is the whole reason the jaw is worth a test.
  final double swingDegrees;
}

/// Everything that differs between the animals drawn by
/// `AnimalFacePainter` — and nothing else. The pose solver never sees this
/// type: species is geometry, behaviour is shared.
///
/// Body coordinates live in [design]; the head keeps a 0..100 space of its
/// own, placed by [headAnchor]/[headScale], so every animal reuses the same
/// face coordinates (a skull centered on (50, 54), eyes at x = 39 and 61).
@immutable
class AnimalShape {
  const AnimalShape({
    required this.headAnchor,
    required this.headScale,
    required this.torso,
    required this.haunch,
    required this.legs,
    required this.tail,
    required this.breathAnchorY,
    required this.ears,
    required this.nose,
    required this.whiskers,
    this.mouth,
    this.jaw,
    this.snout,
    this.skullRadius = 30,
    this.eyesY = 49,
    this.eyeBumps = false,
    this.ridge = const [],
  }) : assert(
         (mouth == null) != (jaw == null),
         'an animal has either a mouth or a jaw, never both and never neither',
       );

  /// The space bodies are drawn in: wider than tall, because all three
  /// animals are down on the ground rather than standing.
  static const Size design = Size(158, 112);

  final Offset headAnchor;
  final double headScale;

  /// The skull is sized apart from [headScale] so shrinking it doesn't drag
  /// the eyes and the muzzle — which live in the same head space — along
  /// with it.
  final double skullRadius;

  final AnimalPart torso;
  final AnimalPart haunch;

  /// Painted back to front, over the torso: the nearest limb comes last.
  final List<AnimalPart> legs;

  /// Spikes along the spine, in body coordinates. Painted with the trunk,
  /// so they breathe with it.
  final List<Offset> ridge;

  final TailShape tail;

  /// The line breathing stretches the trunk about — a lying animal's belly,
  /// a sitting one's ground. Stretching about the center instead makes a
  /// seated figure bob up and down off its own seat.
  final double breathAnchorY;

  final EarStyle ears;
  final NoseStyle nose;

  /// Where the eyes sit in head coordinates. A crocodile keeps them on top
  /// of the skull rather than on its face.
  final double eyesY;

  /// Brow bumps under the eyes — half of what makes a green oval read as a
  /// crocodile.
  final bool eyeBumps;

  /// An ellipse mouth, for animals that have one. Mutually exclusive with
  /// [jaw].
  final MouthShape? mouth;

  /// Two slabs on a hinge, for animals that don't. Mutually exclusive with
  /// [mouth].
  final JawShape? jaw;

  final bool whiskers;

  /// A drawn-out muzzle, for animals whose face isn't flat.
  final AnimalPart? snout;

  static AnimalShape of(FaceShape face) => switch (face) {
    FaceShape.cat => cat,
    FaceShape.dog => dog,
    FaceShape.crocodile => crocodile,
  };

  /// Lying on its side, tail curling up behind it.
  static const AnimalShape cat = AnimalShape(
    headAnchor: Offset(42, 40),
    headScale: 0.82,
    torso: AnimalPart(center: Offset(86, 70), size: Size(76, 32), rotationDegrees: -5, tone: 0.62),
    haunch: AnimalPart(center: Offset(114, 65), size: Size(32, 30), tone: 0.62),
    legs: [
      AnimalPart(
        center: Offset(58, 80),
        size: Size(34, 10),
        rotationDegrees: 4,
        tone: 0.46,
        strokeWidth: 1.8,
      ),
      AnimalPart(
        center: Offset(52, 87),
        size: Size(36, 11),
        rotationDegrees: 6,
        tone: 0.30,
        strokeWidth: 2,
      ),
      AnimalPart(center: Offset(124, 79), size: Size(18, 10), tone: 0.30, strokeWidth: 2),
    ],
    tail: TailShape(style: TailStyle.curl, from: Offset(126, 68), width: 8),
    breathAnchorY: 78,
    ears: EarStyle.pointed,
    nose: NoseStyle.triangle,
    mouth: MouthShape(y: 68, width: 5, openHeight: 6.2),
    whiskers: true,
  );

  /// Sitting: forelegs straight, body and head up, tail flat on the ground.
  static const AnimalShape dog = AnimalShape(
    headAnchor: Offset(74, 26),
    headScale: 0.78,
    // Reaches down to the paws' midline. Ending it just above them left the
    // outline hanging in the gap with nothing to sit on.
    torso: AnimalPart(center: Offset(84, 65), size: Size(38, 64), rotationDegrees: 8, tone: 0.62),
    haunch: AnimalPart(center: Offset(104, 74), size: Size(42, 44), tone: 0.62),
    legs: [
      // Outer foreleg and its paw, then the tucked hind paw, then the inner
      // foreleg — the dog is turned inward, so the inner leg is the near
      // one and has to finish on top.
      AnimalPart(
        center: Offset(70, 80),
        size: Size(13, 34),
        rotationDegrees: -2,
        tone: 0.46,
        strokeWidth: 1.8,
      ),
      AnimalPart(center: Offset(71, 97), size: Size(17, 9), tone: 0.46, strokeWidth: 1.8),
      AnimalPart(center: Offset(93, 96), size: Size(20, 10), tone: 0.30, strokeWidth: 2),
      AnimalPart(
        center: Offset(78, 80),
        size: Size(12, 34),
        rotationDegrees: 3,
        tone: 0.30,
        strokeWidth: 2,
      ),
      AnimalPart(center: Offset(79, 97), size: Size(16, 9), tone: 0.30, strokeWidth: 2),
    ],
    tail: TailShape(style: TailStyle.flat, from: Offset(118, 92), width: 10, gain: 1.6),
    breathAnchorY: 96,
    ears: EarStyle.floppy,
    nose: NoseStyle.round,
    mouth: MouthShape(y: 76, width: 5.5, openHeight: 6),
    whiskers: false,
    snout: AnimalPart(center: Offset(50, 71), size: Size(32, 24), tone: 0.28, strokeWidth: 2),
  );

  /// Flat on the ground: long low body with a ridged spine, one pair of
  /// splayed legs, a tapering tail and a hinged muzzle.
  static const AnimalShape crocodile = AnimalShape(
    headAnchor: Offset(44, 58),
    headScale: 0.72,
    // A crocodile's skull is only the back of its head — the muzzle in
    // front does the rest, so the circle is far smaller than a cat's.
    skullRadius: 25,
    torso: AnimalPart(center: Offset(86, 76), size: Size(68, 30), rotationDegrees: -2, tone: 0.62),
    haunch: AnimalPart(center: Offset(110, 78), size: Size(22, 20), tone: 0.62),
    // One pair of legs, not two: an animal this low to the ground shows the
    // near side only, and a far pair just muddied the silhouette. The
    // foreleg reaches past the body's leading edge, the hind one past the
    // tail's base.
    legs: [
      AnimalPart(center: Offset(56, 90), size: Size(26, 10), tone: 0.30, strokeWidth: 2),
      AnimalPart(center: Offset(119, 90), size: Size(26, 10), tone: 0.30, strokeWidth: 2),
    ],
    // Stops where the body stops: a spike over the tail would stand still
    // while the tail swept out from under it.
    ridge: [Offset(72, 61), Offset(84, 59), Offset(96, 59), Offset(108, 62)],
    tail: TailShape(style: TailStyle.taper, from: Offset(118, 76), width: 0, gain: 0.8, length: 36),
    breathAnchorY: 88,
    ears: EarStyle.none,
    nose: NoseStyle.none,
    eyesY: 38,
    eyeBumps: true,
    jaw: JawShape(hinge: Offset(43, 63), restDegrees: -5, swingDegrees: -28),
    whiskers: false,
  );
}
