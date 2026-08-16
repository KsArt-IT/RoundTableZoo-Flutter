import 'package:roundtablezoo/core/constants/app_constants.dart';
import 'package:roundtablezoo/domain/entities/day_key.dart';
import 'package:roundtablezoo/domain/entities/reminder_occurrence.dart';
import 'package:roundtablezoo/domain/entities/user_settings.dart';
import 'package:roundtablezoo/domain/services/day_resolver.dart';
import 'package:timezone/timezone.dart' as tz;

/// Pure function from (now, timezone, settings, recorded days) to a sliding
/// window of one-shot reminder firings. No Flutter, no `DateTime.now()`
/// (principle IV, data-model.md).
class ReminderPlanner {
  ReminderPlanner({required DayResolver dayResolver}) : _dayResolver = dayResolver;

  final DayResolver _dayResolver;

  List<ReminderOccurrence> plan({
    required DateTime nowUtc,
    required tz.Location zone,
    required UserSettings settings,
    required Set<DayKey> recordedDays,
    int horizonDays = AppConstants.reminderHorizonDays,
  }) {
    if (!settings.reminderEnabled) return const [];

    final nowLocal = tz.TZDateTime.from(nowUtc, zone);
    final reminderTime = settings.reminderTime;
    final dayStartHour = settings.dayStartHour.value;

    final todayAtReminderTime = tz.TZDateTime(
      zone,
      nowLocal.year,
      nowLocal.month,
      nowLocal.day,
      reminderTime.hour,
      reminderTime.minute,
    );
    final startOffset = todayAtReminderTime.isAfter(nowLocal) ? 0 : 1;

    final occurrences = <ReminderOccurrence>[];
    final seenDays = <DayKey>{};

    for (var i = 0; i < horizonDays; i++) {
      final targetDate = DateTime.utc(nowLocal.year, nowLocal.month, nowLocal.day + startOffset + i);
      final scheduledLocal = tz.TZDateTime(
        zone,
        targetDate.year,
        targetDate.month,
        targetDate.day,
        reminderTime.hour,
        reminderTime.minute,
      );
      final scheduledUtc = scheduledLocal.toUtc();
      final day = _dayResolver.resolve(scheduledUtc, zone: zone, dayStartHour: dayStartHour);

      if (seenDays.contains(day)) continue;
      seenDays.add(day);
      if (recordedDays.contains(day)) continue;

      occurrences.add(ReminderOccurrence(day: day, scheduledAtUtc: scheduledUtc));
    }

    return occurrences;
  }
}
