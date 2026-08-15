/// Stored language choice. `system` means "follow the OS locale, falling
/// back to Russian when unsupported" (US5.3, FR-029).
enum LocalePreference {
  ru,
  uk,
  en,
  system;

  static LocalePreference fromStorage(String? name) =>
      LocalePreference.values.firstWhere((value) => value.name == name, orElse: () => system);
}
