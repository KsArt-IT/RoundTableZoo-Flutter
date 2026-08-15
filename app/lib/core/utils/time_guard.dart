/// Guards against a system clock rollback (or timezone change) turning a
/// live `now − startedAt` computation negative — timers and history must
/// never show/store a negative duration.
extension ClockGuard on DateTime {
  /// Seconds elapsed since [start], clamped to ≥ 0.
  int secondsSince(DateTime start) {
    final diff = difference(start).inSeconds;
    return diff < 0 ? 0 : diff;
  }

  /// Delay until this DateTime, clamped to ≥ [Duration.zero] so a `Timer`
  /// armed for a moment that has already passed fires immediately instead
  /// of throwing.
  Duration delayFrom(DateTime now) {
    final delay = difference(now);
    return delay.isNegative ? Duration.zero : delay;
  }
}
