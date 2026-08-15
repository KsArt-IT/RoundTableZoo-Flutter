/// Application-wide business constants (single source of magic numbers).
abstract final class AppConstants {
  const AppConstants._();

  /// Minimum tap target size, per Material accessibility guidelines.
  static const double minTapTargetDp = 48;

  /// Window within which identical failures are collapsed into one toast.
  static const Duration duplicateFailureWindow = Duration(seconds: 3);

  /// Maximum length of a diary day entry's free text.
  static const int maxDayTextLength = 2000;

  /// Allowed drift between a day-rollover tick and the boundary it targets.
  static const Duration dayRolloverTolerance = Duration(seconds: 60);
}
