import 'package:roundtablezoo/core/errors/result.dart';
import 'package:roundtablezoo/domain/entities/character_reaction.dart';
import 'package:roundtablezoo/domain/entities/day_entry.dart';
import 'package:roundtablezoo/domain/entities/day_key.dart';
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

  /// Emits on any change to `day_entries`. Value carries no data — the sole
  /// consumer, `ReminderCoordinator`, only needs the fact of a change
  /// (FR-014a).
  Stream<void> watchEntriesChanged();
}
