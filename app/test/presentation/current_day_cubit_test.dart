import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:roundtablezoo/domain/entities/day_key.dart';
import 'package:roundtablezoo/domain/entities/user_settings.dart';
import 'package:roundtablezoo/domain/services/day_resolver.dart';
import 'package:roundtablezoo/domain/value_objects/day_start_hour.dart';
import 'package:roundtablezoo/domain/value_objects/locale_preference.dart';
import 'package:roundtablezoo/domain/value_objects/reminder_time.dart';
import 'package:roundtablezoo/domain/value_objects/theme_preference.dart';
import 'package:roundtablezoo/presentation/app_settings/cubit/current_day_cubit.dart';
import 'package:roundtablezoo/presentation/app_settings/cubit/current_day_state.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../support/fake_app_clock.dart';
import '../support/mocks.dart';

UserSettings _settingsWith(DayStartHour dayStartHour) => UserSettings(
  installId: 'test',
  themeMode: ThemePreference.system,
  locale: LocalePreference.system,
  soundEnabled: true,
  enabledCharacterIds: const ['cat'],
  hasSeenOnboarding: false,
  reminderEnabled: false,
  reminderTime: ReminderTime.defaultValue,
  dayStartHour: dayStartHour,
);

DayStartHour _hour(int value) => DayStartHour.create(value).valueOrGet(() => throw StateError('bad fixture'));

void main() {
  late FakeAppClock clock;
  late MockSettingsRepository settingsRepository;
  late tz.Location kyiv;

  setUpAll(() {
    tzdata.initializeTimeZones();
    kyiv = tz.getLocation('Europe/Kyiv');
  });

  setUp(() {
    settingsRepository = MockSettingsRepository();
    when(() => settingsRepository.watch()).thenAnswer((_) => Stream.value(_settingsWith(_hour(0))));
  });

  tearDown(() => clock.dispose());

  CurrentDayCubit buildCubit() {
    clock = FakeAppClock(now: DateTime.utc(2026, 3, 10, 10), location: kyiv);
    return CurrentDayCubit(
      clock: clock,
      dayResolver: DayResolver(),
      settingsRepository: settingsRepository,
    );
  }

  blocTest<CurrentDayCubit, CurrentDayState>(
    'a tick crossing midnight (dayStartHour = 0) changes the day',
    build: buildCubit,
    act: (cubit) => clock.emitTick(DateTime.utc(2026, 3, 10, 22)), // 00:00 Kyiv (3/11)
    expect: () => [const CurrentDayState.day(key: DayKey(year: 2026, month: 3, day: 11))],
  );

  blocTest<CurrentDayCubit, CurrentDayState>(
    'a tick within the same day does not emit',
    build: buildCubit,
    act: (cubit) => clock.emitTick(DateTime.utc(2026, 3, 10, 11)), // still 13:00 Kyiv, same date
    expect: () => <CurrentDayState>[],
  );

  group('dayStartHour = 4', () {
    setUp(() {
      when(
        () => settingsRepository.watch(),
      ).thenAnswer((_) => Stream.value(_settingsWith(_hour(4))));
    });

    blocTest<CurrentDayCubit, CurrentDayState>(
      'a tick at 02:00 local still belongs to the previous day',
      build: buildCubit,
      act: (cubit) => clock.emitTick(DateTime.utc(2026, 3, 10, 22)), // 00:00 Kyiv (3/11)
      expect: () => <CurrentDayState>[],
    );

    blocTest<CurrentDayCubit, CurrentDayState>(
      'a tick at 04:00 local rolls onto the next day',
      build: buildCubit,
      act: (cubit) => clock.emitTick(DateTime.utc(2026, 3, 11, 2)), // 04:00 Kyiv (3/11)
      expect: () => [const CurrentDayState.day(key: DayKey(year: 2026, month: 3, day: 11))],
    );
  });

  blocTest<CurrentDayCubit, CurrentDayState>(
    // FR-026a: `AppClock` exposes no location-change stream, so a timezone
    // change only takes effect via an explicit refresh() (app_root.dart
    // calls this on AppLifecycleState.resumed, right after updateLocation).
    'refresh() after a timezone change recomputes the day for the current instant',
    build: buildCubit,
    act: (cubit) {
      // Construction resolved 2026-03-10T10:00Z in Kyiv (UTC+2, local
      // 12:00) to day 2026-03-10. Pacific/Midway (UTC-11) puts the same
      // instant at local 23:00 on 2026-03-09 — a different day.
      clock.updateLocation(tz.getLocation('Pacific/Midway'));
      cubit.refresh();
    },
    expect: () => [const CurrentDayState.day(key: DayKey(year: 2026, month: 3, day: 9))],
  );

  test('does not emit after the cubit is closed', () async {
    final cubit = buildCubit();
    final closeFuture = cubit.close();
    clock.emitTick(DateTime.utc(2026, 3, 10, 22));
    await closeFuture;
    expect(cubit.isClosed, isTrue);
  });
}
