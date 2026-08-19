import 'package:flutter_test/flutter_test.dart';
import 'package:roundtablezoo/core/constants/app_constants.dart';
import 'package:roundtablezoo/domain/entities/day_key.dart';
import 'package:roundtablezoo/domain/entities/user_settings.dart';
import 'package:roundtablezoo/domain/services/day_resolver.dart';
import 'package:roundtablezoo/domain/services/reminder_planner.dart';
import 'package:roundtablezoo/domain/value_objects/day_start_hour.dart';
import 'package:roundtablezoo/domain/value_objects/locale_preference.dart';
import 'package:roundtablezoo/domain/value_objects/reminder_time.dart';
import 'package:roundtablezoo/domain/value_objects/theme_preference.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

UserSettings _settings({
  bool reminderEnabled = true,
  ReminderTime? reminderTime,
  int dayStartHour = 0,
}) => UserSettings(
  installId: 'test',
  themeMode: ThemePreference.system,
  locale: LocalePreference.system,
  soundEnabled: true,
  enabledCharacterIds: const ['cat'],
  hasSeenOnboarding: true,
  reminderEnabled: reminderEnabled,
  reminderTime: reminderTime ?? ReminderTime.defaultValue,
  dayStartHour: DayStartHour.create(dayStartHour).valueOrGet(() => throw StateError('bad fixture')),
);

void main() {
  final planner = ReminderPlanner(dayResolver: DayResolver());
  late tz.Location kyiv;
  late tz.Location saoPaulo;

  setUpAll(() {
    tz.initializeTimeZones();
    kyiv = tz.getLocation('Europe/Kyiv');
    saoPaulo = tz.getLocation('America/Sao_Paulo');
  });

  DateTime utcOfLocal(tz.Location zone, int y, int m, int d, int h, [int min = 0]) =>
      tz.TZDateTime(zone, y, m, d, h, min).toUtc();

  group('basic behavior', () {
    test('disabled reminder yields an empty plan', () {
      final now = utcOfLocal(kyiv, 2026, 3, 10, 10);
      final occurrences = planner.plan(
        nowUtc: now,
        zone: kyiv,
        settings: _settings(reminderEnabled: false),
        recordedDays: const {},
      );
      expect(occurrences, isEmpty);
    });

    test("a firing today is included if the time hasn't passed yet", () {
      final now = utcOfLocal(kyiv, 2026, 3, 10, 10);
      final occurrences = planner.plan(
        nowUtc: now,
        zone: kyiv,
        settings: _settings(
          reminderTime: ReminderTime.create(
            hour: 20,
            minute: 0,
          ).valueOrGet(() => throw StateError('x')),
        ),
        recordedDays: const {},
      );
      expect(occurrences.first.day, const DayKey(year: 2026, month: 3, day: 10));
      expect(occurrences.first.scheduledAtUtc, utcOfLocal(kyiv, 2026, 3, 10, 20));
    });

    test('a firing today is skipped once the time has already passed', () {
      final now = utcOfLocal(kyiv, 2026, 3, 10, 21);
      final occurrences = planner.plan(
        nowUtc: now,
        zone: kyiv,
        settings: _settings(
          reminderTime: ReminderTime.create(
            hour: 20,
            minute: 0,
          ).valueOrGet(() => throw StateError('x')),
        ),
        recordedDays: const {},
      );
      expect(occurrences.first.day, const DayKey(year: 2026, month: 3, day: 11));
    });

    test('a recorded day is dropped from the plan', () {
      final now = utcOfLocal(kyiv, 2026, 3, 10, 10);
      final occurrences = planner.plan(
        nowUtc: now,
        zone: kyiv,
        settings: _settings(),
        recordedDays: {const DayKey(year: 2026, month: 3, day: 10)},
      );
      expect(occurrences.any((o) => o.day == const DayKey(year: 2026, month: 3, day: 10)), isFalse);
    });

    test(
      'the horizon is exactly AppConstants.reminderHorizonDays occurrences when none are recorded',
      () {
        final now = utcOfLocal(kyiv, 2026, 3, 10, 10);
        final occurrences = planner.plan(
          nowUtc: now,
          zone: kyiv,
          settings: _settings(),
          recordedDays: const {},
        );
        expect(occurrences, hasLength(AppConstants.reminderHorizonDays));
      },
    );

    test('a custom horizon overrides the constant', () {
      final now = utcOfLocal(kyiv, 2026, 3, 10, 10);
      final occurrences = planner.plan(
        nowUtc: now,
        zone: kyiv,
        settings: _settings(),
        recordedDays: const {},
        horizonDays: 3,
      );
      expect(occurrences, hasLength(3));
    });
  });

  group('day-start-hour boundary (FR-019a, FR-019b)', () {
    test('a reminder time before the day-start hour belongs to the previous day key', () {
      // dayStartHour = 4, reminder fires at 02:00 -> still "yesterday" per
      // DayResolver, even though the calendar date is already the next day.
      final now = utcOfLocal(kyiv, 2026, 3, 10, 10);
      final occurrences = planner.plan(
        nowUtc: now,
        zone: kyiv,
        settings: _settings(
          reminderTime: ReminderTime.create(
            hour: 2,
            minute: 0,
          ).valueOrGet(() => throw StateError('x')),
          dayStartHour: 4,
        ),
        recordedDays: const {},
      );
      final first = occurrences.first;
      expect(first.scheduledAtUtc, utcOfLocal(kyiv, 2026, 3, 11, 2));
      expect(first.day, const DayKey(year: 2026, month: 3, day: 10));
    });

    test('a reminder time exactly at the day-start hour belongs to that calendar day', () {
      final now = utcOfLocal(kyiv, 2026, 3, 10, 10);
      final occurrences = planner.plan(
        nowUtc: now,
        zone: kyiv,
        settings: _settings(
          reminderTime: ReminderTime.create(
            hour: 4,
            minute: 0,
          ).valueOrGet(() => throw StateError('x')),
          dayStartHour: 4,
        ),
        recordedDays: const {},
      );
      final first = occurrences.first;
      expect(first.scheduledAtUtc, utcOfLocal(kyiv, 2026, 3, 11, 4));
      expect(first.day, const DayKey(year: 2026, month: 3, day: 11));
    });
  });

  group('DST — America/Sao_Paulo', () {
    test('a nonexistent local time on the spring-forward day still yields exactly one firing', () {
      // 2018-11-04: 00:00 -> 01:00 skip. 00:30 doesn't exist locally.
      final now = utcOfLocal(saoPaulo, 2018, 11, 3, 10);
      final time = ReminderTime.create(hour: 0, minute: 30).valueOrGet(() => throw StateError('x'));
      final occurrences = planner.plan(
        nowUtc: now,
        zone: saoPaulo,
        settings: _settings(reminderTime: time),
        recordedDays: const {},
        horizonDays: 3,
      );
      final onSkipDay = occurrences.where(
        (o) => o.day == const DayKey(year: 2018, month: 11, day: 4),
      );
      expect(onSkipDay, hasLength(1));
    });

    test('a doubled local hour on the fall-back day still yields exactly one firing', () {
      // 2018-02-18 00:00 -> clocks fall back an hour; 23:30 on Feb 17 is
      // ambiguous (occurs twice in absolute time).
      final now = utcOfLocal(saoPaulo, 2018, 2, 16, 10);
      final time = ReminderTime.create(
        hour: 23,
        minute: 30,
      ).valueOrGet(() => throw StateError('x'));
      final occurrences = planner.plan(
        nowUtc: now,
        zone: saoPaulo,
        settings: _settings(reminderTime: time),
        recordedDays: const {},
        horizonDays: 4,
      );
      final onFoldDay = occurrences.where(
        (o) => o.day == const DayKey(year: 2018, month: 2, day: 17),
      );
      expect(onFoldDay, hasLength(1));
    });
  });

  test('a timezone change does not shift the configured wall-clock time', () {
    final now = utcOfLocal(kyiv, 2026, 6, 1, 5);
    final time = ReminderTime.create(hour: 20, minute: 0).valueOrGet(() => throw StateError('x'));

    final inKyiv = planner.plan(
      nowUtc: now,
      zone: kyiv,
      settings: _settings(reminderTime: time),
      recordedDays: const {},
    );
    final inSaoPaulo = planner.plan(
      nowUtc: now,
      zone: saoPaulo,
      settings: _settings(reminderTime: time),
      recordedDays: const {},
    );

    final kyivLocal = tz.TZDateTime.from(inKyiv.first.scheduledAtUtc, kyiv);
    final saoPauloLocal = tz.TZDateTime.from(inSaoPaulo.first.scheduledAtUtc, saoPaulo);
    expect(kyivLocal.hour, 20);
    expect(saoPauloLocal.hour, 20);
    expect(inKyiv.first.scheduledAtUtc, isNot(equals(inSaoPaulo.first.scheduledAtUtc)));
  });
}
