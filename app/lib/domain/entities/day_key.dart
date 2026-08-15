import 'package:flutter/foundation.dart';

/// Calendar day a moment belongs to, as computed by `DayResolver`. Never
/// stored in the database — always derived from `occurredAt` + timezone +
/// `dayStartHour`.
@immutable
final class DayKey implements Comparable<DayKey> {
  const DayKey({required this.year, required this.month, required this.day});

  factory DayKey.fromDateTime(DateTime date) =>
      DayKey(year: date.year, month: date.month, day: date.day);

  final int year;
  final int month;
  final int day;

  /// Day immediately after this one.
  DayKey get next => DayKey.fromDateTime(DateTime.utc(year, month, day + 1));

  /// Day immediately before this one.
  DayKey get previous => DayKey.fromDateTime(DateTime.utc(year, month, day - 1));

  @override
  int compareTo(DayKey other) {
    if (year != other.year) return year.compareTo(other.year);
    if (month != other.month) return month.compareTo(other.month);
    return day.compareTo(other.day);
  }

  bool operator <(DayKey other) => compareTo(other) < 0;

  bool operator <=(DayKey other) => compareTo(other) <= 0;

  bool operator >(DayKey other) => compareTo(other) > 0;

  bool operator >=(DayKey other) => compareTo(other) >= 0;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DayKey && year == other.year && month == other.month && day == other.day;

  @override
  int get hashCode => Object.hash(year, month, day);

  @override
  String toString() =>
      '${year.toString().padLeft(4, '0')}-'
      '${month.toString().padLeft(2, '0')}-'
      '${day.toString().padLeft(2, '0')}';
}
