import 'package:drift/drift.dart';
import 'package:roundtablezoo/core/app_clock/app_clock.dart';
import 'package:roundtablezoo/core/errors/app_failure.dart';
import 'package:roundtablezoo/core/errors/result.dart';
import 'package:roundtablezoo/core/errors/safe_call_mixin.dart';
import 'package:roundtablezoo/data/datasources/diary_local_datasource.dart';
import 'package:roundtablezoo/data/datasources/drift/app_database.dart';
import 'package:roundtablezoo/data/datasources/settings_local_datasource.dart';
import 'package:roundtablezoo/data/mappers/character_reaction_mapper.dart';
import 'package:roundtablezoo/data/mappers/day_entry_mapper.dart';
import 'package:roundtablezoo/domain/entities/character_reaction.dart';
import 'package:roundtablezoo/domain/entities/day_entry.dart';
import 'package:roundtablezoo/domain/entities/day_key.dart';
import 'package:roundtablezoo/domain/repositories/diary_repository.dart';
import 'package:roundtablezoo/domain/services/day_resolver.dart';
import 'package:roundtablezoo/domain/value_objects/mood_score.dart';
import 'package:roundtablezoo/domain/value_objects/validators.dart';

/// Registered by `StorageDiSwitch`, not `@LazySingleton(as: ...)` — see
/// `injection_module.dart`.
class DiaryRepositoryImpl with SafeCallMixin implements DiaryRepository {
  DiaryRepositoryImpl({
    required this._db,
    required this._dataSource,
    required this._settingsDataSource,
    required this._clock,
    required this._dayResolver,
  });

  final AppDatabase _db;
  final DiaryLocalDataSource _dataSource;
  final SettingsLocalDataSource _settingsDataSource;
  final AppClock _clock;
  final DayResolver _dayResolver;

  @override
  // This phase has a single writer of day_entries (the Table screen), and
  // it always sends both fields together — so overwriting dayText on every
  // save is safe. If a future screen ever calls this with mood only,
  // expecting existing text to survive, this needs a "preserve on omit"
  // rule instead.
  Future<Result<DayEntry>> saveTodayEntry({required MoodScore moodScore, String? dayText}) =>
      safeCall(() async {
        final normalizedText = Validators.dayText(
          dayText,
        ).match(success: (value) => value, failure: (failure) => throw failure);

        return _db.transaction(() async {
          final now = _clock.nowUtc();
          final settingsRow = await _settingsDataSource.loadOrCreate();
          final key = _dayResolver.resolve(
            now,
            zone: _clock.location,
            dayStartHour: settingsRow.dayStartHour,
          );
          final bounds = _boundsFor(key, settingsRow);
          final existing = await _dataSource.entriesInRange(bounds.startUtc, bounds.endUtc);

          if (existing.isEmpty) {
            final inserted = await _dataSource.insertEntry(
              DayEntriesCompanion.insert(
                occurredAt: now,
                moodScore: moodScore.value,
                dayText: Value(normalizedText),
                createdAt: now,
                updatedAt: now,
              ),
            );
            return inserted.toEntity();
          }

          // entriesInRange sorts DESC — the first row is the one FR-009d
          // designates as "the" entry for this day.
          final updated = await _dataSource.updateEntry(
            existing.first.id,
            DayEntriesCompanion(
              moodScore: Value(moodScore.value),
              dayText: Value(normalizedText),
              updatedAt: Value(now),
            ),
          );
          return updated.toEntity();
        });
      });

  @override
  Future<Result<DayEntry?>> entryForDay(DayKey key) => safeCall(() async {
    final entries = await _entriesInDay(key);
    return entries.isEmpty ? null : entries.first;
  });

  @override
  Future<Result<List<DayEntry>>> entriesForDay(DayKey key) => safeCall(() => _entriesInDay(key));

  @override
  Future<Result<List<DayEntry>>> entriesBetween(DayKey from, DayKey to) => safeCall(() async {
    final settingsRow = await _settingsDataSource.loadOrCreate();
    final startBounds = _boundsFor(from, settingsRow);
    final endBounds = _boundsFor(to, settingsRow);
    final rows = await _dataSource.entriesInRange(startBounds.startUtc, endBounds.endUtc);
    return rows.map((row) => row.toEntity()).toList();
  });

  @override
  Future<Result<void>> deleteEntry(int id) => safeCall(() async {
    final deletedCount = await _dataSource.deleteEntry(id);
    if (deletedCount == 0) {
      throw const DatabaseFailure(null, code: DatabaseFailure.entityNotFound);
    }
  });

  @override
  Future<Result<CharacterReaction>> addReaction(CharacterReaction reaction) => safeCall(() async {
    Validators.intensity(
      reaction.intensity,
    ).match(success: (_) {}, failure: (failure) => throw failure);
    final inserted = await _dataSource.insertReaction(reaction.toInsertCompanion());
    return inserted.toEntity();
  });

  @override
  Future<Result<List<CharacterReaction>>> reactionsFor(int dayEntryId) => safeCall(() async {
    final rows = await _dataSource.reactionsForEntry(dayEntryId);
    return rows.map((row) => row.toEntity()).toList();
  });

  Future<List<DayEntry>> _entriesInDay(DayKey key) async {
    final settingsRow = await _settingsDataSource.loadOrCreate();
    final bounds = _boundsFor(key, settingsRow);
    final rows = await _dataSource.entriesInRange(bounds.startUtc, bounds.endUtc);
    return rows.map((row) => row.toEntity()).toList();
  }

  ({DateTime startUtc, DateTime endUtc}) _boundsFor(DayKey key, UserSettingsRow settingsRow) =>
      _dayResolver.boundsUtc(key, zone: _clock.location, dayStartHour: settingsRow.dayStartHour);
}
