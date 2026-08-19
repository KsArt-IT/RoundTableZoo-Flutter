import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:roundtablezoo/core/constants/app_constants.dart';

/// One character's avatar plus its optional speaking bubble.
class RoundTableSeat {
  const RoundTableSeat({required this.characterId, required this.avatar, this.bubble});

  /// Identifies this seat across rebuilds — used as the `Positioned`
  /// widgets' own `Key` in the `Stack` (not just a key on the avatar/bubble
  /// child). Without it, two `Positioned`s of the same type and `null` key
  /// are indistinguishable to `Stack`'s reconciliation, so when the set of
  /// characters *with a bubble* changes shape between builds, Flutter can
  /// match the wrong `Positioned`/`AnimationController` to the wrong seat
  /// — the profile of a bubble surfacing over the wrong avatar.
  final String characterId;

  final Widget avatar;

  /// Rendered full-width, anchored just outside the circle from the
  /// avatar's own side (above for the top half, below for the bottom
  /// half) — not confined to the avatar's own circle, so a long reply has
  /// room to read instead of being clipped.
  final Widget? bubble;
}

/// Positions 1..`AppConstants.maxCharactersAtTable` avatars around a circle,
/// starting at the top and going clockwise (research.md R9):
/// `angle = -pi/2 + 2*pi*i/n`. A single character is the degenerate case —
/// it lands at the top, not centered, which needs no special branch.
///
/// Requires bounded constraints from its parent (e.g. `Expanded`/`SizedBox`
/// inside a `Column`) — like any `Stack`, it doesn't size itself from its
/// children.
class RoundTableLayout extends StatelessWidget {
  const RoundTableLayout({required this.seats, this.activeCharacterId, super.key});

  final List<RoundTableSeat> seats;

  /// The character most recently tapped, if any — its bubble paints last
  /// (on top of the others), so a fresh reply is never hidden under an
  /// older, still-visible one from a neighboring seat.
  final String? activeCharacterId;

  static const _seatSize = AppConstants.minTapTargetDp * 1.5;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        final center = Offset(size.width / 2, size.height / 2);
        final radius = math.max(0.0, math.min(size.width, size.height) / 2 - _seatSize / 2 - 8);
        final count = seats.length;

        final angles = <double>[
          for (var i = 0; i < count; i++) -math.pi / 2 + 2 * math.pi * i / count,
        ];
        final tops = <double>[
          for (final angle in angles) center.dy + radius * math.sin(angle) - _seatSize / 2,
        ];

        final avatars = <Widget>[
          for (var i = 0; i < count; i++)
            _avatarAt(
              key: ValueKey('seat-${seats[i].characterId}'),
              center: center,
              radius: radius,
              angle: angles[i],
              top: tops[i],
              child: seats[i].avatar,
            ),
        ];

        final bubbles = <MapEntry<String, Widget>>[
          for (var i = 0; i < count; i++)
            if (seats[i].bubble case final bubble?)
              MapEntry(
                seats[i].characterId,
                _bubbleFor(
                  key: ValueKey('bubble-slot-${seats[i].characterId}'),
                  // The right half of the circle (top through right, clockwise)
                  // opens upward; the left half (bottom through left) opens
                  // downward — a plain "always above" rule crowds every
                  // reply into the same band for a 4-seat table, since the
                  // right/left seats share the top seat's vertical anchor.
                  above: angles[i] < math.pi / 2,
                  avatarTop: tops[i],
                  avatarBottom: tops[i] + _seatSize,
                  stackHeight: size.height,
                  child: bubble,
                ),
              ),
        ];
        // Stable partition, not a comparator sort: the active character's
        // bubble moves to the end (painted last, on top) without
        // reordering the rest relative to each other.
        final orderedBubbles = [
          ...bubbles.where((entry) => entry.key != activeCharacterId),
          ...bubbles.where((entry) => entry.key == activeCharacterId),
        ];

        return Stack(children: [...avatars, for (final entry in orderedBubbles) entry.value]);
      },
    );
  }

  Widget _avatarAt({
    required Key key,
    required Offset center,
    required double radius,
    required double angle,
    required double top,
    required Widget child,
  }) {
    final left = center.dx + radius * math.cos(angle) - _seatSize / 2;
    return Positioned(key: key, left: left, top: top, width: _seatSize, child: child);
  }

  /// [above]: anchored by its bottom edge to just above the avatar's top,
  /// growing upward. Otherwise anchored by its top edge to just below the
  /// avatar's bottom, growing downward. Full screen width either way.
  Widget _bubbleFor({
    required Key key,
    required bool above,
    required double avatarTop,
    required double avatarBottom,
    required double stackHeight,
    required Widget child,
  }) {
    if (above) {
      return Positioned(
        key: key,
        left: 0,
        right: 0,
        bottom: math.max(0, stackHeight - avatarTop),
        child: Align(alignment: Alignment.bottomCenter, child: child),
      );
    }
    return Positioned(
      key: key,
      left: 0,
      right: 0,
      top: avatarBottom,
      child: Align(alignment: Alignment.topCenter, child: child),
    );
  }
}
