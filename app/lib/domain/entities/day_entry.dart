import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:roundtablezoo/domain/value_objects/mood_score.dart';

part 'day_entry.freezed.dart';

/// One diary entry. Which calendar day it belongs to is *not* a field here
/// — call `DayResolver.resolve(occurredAt, …)` (FR-009).
@freezed
abstract class DayEntry with _$DayEntry {
  const factory DayEntry({
    required DateTime occurredAt,
    required MoodScore moodScore,
    required DateTime createdAt,
    required DateTime updatedAt,

    /// `null` until the entry is persisted.
    int? id,
    String? dayText,
  }) = _DayEntry;
}
