import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:roundtablezoo/data/datasources/drift/database_file_location.dart';
import 'package:roundtablezoo/data/datasources/drift/tables/app_tables.dart';
import 'package:roundtablezoo/data/datasources/drift/tables/diary_tables.dart';

part 'app_database.g.dart';

/// Local SQLite storage. `schemaVersion = 1` and no `MigrationStrategy` —
/// per the constitution, schema changes bump the version and reset local
/// dev data until the first Store release.
@DriftDatabase(tables: [DayEntries, CharacterReactions, UserSettingsTable])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
    : super(
        executor ??
            driftDatabase(
              name: databaseName,
              native: DriftNativeOptions(
                databasePath: () async => (await resolveDatabaseFile()).path,
              ),
            ),
      );

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
