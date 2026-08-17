import 'package:flutter/material.dart';
import 'package:roundtablezoo/gen/app_localizations.dart';

/// Maps `MoodScore.value` (1..5) to emoji, semantic color and localized
/// label — single source of truth shared by the Table screen and the future
/// Diary chart (research.md R15). Distinguishable by more than color alone
/// (FR-001), for screen readers too.
enum MoodScale {
  veryBad(value: 1, emoji: '😢', color: Color(0xFFE57373)),
  bad(value: 2, emoji: '😕', color: Color(0xFFFFB74D)),
  neutral(value: 3, emoji: '😐', color: Color(0xFFFFD54F)),
  good(value: 4, emoji: '🙂', color: Color(0xFFAED581)),
  veryGood(value: 5, emoji: '😄', color: Color(0xFF66BB6A));

  const MoodScale({
    required this.value,
    required this.emoji,
    required this.color,
  });

  final int value;
  final String emoji;
  final Color color;

  static MoodScale fromValue(int value) => values[value - 1];

  String label(AppLocalizations locale) => switch (this) {
    veryBad => locale.moodScaleVeryBad,
    bad => locale.moodScaleBad,
    neutral => locale.moodScaleNeutral,
    good => locale.moodScaleGood,
    veryGood => locale.moodScaleVeryGood,
  };
}
