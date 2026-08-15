import 'package:flutter/foundation.dart';
import 'package:roundtablezoo/core/errors/app_failure.dart';
import 'package:roundtablezoo/core/errors/result.dart';

/// Hour of day (0..23) at which a new diary day begins (FR-025a).
@immutable
final class DayStartHour {
  const DayStartHour._(this.value);

  static const int min = 0;
  static const int max = 23;

  static const DayStartHour defaultValue = DayStartHour._(0);

  final int value;

  static Result<DayStartHour> create(int value) {
    if (value < min || value > max) {
      return const Result.failure(
        ValidationFailure(null, code: ValidationFailure.dayStartHourOutOfRange),
      );
    }
    return Result.success(DayStartHour._(value));
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is DayStartHour && value == other.value);

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'DayStartHour($value)';
}
