import 'dart:ui';

import 'package:roundtablezoo/core/utils/locale_resolution.dart';
import 'package:roundtablezoo/domain/value_objects/locale_preference.dart';
import 'package:roundtablezoo/gen/app_localizations.dart';

/// Localized reminder notification text, resolved without a `BuildContext`
/// (research.md, R7) — the notification is planned ahead of time and may
/// fire while the app isn't running.
Future<({String title, String body})> reminderTexts(LocalePreference preference) async {
  final localizations = await _localizationsFor(preference);
  return (title: localizations.reminderNotificationTitle, body: localizations.reminderNotificationBody);
}

/// Localized notification channel name/description, shown in the system
/// settings — same neutrality rules as [reminderTexts] apply (FR-016b).
Future<({String name, String description})> channelTexts(LocalePreference preference) async {
  final localizations = await _localizationsFor(preference);
  return (
    name: localizations.notificationChannelName,
    description: localizations.notificationChannelDescription,
  );
}

Future<AppLocalizations> _localizationsFor(LocalePreference preference) {
  final locale = preference == LocalePreference.system
      ? resolveDeviceLocale(PlatformDispatcher.instance.locale, AppLocalizations.supportedLocales)
      : _toLocale(preference);
  return AppLocalizations.delegate.load(locale);
}

Locale _toLocale(LocalePreference preference) => switch (preference) {
  LocalePreference.ru => const Locale('ru'),
  LocalePreference.uk => const Locale('uk'),
  LocalePreference.en => const Locale('en'),
  LocalePreference.system => throw StateError('system is resolved separately'),
};
