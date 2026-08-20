import 'package:drift/drift.dart';
import 'package:roundtablezoo/data/datasources/drift/app_database.dart';

/// Thin query layer over `day_entries`/`character_reactions`. No domain
/// types here — mapping happens in `data/mappers/`. Registered by
/// `StorageDiSwitch`, not `@lazySingleton` — see `injection_module.dart`.
class DiaryLocalDataSource {
  DiaryLocalDataSource(this._db);

  final AppDatabase _db;

  /// Entries with `occurredAt` in `[startUtc, endUtc)`, latest first —
  /// `ORDER BY occurredAt DESC, id DESC` per FR-009d.
  Future<List<DayEntryRow>> entriesInRange(DateTime startUtc, DateTime endUtc) {
    final query = _db.select(_db.dayEntries)
      ..where(
        (row) =>
            row.occurredAt.isBiggerOrEqualValue(startUtc) &
            row.occurredAt.isSmallerThanValue(endUtc),
      )
      ..orderBy([
        (row) => OrderingTerm.desc(row.occurredAt),
        (row) => OrderingTerm.desc(row.id),
      ]);
    return query.get();
  }

  Future<DayEntryRow> insertEntry(DayEntriesCompanion companion) =>
      _db.into(_db.dayEntries).insertReturning(companion);

  Future<DayEntryRow> updateEntry(int id, DayEntriesCompanion companion) async {
    final rows = await (_db.update(
      _db.dayEntries,
    )..where((row) => row.id.equals(id))).writeReturning(companion);
    return rows.single;
  }

  /// Number of rows deleted (0 when `id` doesn't exist).
  Future<int> deleteEntry(int id) =>
      (_db.delete(_db.dayEntries)..where((row) => row.id.equals(id))).go();

  /// Emits on any change to `day_entries` — the value carries no data, only
  /// the fact that something changed (`ReminderCoordinator`).
  Stream<void> watchEntriesChanged() => _db.select(_db.dayEntries).watch().map((_) {});

  Future<CharacterReactionRow> insertReaction(CharacterReactionsCompanion companion) =>
      _db.into(_db.characterReactions).insertReturning(companion);

  Future<List<CharacterReactionRow>> reactionsForEntry(int dayEntryId) {
    final query = _db.select(_db.characterReactions)
      ..where((row) => row.dayEntryId.equals(dayEntryId))
      ..orderBy([(row) => OrderingTerm.asc(row.createdAt)]);
    return query.get();
  }

  /// Keyset page for the Diary list — `occurredAt < beforeUtc` (or
  /// unfiltered when `beforeUtc` is `null`), newest first, at most [limit]
  /// rows. Uses `idx_day_entries_occurred_at` (contracts/diary-repository.md
  /// §1).
  Future<List<DayEntryRow>> entriesBefore(DateTime? beforeUtc, int limit) {
    final query = _db.select(_db.dayEntries);
    if (beforeUtc != null) {
      query.where((row) => row.occurredAt.isSmallerThanValue(beforeUtc));
    }
    query
      ..orderBy([
        (row) => OrderingTerm.desc(row.occurredAt),
        (row) => OrderingTerm.desc(row.id),
      ])
      ..limit(limit);
    return query.get();
  }

  /// The `(occurredAt, moodScore)` projection over the whole table, used
  /// for the mood chart — `dayText` is never read (research.md R3).
  Future<List<({DateTime occurredAt, int moodScore})>> moodProjection() async {
    final query = _db.selectOnly(_db.dayEntries)
      ..addColumns([_db.dayEntries.occurredAt, _db.dayEntries.moodScore])
      ..orderBy([OrderingTerm.desc(_db.dayEntries.occurredAt)]);
    final rows = await query.get();
    return rows
        .map(
          (row) => (
            occurredAt: row.read(_db.dayEntries.occurredAt)!,
            moodScore: row.read(_db.dayEntries.moodScore)!,
          ),
        )
        .toList(growable: false);
  }

  /// Reactions for several entries in one query, grouped by `dayEntryId` —
  /// avoids the N+1 pattern `reactionsForEntry` would produce per day
  /// (contracts/diary-repository.md §3, research.md R11). Entries with no
  /// reactions are absent from the result.
  Future<List<CharacterReactionRow>> reactionsForEntryIds(List<int> ids) {
    if (ids.isEmpty) return Future.value(const []);
    final query = _db.select(_db.characterReactions)
      ..where((row) => row.dayEntryId.isIn(ids))
      ..orderBy([(row) => OrderingTerm.asc(row.createdAt)]);
    return query.get();
  }
}
