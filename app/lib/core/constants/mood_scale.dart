import 'package:flutter/material.dart';
import 'package:roundtablezoo/gen/app_localizations.dart';

/// Single entry of the emoji mood scale (FR-001): emoji, semantic color and
/// a localized label so the value is distinguishable to screen readers, not
/// only by color.
class MoodScaleEntry {
  const MoodScaleEntry({
    required this.value,
    required this.emoji,
    required this.color,
    required this.label,
  });

  final int value;
  final String emoji;
  final Color color;
  final String Function(AppLocalizations locale) label;
}

/// Maps `MoodScore.value` (1..5) to emoji, semantic color and localized
/// label — single source of truth shared by the Table screen and the future
/// Diary chart (research.md R15).
abstract final class MoodScale {
  const MoodScale._();

  static const List<MoodScaleEntry> entries = [
    MoodScaleEntry(
      value: 1,
      emoji: '😢',
      color: Color(0xFFE57373),
      label: _label1,
    ),
    MoodScaleEntry(
      value: 2,
      emoji: '😕',
      color: Color(0xFFFFB74D),
      label: _label2,
    ),
    MoodScaleEntry(
      value: 3,
      emoji: '😐',
      color: Color(0xFFFFD54F),
      label: _label3,
    ),
    MoodScaleEntry(
      value: 4,
      emoji: '🙂',
      color: Color(0xFFAED581),
      label: _label4,
    ),
    MoodScaleEntry(
      value: 5,
      emoji: '😄',
      color: Color(0xFF66BB6A),
      label: _label5,
    ),
  ];

  static MoodScaleEntry ofValue(int value) =>
      entries.firstWhere((entry) => entry.value == value);

  static String _label1(AppLocalizations locale) => locale.moodScaleVeryBad;
  static String _label2(AppLocalizations locale) => locale.moodScaleBad;
  static String _label3(AppLocalizations locale) => locale.moodScaleNeutral;
  static String _label4(AppLocalizations locale) => locale.moodScaleGood;
  static String _label5(AppLocalizations locale) => locale.moodScaleVeryGood;
}
