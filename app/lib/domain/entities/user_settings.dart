import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:roundtablezoo/domain/value_objects/day_start_hour.dart';
import 'package:roundtablezoo/domain/value_objects/locale_preference.dart';
import 'package:roundtablezoo/domain/value_objects/reminder_time.dart';
import 'package:roundtablezoo/domain/value_objects/theme_preference.dart';

part 'user_settings.freezed.dart';

/// Singleton application settings row (`user_settings`, `id = 1`).
@freezed
abstract class UserSettings with _$UserSettings {
  const factory UserSettings({
    /// Anonymous per-install identifier. Never leaves the device.
    required String installId,
    required ThemePreference themeMode,
    required LocalePreference locale,
    required bool soundEnabled,
    /// Must not be empty (`Validators.enabledCharacterIds`).
    required List<String> enabledCharacterIds,
    required bool hasSeenOnboarding,
    required bool reminderEnabled,
    required ReminderTime reminderTime,
    required DayStartHour dayStartHour,
  }) = _UserSettings;
}
