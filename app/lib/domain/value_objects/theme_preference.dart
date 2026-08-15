/// Stored theme choice. `system` means "follow the OS setting" and is the
/// default (FR-027).
enum ThemePreference {
  light,
  dark,
  system;

  static ThemePreference fromStorage(String? name) =>
      ThemePreference.values.firstWhere((value) => value.name == name, orElse: () => system);
}
