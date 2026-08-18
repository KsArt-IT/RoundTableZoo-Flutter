import 'package:drift/drift.dart';

/// Singleton settings row — exactly one row, `id = 1` (enforced by the
/// check constraint, not just convention).
@DataClassName('UserSettingsRow')
class UserSettingsTable extends Table {
  @override
  String get tableName => 'user_settings';

  IntColumn get id => integer().check(id.equals(1)).clientDefault(() => 1)();

  /// 32 hex characters, generated once on first insert (FR-014, FR-015).
  TextColumn get installId => text()();

  /// `'light' | 'dark' | 'system'`.
  TextColumn get themeMode => text().withDefault(const Constant('system'))();

  /// `'ru' | 'uk' | 'en' | 'system'`.
  TextColumn get locale => text().withDefault(const Constant('system'))();

  BoolColumn get soundEnabled => boolean().withDefault(const Constant(true))();

  /// JSON array of character ids; must contain at least one entry.
  TextColumn get enabledCharacterIds =>
      text().withDefault(const Constant('["cat","dog","crocodile","hippo"]'))();

  BoolColumn get hasSeenOnboarding => boolean().withDefault(const Constant(false))();

  BoolColumn get reminderEnabled => boolean().withDefault(const Constant(false))();

  /// `HH:mm`.
  TextColumn get reminderTime => text().withDefault(const Constant('20:00'))();

  IntColumn get dayStartHour => integer()
      .check(dayStartHour.isBiggerOrEqualValue(0) & dayStartHour.isSmallerOrEqualValue(23))
      .withDefault(const Constant(0))();

  /// The `check(id.equals(1))` constraint alone doesn't stop a second row:
  /// without a real uniqueness constraint on `id`, `INSERT OR IGNORE` has
  /// nothing to conflict against, so concurrent first-time
  /// `loadOrCreate()` callers (e.g. `AppSettingsCubit` and
  /// `CurrentDayCubit` both racing to create the row on first use) can
  /// each insert their own `id = 1` row.
  @override
  Set<Column> get primaryKey => {id};
}
