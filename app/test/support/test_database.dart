import 'package:drift/native.dart';
import 'package:roundtablezoo/data/datasources/drift/app_database.dart';

/// In-memory [AppDatabase] for tests: no file I/O, no shared state between
/// tests, seeded with a default `user_settings` row.
Future<AppDatabase> openTestDatabase({String installId = 'test-install-id'}) async {
  final database = AppDatabase(NativeDatabase.memory());
  await database
      .into(database.userSettingsTable)
      .insert(
        UserSettingsTableCompanion.insert(installId: installId),
      );
  return database;
}
