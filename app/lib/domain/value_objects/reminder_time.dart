import 'package:flutter/foundation.dart';
import 'package:roundtablezoo/core/errors/app_failure.dart';
import 'package:roundtablezoo/core/errors/result.dart';

/// Time-of-day (hours + minutes) a reminder notification fires at.
/// Persisted as `HH:mm` (data-model `user_settings.reminderTime`).
@immutable
final class ReminderTime {
  const ReminderTime._(this.hour, this.minute);

  /// Parses a stored `HH:mm` string. Falls back to [defaultValue] when the
  /// string is malformed instead of failing storage reads.
  factory ReminderTime.fromStorage(String value) {
    final parts = value.split(':');
    if (parts.length != 2) return defaultValue;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return defaultValue;
    return create(hour: hour, minute: minute).valueOrGet(() => defaultValue);
  }

  static const ReminderTime defaultValue = ReminderTime._(20, 0);

  final int hour;
  final int minute;

  static Result<ReminderTime> create({required int hour, required int minute}) {
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
      return const Result.failure(
        ValidationFailure(null, code: ValidationFailure.reminderTimeInvalid),
      );
    }
    return Result.success(ReminderTime._(hour, minute));
  }

  String toStorageString() =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is ReminderTime && hour == other.hour && minute == other.minute);

  @override
  int get hashCode => Object.hash(hour, minute);

  @override
  String toString() => toStorageString();
}
