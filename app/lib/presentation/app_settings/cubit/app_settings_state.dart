import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:roundtablezoo/core/errors/app_failure.dart';
import 'package:roundtablezoo/domain/entities/user_settings.dart';
import 'package:roundtablezoo/domain/value_objects/locale_preference.dart';
import 'package:roundtablezoo/domain/value_objects/theme_preference.dart';

part 'app_settings_state.freezed.dart';

@freezed
sealed class AppSettingsState with _$AppSettingsState {
  const AppSettingsState._();

  /// Before the first `SettingsRepository.watch()` emission — `AppMaterialRouter`
  /// treats this the same as `error`: system theme, system/RU locale
  /// (FR-021b1, ui-contracts.md).
  const factory AppSettingsState.initial() = AppSettingsInitial;

  const factory AppSettingsState.loaded({required UserSettings settings}) = AppSettingsLoaded;

  /// `watch()` failed — the app stays usable on system theme/locale rather
  /// than losing its UI (ui-contracts.md).
  const factory AppSettingsState.error({required AppFailure failure}) = AppSettingsError;

  ThemeMode get themeMode => switch (this) {
    AppSettingsLoaded(:final settings) => settings.themeMode.toThemeMode(),
    AppSettingsInitial() || AppSettingsError() => ThemeMode.system,
  };

  /// `null` leaves locale resolution to `localeResolutionCallback` (system
  /// locale, falling back to Russian when unsupported — US5.3).
  Locale? get locale => switch (this) {
    AppSettingsLoaded(:final settings) => settings.locale.toLocale(),
    AppSettingsInitial() || AppSettingsError() => null,
  };
}

extension ThemePreferenceX on ThemePreference {
  ThemeMode toThemeMode() => switch (this) {
    ThemePreference.light => ThemeMode.light,
    ThemePreference.dark => ThemeMode.dark,
    ThemePreference.system => ThemeMode.system,
  };
}

extension LocalePreferenceX on LocalePreference {
  Locale? toLocale() => switch (this) {
    LocalePreference.ru => const Locale('ru'),
    LocalePreference.uk => const Locale('uk'),
    LocalePreference.en => const Locale('en'),
    LocalePreference.system => null,
  };
}
