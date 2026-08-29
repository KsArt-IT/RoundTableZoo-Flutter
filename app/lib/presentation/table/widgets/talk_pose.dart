import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:roundtablezoo/presentation/table/widgets/character_visual_state.dart';

/// One frame of a character's face, in units that don't depend on how big
/// the avatar is drawn: [headBob] is a fraction of the avatar's size, angles
/// are degrees, the rest are 0..1 fractions.
///
/// Deliberately a plain immutable class, not `@freezed`: it is created ~60
/// times per second and never serialized, so `copyWith`/`fromJson` would be
/// dead weight — and the animation layer stays free of code generation.
@immutable
class TalkPose {
  const TalkPose({
    this.mouthOpen = 0,
    this.headBob = 0,
    this.tiltDegrees = 0,
    this.scale = 1,
    this.earTwistDegrees = 0,
    this.eyeOpen = 1,
    this.tailSway = 0,
    this.bodyBreath = 1,
  });

  /// The resting face: mouth shut, eyes open, no offset. What a seat shows
  /// when it is idle, and what "reduce motion" freezes every state to
  /// (FR-033a).
  static const TalkPose still = TalkPose();

  /// 0 — shut, 1 — widest this character's mouth opens.
  final double mouthOpen;

  /// Vertical offset as a fraction of the avatar's size; negative is up.
  final double headBob;

  final double tiltDegrees;
  final double scale;

  /// Rotation of both ears, mirrored: positive turns them outward.
  final double earTwistDegrees;

  /// 0 — eyelid shut, 1 — fully open.
  final double eyeOpen;

  /// Sideways sweep of the tail, roughly -1.5..1.5. Its own rhythm per
  /// state rather than the mouth's: the tail is the loudest thing on the
  /// avatar and the easiest to read at seat size.
  final double tailSway;

  /// Vertical scale of the lying body, ~0.99..1.01. The head nods, the body
  /// only breathes — moving both as one block reads as a bobbing toy.
  final double bodyBreath;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TalkPose &&
          other.mouthOpen == mouthOpen &&
          other.headBob == headBob &&
          other.tiltDegrees == tiltDegrees &&
          other.scale == scale &&
          other.earTwistDegrees == earTwistDegrees &&
          other.eyeOpen == eyeOpen &&
          other.tailSway == tailSway &&
          other.bodyBreath == bodyBreath;

  @override
  int get hashCode => Object.hash(
    mouthOpen,
    headBob,
    tiltDegrees,
    scale,
    earTwistDegrees,
    eyeOpen,
    tailSway,
    bodyBreath,
  );

  @override
  String toString() =>
      'TalkPose(mouthOpen: $mouthOpen, headBob: $headBob, tiltDegrees: $tiltDegrees, '
      'scale: $scale, earTwistDegrees: $earTwistDegrees, eyeOpen: $eyeOpen, '
      'tailSway: $tailSway, bodyBreath: $bodyBreath)';
}

/// Turns "which state, how strongly, how long ago" into a [TalkPose].
///
/// A pure function of its arguments — same inputs, same face, on every
/// platform and in every test. That is the point of splitting it out of the
/// widget: the *look* of the animation is unit-testable without pumping a
/// single frame, and the widget is left with nothing but a ticker.
///
/// The speaking mouth is deliberately **not** a sine wave. Speech is
/// syllabic: short holds at varying openness separated by closures, not a
/// smooth oscillation — a sine reads as a chewing motion, a stepped envelope
/// reads as talking. Slots are [syllable] long, their target openness (and
/// which of them are silent) comes from a hash of the character's seed, so
/// two animals talking at once are never in lockstep.
abstract final class TalkPoseSolver {
  const TalkPoseSolver._();

  /// One syllable's slot. ~7 per second at the shortest — close to the
  /// upper end of comfortable speech, which is where `flutter_tts` sits for
  /// these characters' `rate`.
  static const Duration syllable = Duration(milliseconds: 145);

  /// Share of slots that stay shut — the pauses between words. Without them
  /// the mouth never fully closes and the effect reads as babbling.
  static const double silentSlotShare = 0.28;

  /// Smallest opening a *sounded* slot gets, so quiet syllables still read
  /// as movement at 72 dp.
  static const double minSoundedOpen = 0.35;

  static const Duration blinkPeriod = Duration(milliseconds: 3400);
  static const Duration blinkDuration = Duration(milliseconds: 130);

  /// How long the one-shot `answered` reaction lasts. Not a loop: it fires
  /// once when the reply lands and then the face settles.
  static const Duration answeredPop = Duration(milliseconds: 620);

  /// Share of a slot spent moving to the new opening; the rest holds it.
  static const double _slotTravel = 0.5;

  static const double _maxBob = 0.035;
  static const double _maxTilt = 3.0;
  static const double _maxEarTwist = 7.0;

  /// [elapsed] is time since the ticker started (continuous across state
  /// changes, so blinking doesn't restart every time a reply lands);
  /// [sinceStateChange] is time since [state] was entered, which only the
  /// one-shot `answered` reaction needs.
  ///
  /// [intensity] is `CharacterReaction.intensity` — clamped here rather than
  /// trusted, because it arrives from the ai-proxy.
  static TalkPose solve({
    required CharacterVisualState state,
    required double intensity,
    required Duration elapsed,
    required Duration sinceStateChange,
    required int seed,
  }) {
    final amp = intensity.clamp(0.0, 1.0).toDouble();
    final t = elapsed.inMicroseconds / Duration.microsecondsPerSecond;

    return switch (state) {
      // A table of four idling animals is the screen's resting state; a
      // permanent breathing loop there would compete with the day text for
      // attention (and never let a frame be the last one). Motion belongs
      // to the character who is doing something.
      CharacterVisualState.idle => TalkPose.still,

      CharacterVisualState.waiting => TalkPose(
        tiltDegrees: 6 + math.sin(t * 1.4) * 1.5,
        earTwistDegrees: math.max(0.0, math.sin(t * 3.2)) * _maxEarTwist,
        eyeOpen: _eyeOpen(elapsed, seed),
        // Waiting is where the tail is most agitated: fast and wide, the
        // one signal that reads before the reply arrives.
        tailSway: math.sin(t * 2.7) * 1.5,
        bodyBreath: _breath(t, resting: true),
      ),

      CharacterVisualState.speaking => () {
        final open = _syllableOpen(elapsed, seed) * amp;
        return TalkPose(
          mouthOpen: open,
          // The nod follows the mouth rather than a clock of its own: heads
          // dip on stressed syllables, and tying the two together is what
          // makes the motion read as one gesture instead of two loops.
          headBob: -_maxBob * open,
          tiltDegrees: math.sin(t * 2.2) * _maxTilt * amp,
          scale: 1 + 0.012 * open,
          earTwistDegrees: math.sin(t * 6.5) * _maxEarTwist * 0.5 * amp,
          eyeOpen: _eyeOpen(elapsed, seed),
          tailSway: math.sin(t * 1.9) * (0.6 + 0.6 * amp),
          bodyBreath: _breath(t, resting: false),
        );
      }(),

      CharacterVisualState.answered => () {
        final span = answeredPop.inMicroseconds;
        final since = sinceStateChange.inMicroseconds;
        if (since >= span) return TalkPose.still;
        // One hump, not a loop: rises and settles back to `still`.
        final k = math.sin(math.pi * (since / span));
        return TalkPose(
          mouthOpen: 0.35 * k,
          headBob: -0.06 * k,
          tiltDegrees: 4 * k,
          scale: 1 + 0.08 * k,
          earTwistDegrees: 6 * k,
          tailSway: math.sin(t * 11) * 1.5 * k,
          bodyBreath: _breath(t, resting: true),
        );
      }(),
    };
  }

  /// `true` while [state] still has frames left to draw — the driver stops
  /// its ticker as soon as this goes `false`, so a settled table schedules
  /// no frames at all (and `pumpAndSettle` in widget tests terminates).
  static bool isAnimated({
    required CharacterVisualState state,
    required Duration sinceStateChange,
  }) => switch (state) {
    CharacterVisualState.idle => false,
    CharacterVisualState.waiting || CharacterVisualState.speaking => true,
    CharacterVisualState.answered => sinceStateChange < answeredPop,
  };

  /// Breathing runs faster while the character talks.
  static double _breath(double t, {required bool resting}) =>
      1 + 0.014 * math.sin(t * (resting ? 1.5 : 3.4));

  static double _syllableOpen(Duration elapsed, int seed) {
    final slot = syllable.inMicroseconds;
    final index = elapsed.inMicroseconds ~/ slot;
    final progress = (elapsed.inMicroseconds % slot) / slot;

    final from = _slotOpen(seed, index - 1);
    final to = _slotOpen(seed, index);

    // The jaw moves during the first half of the slot and *holds* for the
    // second. Interpolating across the whole slot would make the mouth
    // drift continuously between targets — which is exactly the chewing
    // motion a sine gives, only with different numbers. Holding is what
    // makes a silent slot read as a pause instead of a passing zero.
    if (progress >= _slotTravel) return to;
    final f = progress / _slotTravel;
    // Smoothstep across the travelling half: the jaw has mass.
    return from + (to - from) * (f * f * (3 - 2 * f));
  }

  static double _slotOpen(int seed, int index) {
    if (_noise(seed, index * 31 + 7) < silentSlotShare) return 0;
    return minSoundedOpen + (1 - minSoundedOpen) * _noise(seed, index);
  }

  static double _eyeOpen(Duration elapsed, int seed) {
    final period = blinkPeriod.inMicroseconds;
    final cycle = elapsed.inMicroseconds ~/ period;
    // Jitter the blink inside its period, otherwise every character on the
    // table blinks on the same beat.
    final start = (_noise(seed, cycle * 17 + 3) * (period - blinkDuration.inMicroseconds)).round();
    final phase = elapsed.inMicroseconds % period - start;
    if (phase < 0 || phase > blinkDuration.inMicroseconds) return 1;

    final f = phase / blinkDuration.inMicroseconds;
    return 1 - math.sin(math.pi * f) * 0.94;
  }

  /// Deterministic 0..1 hash. `Random(seed)` would be wrong here: the solver
  /// must answer for an arbitrary slot index without having walked the ones
  /// before it (tests jump straight to t = 12 s), which a sequential
  /// generator cannot do.
  static double _noise(int seed, int index) {
    var h = seed * 374761393 + index * 668265263;
    h = (h ^ (h >> 13)) * 1274126177;
    h ^= h >> 16;
    return (h & 0xFFFF) / 0xFFFF;
  }
}
