import 'package:flutter_test/flutter_test.dart';
import 'package:roundtablezoo/presentation/table/widgets/character_visual_state.dart';
import 'package:roundtablezoo/presentation/table/widgets/talk_pose.dart';

TalkPose _pose(
  CharacterVisualState state, {
  double intensity = 1,
  Duration elapsed = Duration.zero,
  Duration? sinceStateChange,
  int seed = 7,
}) => TalkPoseSolver.solve(
  state: state,
  intensity: intensity,
  elapsed: elapsed,
  sinceStateChange: sinceStateChange ?? elapsed,
  seed: seed,
);

/// Samples one state every [step] over [span].
List<TalkPose> _samples(
  CharacterVisualState state, {
  double intensity = 1,
  int seed = 7,
  Duration span = const Duration(seconds: 3),
  Duration step = const Duration(milliseconds: 10),
}) => [
  for (var t = Duration.zero; t < span; t += step)
    _pose(state, intensity: intensity, elapsed: t, seed: seed),
];

void main() {
  group('idle', () {
    test('rests completely still — the table at rest must not compete with the text', () {
      expect(_samples(CharacterVisualState.idle), everyElement(TalkPose.still));
    });

    test('schedules no frames', () {
      expect(
        TalkPoseSolver.isAnimated(
          state: CharacterVisualState.idle,
          sinceStateChange: Duration.zero,
        ),
        isFalse,
      );
    });
  });

  group('speaking', () {
    test('opens the mouth, and never past its bounds', () {
      final open = _samples(CharacterVisualState.speaking).map((p) => p.mouthOpen);

      expect(open.reduce((a, b) => a > b ? a : b), greaterThan(0.6));
      expect(open, everyElement(inInclusiveRange(0, 1)));
    });

    test('is syllabic, not a sine: the mouth shuts fully between words', () {
      final open = _samples(CharacterVisualState.speaking).map((p) => p.mouthOpen).toList();

      // A silent slot closes the mouth completely; a sine wave would only
      // touch zero at isolated instants and never hold there.
      expect(open.where((v) => v == 0).length, greaterThan(10));
    });

    test('amplitude scales linearly with intensity', () {
      final full = _samples(CharacterVisualState.speaking);
      final half = _samples(CharacterVisualState.speaking, intensity: 0.5);

      for (var i = 0; i < full.length; i++) {
        expect(half[i].mouthOpen, closeTo(full[i].mouthOpen / 2, 1e-9));
      }
    });

    test('intensity 0 keeps the mouth shut', () {
      expect(
        _samples(CharacterVisualState.speaking, intensity: 0).map((p) => p.mouthOpen),
        everyElement(0),
      );
    });

    test('intensity from the proxy is clamped, not trusted', () {
      const at = Duration(milliseconds: 640);
      expect(
        _pose(CharacterVisualState.speaking, intensity: 4.2, elapsed: at).mouthOpen,
        _pose(CharacterVisualState.speaking, elapsed: at).mouthOpen,
      );
      expect(
        _pose(CharacterVisualState.speaking, intensity: -1, elapsed: at).mouthOpen,
        0,
      );
    });

    test('the head nods with the mouth rather than on a clock of its own', () {
      for (final pose in _samples(CharacterVisualState.speaking)) {
        expect(pose.headBob <= 0, isTrue);
        expect(pose.mouthOpen == 0, pose.headBob == 0);
      }
    });

    test('two characters speaking at once are not in lockstep', () {
      final catty = _samples(CharacterVisualState.speaking, seed: 1).map((p) => p.mouthOpen);
      final doggy = _samples(CharacterVisualState.speaking, seed: 2).map((p) => p.mouthOpen);

      expect(catty, isNot(orderedEquals(doggy)));
    });

    test('is deterministic — the same moment always draws the same face', () {
      const at = Duration(milliseconds: 12345);
      expect(
        _pose(CharacterVisualState.speaking, elapsed: at),
        _pose(CharacterVisualState.speaking, elapsed: at),
      );
    });

    test('blinks', () {
      final eyes = _samples(
        CharacterVisualState.speaking,
        span: TalkPoseSolver.blinkPeriod * 3,
      ).map((p) => p.eyeOpen);

      expect(eyes.any((v) => v < 0.3), isTrue, reason: 'the eyes never close');
      expect(eyes.where((v) => v == 1).length, greaterThan(eyes.length ~/ 2));
    });
  });

  group('the body under the head', () {
    test('the tail keeps a rhythm of its own, on both sides', () {
      for (final state in [CharacterVisualState.speaking, CharacterVisualState.waiting]) {
        final sway = _samples(state).map((p) => p.tailSway).toList();

        expect(sway.any((v) => v > 0.3), isTrue, reason: '$state: the tail never sweeps right');
        expect(sway.any((v) => v < -0.3), isTrue, reason: '$state: the tail never sweeps left');
        expect(sway, everyElement(inInclusiveRange(-1.6, 1.6)));
      }
    });

    test('the tail sweeps wider the louder the reply', () {
      double widest(double intensity) => _samples(
        CharacterVisualState.speaking,
        intensity: intensity,
      ).map((p) => p.tailSway.abs()).reduce((a, b) => a > b ? a : b);

      expect(widest(1), greaterThan(widest(0.2)));
    });

    test('the body only breathes — it never joins the head\'s nod', () {
      final poses = _samples(CharacterVisualState.speaking);

      expect(poses.map((p) => p.bodyBreath), everyElement(inInclusiveRange(0.98, 1.02)));
      // The nod belongs to the head alone: nothing about the body follows
      // `mouthOpen`, or the whole cat would bob like a toy.
      expect(poses.map((p) => p.bodyBreath).toSet().length, greaterThan(10));
    });
  });

  group('waiting', () {
    test('listens with the head cocked and the mouth shut', () {
      final poses = _samples(CharacterVisualState.waiting);

      expect(poses.map((p) => p.mouthOpen), everyElement(0));
      expect(poses.map((p) => p.tiltDegrees), everyElement(greaterThan(0)));
    });

    test('twitches its ears outward only — never inward', () {
      expect(
        _samples(CharacterVisualState.waiting).map((p) => p.earTwistDegrees),
        everyElement(greaterThanOrEqualTo(0)),
      );
    });
  });

  group('answered', () {
    test('is a single hump that settles, not a loop', () {
      final start = _pose(CharacterVisualState.answered, sinceStateChange: Duration.zero);
      final peak = _pose(
        CharacterVisualState.answered,
        sinceStateChange: TalkPoseSolver.answeredPop ~/ 2,
      );
      final after = _pose(
        CharacterVisualState.answered,
        sinceStateChange: TalkPoseSolver.answeredPop * 2,
      );

      expect(start.scale, closeTo(1, 1e-9));
      expect(peak.scale, greaterThan(1.05));
      expect(peak.headBob, lessThan(0));
      expect(after, TalkPose.still);
    });

    test('stops scheduling frames once it has run its course', () {
      expect(
        TalkPoseSolver.isAnimated(
          state: CharacterVisualState.answered,
          sinceStateChange: TalkPoseSolver.answeredPop ~/ 2,
        ),
        isTrue,
      );
      expect(
        TalkPoseSolver.isAnimated(
          state: CharacterVisualState.answered,
          sinceStateChange: TalkPoseSolver.answeredPop,
        ),
        isFalse,
      );
    });
  });
}
