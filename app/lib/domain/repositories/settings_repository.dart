import 'package:roundtablezoo/core/errors/result.dart';
import 'package:roundtablezoo/domain/entities/user_settings.dart';
import 'package:roundtablezoo/domain/value_objects/day_start_hour.dart';
import 'package:roundtablezoo/domain/value_objects/locale_preference.dart';
import 'package:roundtablezoo/domain/value_objects/theme_preference.dart';

/// Singleton settings row. See contracts/repositories.md.
abstract interface class SettingsRepository {
  /// Current settings. On first run, the row is created with defaults and a
  /// fresh `installId` — the caller doesn't need to know that happened.
  Future<Result<UserSettings>> load();

  /// Reactive stream of settings (Drift `watch()`). Feeds `AppSettingsCubit`.
  Stream<UserSettings> watch();

  Future<Result<UserSettings>> updateThemeMode(ThemePreference value);

  Future<Result<UserSettings>> updateLocale(LocalePreference value);

  Future<Result<UserSettings>> updateDayStartHour(DayStartHour value);

  Future<Result<UserSettings>> updateSoundEnabled({required bool value});

  Future<Result<UserSettings>> updateEnabledCharacters(List<String> characterIds);

  Future<Result<UserSettings>> markOnboardingSeen();
}
