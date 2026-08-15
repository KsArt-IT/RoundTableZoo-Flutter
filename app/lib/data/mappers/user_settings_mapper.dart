import 'dart:convert';

import 'package:roundtablezoo/data/datasources/drift/app_database.dart';
import 'package:roundtablezoo/domain/entities/user_settings.dart';
import 'package:roundtablezoo/domain/value_objects/day_start_hour.dart';
import 'package:roundtablezoo/domain/value_objects/locale_preference.dart';
import 'package:roundtablezoo/domain/value_objects/reminder_time.dart';
import 'package:roundtablezoo/domain/value_objects/theme_preference.dart';

extension UserSettingsRowMapper on UserSettingsRow {
  UserSettings toEntity() => UserSettings(
    installId: installId,
    themeMode: ThemePreference.fromStorage(themeMode),
    locale: LocalePreference.fromStorage(locale),
    soundEnabled: soundEnabled,
    enabledCharacterIds: (jsonDecode(enabledCharacterIds) as List<dynamic>).cast<String>(),
    hasSeenOnboarding: hasSeenOnboarding,
    reminderEnabled: reminderEnabled,
    reminderTime: ReminderTime.fromStorage(reminderTime),
    // The CHECK(dayStartHour BETWEEN 0 AND 23) constraint already
    // guarantees this succeeds; see day_entry_mapper.dart for why a
    // failure here throws instead of degrading gracefully.
    dayStartHour: DayStartHour.create(dayStartHour).valueOrGet(
      () => throw StateError(
        'user_settings.dayStartHour=$dayStartHour violates its CHECK constraint',
      ),
    ),
  );
}

/// The `enabledCharacterIds` storage format — a JSON array. Shared so every
/// write goes through the same encoding as [UserSettingsRowMapper] expects
/// to decode.
String encodeEnabledCharacterIds(List<String> characterIds) => jsonEncode(characterIds);
