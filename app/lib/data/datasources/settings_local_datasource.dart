import 'package:drift/drift.dart';
import 'package:roundtablezoo/core/utils/install_id_generator.dart';
import 'package:roundtablezoo/data/datasources/drift/app_database.dart';

/// Thin query layer over the `user_settings` singleton row (`id = 1`).
/// Registered by `StorageDiSwitch`, not `@lazySingleton` — see
/// `injection_module.dart`.
class SettingsLocalDataSource {
  SettingsLocalDataSource(this._db);

  final AppDatabase _db;

  /// The settings row, creating it with defaults and a fresh `installId` on
  /// first access (FR-014, FR-015).
  Future<UserSettingsRow> loadOrCreate() async {
    final existing = await _singleRowQuery.getSingleOrNull();
    if (existing != null) return existing;

    await _db
        .into(_db.userSettingsTable)
        .insert(
          UserSettingsTableCompanion.insert(installId: generateInstallId()),
          mode: InsertMode.insertOrIgnore,
        );
    return _singleRowQuery.getSingle();
  }

  Stream<UserSettingsRow> watch() => _singleRowQuery.watchSingle();

  Future<UserSettingsRow> update(UserSettingsTableCompanion companion) async {
    final rows = await (_db.update(
      _db.userSettingsTable,
    )..where((row) => row.id.equals(1))).writeReturning(companion);
    return rows.single;
  }

  /// The `id = 1` singleton row — every read goes through this one place.
  SimpleSelectStatement<$UserSettingsTableTable, UserSettingsRow> get _singleRowQuery =>
      _db.select(_db.userSettingsTable)..where((row) => row.id.equals(1));
}
