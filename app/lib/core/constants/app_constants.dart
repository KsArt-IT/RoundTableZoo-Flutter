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

  /// How many days ahead the sliding window of one-shot reminder
  /// notifications is planned (FR-015a).
  static const int reminderHorizonDays = 7;

  /// Maximum allowed delivery delay past the scheduled reminder time —
  /// `AndroidScheduleMode.inexactAllowWhileIdle` never fires early (FR-023).
  static const Duration reminderDeliveryTolerance = Duration(minutes: 60);

  /// Client-side timeout for an ai-proxy reaction request (FR-027a).
  static const Duration aiRequestTimeout = Duration(seconds: 15);

  /// Debounce before autosaving the day text draft (FR-008a).
  static const Duration dayTextAutosaveDebounce = Duration(seconds: 1);

  /// Upper bound of the speaking-bubble reveal effect (FR-017b).
  static const Duration speakingBubbleMaxDuration = Duration(seconds: 4);

  /// Maximum number of characters seated at the table at once (FR-010a).
  static const int maxCharactersAtTable = 6;

  /// Diary list — number of days per `entriesPage` request (FR-004, SC-008).
  static const int diaryPageSize = 30;

  /// Diary list — how far from the end of the shown list loadMore() starts
  /// (research.md R19): less than half a page remaining.
  static const int diaryPrefetchThreshold = diaryPageSize ~/ 2;

  /// Diary CSV export — page size for the internal `entriesPage` walk, to
  /// bound peak memory and avoid N+1 reaction queries (research.md R11).
  static const int diaryExportBatchSize = 200;

  /// Diary — debounce before reacting to `watchEntriesChanged` (FR-009,
  /// research.md R12).
  static const Duration diaryRefreshDebounce = Duration(milliseconds: 300);

  /// Diary chart — visible-range upper bound (inclusive) for daily-point
  /// granularity (FR-010a, research.md R5).
  static const int diaryChartDailyMaxDays = 90;

  /// Diary chart — visible-range upper bound (inclusive) for weekly-point
  /// granularity; beyond this, monthly (FR-010a, research.md R5).
  static const int diaryChartWeeklyMaxDays = 731;

  /// Diary chart — maximum horizontal zoom scale (FR-010b, research.md R6).
  static const double diaryChartMaxScale = 12.0;

  /// Diary chart — initial visible window in days, right edge pinned to the
  /// most recent day (FR-010, research.md R18).
  static const int diaryChartInitialDays = 30;

  /// Diary chart — fixed value axis bounds, independent of data spread
  /// (SC-007, research.md R18).
  static const double diaryChartMinValue = 1.0;
  static const double diaryChartMaxValue = 5.0;
}
