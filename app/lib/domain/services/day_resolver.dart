import 'package:roundtablezoo/domain/entities/day_key.dart';
import 'package:timezone/timezone.dart' as tz;

/// Pure function from (instant, timezone, day-start-hour) to a [DayKey].
/// No Flutter, no state, no `DateTime.now()` (FR-009, FR-023b, FR-024).
class DayResolver {
  /// Which day [instantUtc] belongs to, given the device's [zone] and the
  /// configured [dayStartHour] (0..23).
  DayKey resolve(DateTime instantUtc, {required tz.Location zone, required int dayStartHour}) {
    final local = tz.TZDateTime.from(instantUtc, zone);
    final shifted = local.subtract(Duration(hours: dayStartHour));
    return DayKey(year: shifted.year, month: shifted.month, day: shifted.day);
  }

  /// Half-open `[start, end)` UTC bounds of [key] — used for range queries.
  /// Computed via `TZDateTime` (not raw UTC arithmetic) so DST transitions
  /// produce a shorter/longer day instead of a gap or overlap.
  ({DateTime startUtc, DateTime endUtc}) boundsUtc(
    DayKey key, {
    required tz.Location zone,
    required int dayStartHour,
  }) {
    final start = tz.TZDateTime(zone, key.year, key.month, key.day, dayStartHour);
    final end = tz.TZDateTime(zone, key.next.year, key.next.month, key.next.day, dayStartHour);
    return (startUtc: start.toUtc(), endUtc: end.toUtc());
  }
}
