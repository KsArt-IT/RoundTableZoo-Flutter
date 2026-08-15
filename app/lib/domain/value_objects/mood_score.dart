import 'package:flutter/foundation.dart';
import 'package:roundtablezoo/core/errors/app_failure.dart';
import 'package:roundtablezoo/core/errors/result.dart';

/// Explicit emoji-scale mood score, 1..5. Never derived from AI-reaction
/// tone (FR-008).
@immutable
final class MoodScore {
  const MoodScore._(this.value);

  static const int min = 1;
  static const int max = 5;

  final int value;

  static Result<MoodScore> create(int value) {
    if (value < min || value > max) {
      return const Result.failure(
        ValidationFailure(null, code: ValidationFailure.moodScoreOutOfRange),
      );
    }
    return Result.success(MoodScore._(value));
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is MoodScore && value == other.value);

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'MoodScore($value)';
}
