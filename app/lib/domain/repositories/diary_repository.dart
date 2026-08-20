import 'package:roundtablezoo/core/errors/result.dart';
import 'package:roundtablezoo/domain/entities/character_reaction.dart';
import 'package:roundtablezoo/domain/entities/day_entry.dart';
import 'package:roundtablezoo/domain/entities/day_key.dart';
import 'package:roundtablezoo/domain/entities/diary_page.dart';
import 'package:roundtablezoo/domain/entities/mood_chart_point.dart';
import 'package:roundtablezoo/domain/value_objects/mood_score.dart';

/// Diary entries and character reactions. See contracts/repositories.md.
abstract interface class DiaryRepository {
  /// Creates or updates the entry for today's computed day. The "at most
  /// one entry per day" rule is enforced here, in a transaction (FR-009a).
  Future<Result<DayEntry>> saveTodayEntry({required MoodScore moodScore, String? dayText});

  /// The entry for [key]; when several exist, the latest by `occurredAt`
  /// (FR-009c).
  Future<Result<DayEntry?>> entryForDay(DayKey key);

  /// All entries that fall inside [key], newest first. Usually one; more
  /// than one only after a timezone or `dayStartHour` change (FR-009b).
  Future<Result<List<DayEntry>>> entriesForDay(DayKey key);

  /// Entries in a day range — the basis for the future chart.
  Future<Result<List<DayEntry>>> entriesBetween(DayKey from, DayKey to);

  /// Deletes an entry and, by cascade, all its reactions (FR-011).
  Future<Result<void>> deleteEntry(int id);

  Future<Result<CharacterReaction>> addReaction(CharacterReaction reaction);

  Future<Result<List<CharacterReaction>>> reactionsFor(int dayEntryId);

  /// Diary list page, keyset-paginated, newest days first. [beforeOccurredAt]
  /// is [DiaryPage.nextCursor] from the previous page, `null` for the
  /// first. When a day has several entries, only the latest by
  /// `occurredAt` survives (FR-006, same rule as [entryForDay]) —
  /// contracts/diary-repository.md §1.
  Future<Result<DiaryPage>> entriesPage({DateTime? beforeOccurredAt, required int limit});

  /// The full history as chart points, one per day, sorted by ascending
  /// day. A projection of `occurredAt`+`moodScore` only — `dayText` isn't
  /// read (FR-010, research.md R3).
  Future<Result<List<MoodChartPoint>>> moodHistory();

  /// Reactions for several entries in one round trip, keyed by
  /// `dayEntryId`; entries with no reactions are absent. Used by
  /// `ExportDiaryToCsv` to avoid an N+1 query per day (FR-023,
  /// research.md R11).
  Future<Result<Map<int, List<CharacterReaction>>>> reactionsForEntries(List<int> dayEntryIds);

  /// Emits on any change to `day_entries`. Value carries no data — the sole
  /// consumer, `ReminderCoordinator`, only needs the fact of a change
  /// (FR-014a).
  Stream<void> watchEntriesChanged();
}
