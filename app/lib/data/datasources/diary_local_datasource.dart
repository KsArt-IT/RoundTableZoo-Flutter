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
}
