/// Route paths and names. Single source of truth — no path literals
/// elsewhere in `app/` or `presentation/`.
abstract final class AppRoutes {
  const AppRoutes._();

  static const String tablePath = '/table';
  static const String tableName = 'table';

  static const String diaryPath = '/diary';
  static const String diaryName = 'diary';

  static const String settingsPath = '/settings';
  static const String settingsName = 'settings';

  /// Registered but with no redirect guard (FR-006) — reachable, never
  /// forced.
  static const String onboardingPath = '/onboarding';
  static const String onboardingName = 'onboarding';

  /// Full-screen, outside the shell. Only reached via redirect when
  /// `StorageMode.unavailable` (FR-021b).
  static const String storageErrorPath = '/storage-error';
  static const String storageErrorName = 'storageError';
}
