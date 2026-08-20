import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:roundtablezoo/domain/entities/day_entry.dart';
import 'package:roundtablezoo/domain/entities/day_key.dart';

part 'diary_day_entry.freezed.dart';

/// A [DayEntry] together with the day `DayResolver` assigned it. `DayEntry`
/// has no day field of its own — it's derived from `occurredAt` +
/// `dayStartHour`, which must not leave `data/` (principle IV, research.md
/// R15) — so the repository hands back both.
@freezed
abstract class DiaryDayEntry with _$DiaryDayEntry {
  const factory DiaryDayEntry({required DayKey day, required DayEntry entry}) = _DiaryDayEntry;
}
