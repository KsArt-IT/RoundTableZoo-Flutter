import 'package:drift/drift.dart';
import 'package:roundtablezoo/core/errors/result.dart';
import 'package:roundtablezoo/core/errors/safe_call_mixin.dart';
import 'package:roundtablezoo/data/datasources/drift/app_database.dart';
import 'package:roundtablezoo/data/datasources/settings_local_datasource.dart';
import 'package:roundtablezoo/data/mappers/user_settings_mapper.dart';
import 'package:roundtablezoo/domain/entities/user_settings.dart';
import 'package:roundtablezoo/domain/repositories/settings_repository.dart';
import 'package:roundtablezoo/domain/value_objects/day_start_hour.dart';
import 'package:roundtablezoo/domain/value_objects/locale_preference.dart';
import 'package:roundtablezoo/domain/value_objects/reminder_time.dart';
import 'package:roundtablezoo/domain/value_objects/theme_preference.dart';
import 'package:roundtablezoo/domain/value_objects/validators.dart';

/// Registered by `StorageDiSwitch`, not `@LazySingleton(as: ...)` — see
/// `injection_module.dart`.
class SettingsRepositoryImpl with SafeCallMixin implements SettingsRepository {
  SettingsRepositoryImpl({required this._dataSource});

  final SettingsLocalDataSource _dataSource;

  @override
  Future<Result<UserSettings>> load() => safeCall(() async {
    final row = await _dataSource.loadOrCreate();
    return row.toEntity();
  });

  @override
  Stream<UserSettings> watch() async* {
    // The row may not exist yet (fresh install, nobody has called load()/
    // update* first) — watchSingle() errors on zero rows, so create it
    // before subscribing.
    await _dataSource.loadOrCreate();
    yield* _dataSource.watch().map((row) => row.toEntity());
  }

  @override
  Future<Result<UserSettings>> updateThemeMode(ThemePreference value) => _update(
    UserSettingsTableCompanion(themeMode: Value(value.name)),
  );

  @override
  Future<Result<UserSettings>> updateLocale(LocalePreference value) => _update(
    UserSettingsTableCompanion(locale: Value(value.name)),
  );

  @override
  Future<Result<UserSettings>> updateDayStartHour(DayStartHour value) => _update(
    UserSettingsTableCompanion(dayStartHour: Value(value.value)),
  );

  @override
  Future<Result<UserSettings>> updateSoundEnabled({required bool value}) => _update(
    UserSettingsTableCompanion(soundEnabled: Value(value)),
  );

  @override
  Future<Result<UserSettings>> updateEnabledCharacters(List<String> characterIds) =>
      safeCall(() async {
        Validators.enabledCharacterIds(
          characterIds,
        ).match(success: (_) {}, failure: (failure) => throw failure);
        await _dataSource.loadOrCreate();
        final updated = await _dataSource.update(
          UserSettingsTableCompanion(
            enabledCharacterIds: Value(encodeEnabledCharacterIds(characterIds)),
          ),
        );
        return updated.toEntity();
      });

  @override
  Future<Result<UserSettings>> markOnboardingSeen() => _update(
    const UserSettingsTableCompanion(hasSeenOnboarding: Value(true)),
  );

  @override
  Future<Result<UserSettings>> updateReminderEnabled({required bool value}) => _update(
    UserSettingsTableCompanion(reminderEnabled: Value(value)),
  );

  @override
  Future<Result<UserSettings>> updateReminderTime(ReminderTime value) => _update(
    UserSettingsTableCompanion(reminderTime: Value(value.toStorageString())),
  );

  /// Ensures the row exists (first run), applies [companion], and returns
  /// the full resulting state — callers never need to re-read (contract:
  /// every `update*` returns the complete new settings).
  Future<Result<UserSettings>> _update(UserSettingsTableCompanion companion) => safeCall(() async {
    await _dataSource.loadOrCreate();
    final updated = await _dataSource.update(companion);
    return updated.toEntity();
  });
}
