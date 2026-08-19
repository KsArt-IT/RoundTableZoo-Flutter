import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:roundtablezoo/core/errors/app_failure.dart';
import 'package:roundtablezoo/core/errors/result.dart';
import 'package:roundtablezoo/core/notifications/notification_permission_status.dart';
import 'package:roundtablezoo/domain/entities/user_settings.dart';
import 'package:roundtablezoo/domain/value_objects/day_start_hour.dart';
import 'package:roundtablezoo/domain/value_objects/locale_preference.dart';
import 'package:roundtablezoo/domain/value_objects/reminder_time.dart';
import 'package:roundtablezoo/domain/value_objects/theme_preference.dart';
import 'package:roundtablezoo/presentation/settings/cubit/settings_cubit.dart';
import 'package:roundtablezoo/presentation/settings/cubit/settings_state.dart';

import '../support/mocks.dart';

const _settings = UserSettings(
  installId: 'test',
  themeMode: ThemePreference.system,
  locale: LocalePreference.system,
  soundEnabled: true,
  enabledCharacterIds: ['cat'],
  hasSeenOnboarding: true,
  reminderEnabled: false,
  reminderTime: ReminderTime.defaultValue,
  dayStartHour: DayStartHour.defaultValue,
);

void main() {
  late MockSettingsRepository settingsRepository;
  late MockNotificationScheduler notificationScheduler;

  setUpAll(() {
    registerFallbackValue(ThemePreference.system);
  });

  setUp(() {
    settingsRepository = MockSettingsRepository();
    notificationScheduler = MockNotificationScheduler();
    when(() => settingsRepository.watch()).thenAnswer((_) => Stream.value(_settings));
    when(
      () => notificationScheduler.permissionStatus(),
    ).thenAnswer((_) async => NotificationPermissionStatus.unknown);
  });

  SettingsCubit build() => SettingsCubit(
    settingsRepository: settingsRepository,
    notificationScheduler: notificationScheduler,
  );

  test('a fresh install defaults to reminder disabled at 20:00', () async {
    final cubit = build();
    await pumpEventQueue();

    final state = cubit.state as SettingsLoaded;
    expect(state.settings.reminderEnabled, isFalse);
    expect(state.settings.reminderTime, ReminderTime.defaultValue);
    await cubit.close();
  });

  blocTest<SettingsCubit, SettingsState>(
    'watch() emitting settings transitions to loaded with the current permission',
    build: build,
    wait: const Duration(milliseconds: 1),
    expect: () => [
      isA<SettingsLoaded>()
          .having((s) => s.settings, 'settings', _settings)
          .having((s) => s.permission, 'permission', NotificationPermissionStatus.unknown),
    ],
  );

  blocTest<SettingsCubit, SettingsState>(
    'a watch() stream error transitions to error',
    setUp: () {
      when(
        () => settingsRepository.watch(),
      ).thenAnswer((_) => Stream.error(const DatabaseFailure(null, code: 'boom')));
    },
    build: build,
    expect: () => [isA<SettingsError>()],
  );

  blocTest<SettingsCubit, SettingsState>(
    'setThemeMode success does not itself emit — watch() re-emission does',
    setUp: () {
      when(
        () => settingsRepository.updateThemeMode(any()),
      ).thenAnswer((_) async => const Result.success(_settings));
    },
    build: build,
    wait: const Duration(milliseconds: 1),
    act: (cubit) => cubit.setThemeMode(ThemePreference.dark),
    expect: () => [isA<SettingsLoaded>()],
  );

  test('setThemeMode failure surfaces on the failures stream, state unchanged', () async {
    when(
      () => settingsRepository.updateThemeMode(any()),
    ).thenAnswer((_) async => const Result.failure(DatabaseFailure(null, code: 'boom')));
    final cubit = build();
    await pumpEventQueue();
    final before = cubit.state;

    final failures = <AppFailure>[];
    final subscription = cubit.failures.listen(failures.add);

    await cubit.setThemeMode(ThemePreference.dark);
    await pumpEventQueue();

    expect(cubit.state, before);
    expect(failures, hasLength(1));
    await subscription.cancel();
    await cubit.close();
  });

  group('setReminderEnabled', () {
    test('enabling while unknown requests permission and saves regardless of the answer', () async {
      when(
        () => notificationScheduler.requestPermission(),
      ).thenAnswer((_) async => NotificationPermissionStatus.granted);
      when(
        () => settingsRepository.updateReminderEnabled(value: any(named: 'value')),
      ).thenAnswer((_) async => const Result.success(_settings));
      final cubit = build();
      await pumpEventQueue();

      await cubit.setReminderEnabled(value: true);

      verify(() => notificationScheduler.requestPermission()).called(1);
      verify(() => settingsRepository.updateReminderEnabled(value: true)).called(1);
      expect((cubit.state as SettingsLoaded).permission, NotificationPermissionStatus.granted);
      await cubit.close();
    });

    test('enabling while already denied does not repeat the system prompt', () async {
      when(
        () => notificationScheduler.permissionStatus(),
      ).thenAnswer((_) async => NotificationPermissionStatus.denied);
      when(
        () => settingsRepository.updateReminderEnabled(value: any(named: 'value')),
      ).thenAnswer((_) async => const Result.success(_settings));
      final cubit = build();
      await pumpEventQueue();

      await cubit.setReminderEnabled(value: true);

      verifyNever(() => notificationScheduler.requestPermission());
      verify(() => settingsRepository.updateReminderEnabled(value: true)).called(1);
      await cubit.close();
    });
  });

  test('refreshPermissionStatus re-reads and reflects the current status', () async {
    when(
      () => notificationScheduler.permissionStatus(),
    ).thenAnswer((_) async => NotificationPermissionStatus.unknown);
    final cubit = build();
    await pumpEventQueue();
    expect((cubit.state as SettingsLoaded).permission, NotificationPermissionStatus.unknown);

    when(
      () => notificationScheduler.permissionStatus(),
    ).thenAnswer((_) async => NotificationPermissionStatus.granted);
    await cubit.refreshPermissionStatus();

    expect((cubit.state as SettingsLoaded).permission, NotificationPermissionStatus.granted);
    await cubit.close();
  });

  test('does not emit after the cubit is closed', () async {
    final controller = StreamController<UserSettings>();
    when(() => settingsRepository.watch()).thenAnswer((_) => controller.stream);
    final cubit = build();

    final closeFuture = cubit.close();
    controller.add(_settings);
    await closeFuture;

    expect(cubit.isClosed, isTrue);
    await controller.close();
  });
}
