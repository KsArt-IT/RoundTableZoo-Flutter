import 'package:flutter/widgets.dart';

/// Shared `MaterialApp.localeResolutionCallback` fallback: an unsupported
/// device language falls back to Russian, the template locale (FR-029,
/// US5.3). Used by both `AppMaterialRouter` and `StartupErrorPage` — the
/// two `MaterialApp`s that exist before `AppSettingsCubit` can pick an
/// explicit locale.
Locale resolveDeviceLocale(Locale? deviceLocale, Iterable<Locale> supportedLocales) {
  if (deviceLocale == null) return const Locale('ru');
  for (final locale in supportedLocales) {
    if (locale.languageCode == deviceLocale.languageCode) return locale;
  }
  return const Locale('ru');
}
