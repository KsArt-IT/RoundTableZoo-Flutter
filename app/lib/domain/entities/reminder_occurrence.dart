import 'package:flutter/foundation.dart';
import 'package:roundtablezoo/domain/entities/day_key.dart';

/// One planned reminder firing. Never persisted — recomputed on every
/// `ReminderCoordinator.reconcile()` (data-model.md).
@immutable
final class ReminderOccurrence {
  const ReminderOccurrence({required this.day, required this.scheduledAtUtc});

  /// The day (per `dayStartHour`) this reminder belongs to — not
  /// necessarily the calendar date it fires on (FR-019a).
  final DayKey day;

  /// The moment this reminder fires, in UTC.
  final DateTime scheduledAtUtc;

  /// System notification queue id, deterministic by day so cancelling hits
  /// exactly the right firing (FR-014a) and re-planning overwrites rather
  /// than duplicates (FR-015). 2026-08-16 -> 20260816; fits int32 until 2147.
  int get notificationId => day.year * 10000 + day.month * 100 + day.day;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ReminderOccurrence && day == other.day && scheduledAtUtc == other.scheduledAtUtc);

  @override
  int get hashCode => Object.hash(day, scheduledAtUtc);

  @override
  String toString() => 'ReminderOccurrence(day: $day, scheduledAtUtc: $scheduledAtUtc)';
}
