import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:roundtablezoo/presentation/table/widgets/character_visual_state.dart';
import 'package:roundtablezoo/presentation/table/widgets/talk_pose.dart';

/// Drives one seat's [TalkPose] and hands it to [builder] as a listenable,
/// **not** as a value: the pose changes every frame, and rebuilding the
/// widget subtree 60 times a second to move a mouth would be wasteful.
/// Painters take it as their `repaint` argument and repaint alone;
/// non-painted faces can wrap it in a `ValueListenableBuilder` themselves.
///
/// The ticker stops as soon as [TalkPoseSolver.isAnimated] says the state
/// has no frames left (an idle seat, or an `answered` pop that has run its
/// course). That is not only a battery decision: a permanently scheduled
/// frame would make `tester.pumpAndSettle()` time out in every widget test
/// that renders the table.
class TalkPoseDriver extends StatefulWidget {
  const TalkPoseDriver({
    required this.state,
    required this.intensity,
    required this.seed,
    required this.animate,
    required this.builder,
    super.key,
  });

  final CharacterVisualState state;

  /// `CharacterReaction.intensity`, 0..1 — clamped by the solver.
  final double intensity;

  /// Decorrelates one character's syllables and blinks from another's.
  final int seed;

  /// `false` freezes the face at [TalkPose.still] and starts no ticker at
  /// all — FR-033a's "reduce motion" is a still frame, not a slow loop.
  final bool animate;

  final Widget Function(BuildContext context, ValueListenable<TalkPose> pose) builder;

  @override
  State<TalkPoseDriver> createState() => _TalkPoseDriverState();
}

class _TalkPoseDriverState extends State<TalkPoseDriver> with SingleTickerProviderStateMixin {
  final ValueNotifier<TalkPose> _pose = ValueNotifier<TalkPose>(TalkPose.still);
  late final Ticker _ticker = createTicker(_onTick);

  Duration _elapsed = Duration.zero;
  Duration _stateChangedAt = Duration.zero;

  Duration get _sinceStateChange => _elapsed - _stateChangedAt;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(TalkPoseDriver oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state != widget.state) _stateChangedAt = _elapsed;
    _sync();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _pose.dispose();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    _elapsed = elapsed;
    _pose.value = TalkPoseSolver.solve(
      state: widget.state,
      intensity: widget.intensity,
      elapsed: elapsed,
      sinceStateChange: _sinceStateChange,
      seed: widget.seed,
    );
    // Stopping a ticker from inside its own callback is allowed, and is how
    // the one-shot `answered` reaction ends without a timer of its own.
    if (!TalkPoseSolver.isAnimated(state: widget.state, sinceStateChange: _sinceStateChange)) {
      _ticker.stop();
      _pose.value = TalkPose.still;
    }
  }

  void _sync() {
    final wanted =
        widget.animate &&
        TalkPoseSolver.isAnimated(state: widget.state, sinceStateChange: _sinceStateChange);

    if (!wanted) {
      if (_ticker.isActive) _ticker.stop();
      _pose.value = TalkPose.still;
      return;
    }
    if (_ticker.isActive) return;

    // `Ticker` reports time since *its* start, so a restarted ticker begins
    // at zero — both clocks have to be rewound with it or the first frame
    // would jump to whatever the old elapsed time implied.
    _elapsed = Duration.zero;
    _stateChangedAt = Duration.zero;
    _ticker.start();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _pose);
}
