import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:roundtablezoo/core/errors/app_failure.dart';
import 'package:roundtablezoo/domain/entities/user_settings.dart';
import 'package:roundtablezoo/domain/value_objects/day_start_hour.dart';
import 'package:roundtablezoo/domain/value_objects/locale_preference.dart';
import 'package:roundtablezoo/domain/value_objects/reminder_time.dart';
import 'package:roundtablezoo/domain/value_objects/theme_preference.dart';
import 'package:roundtablezoo/presentation/app_settings/cubit/app_settings_cubit.dart';
import 'package:roundtablezoo/presentation/app_settings/cubit/app_settings_state.dart';

import '../support/mocks.dart';

const _settings = UserSettings(
  installId: 'test',
  themeMode: ThemePreference.dark,
  locale: LocalePreference.uk,
  soundEnabled: true,
  enabledCharacterIds: ['cat'],
  hasSeenOnboarding: false,
  reminderEnabled: false,
  reminderTime: ReminderTime.defaultValue,
  dayStartHour: DayStartHour.defaultValue,
);

void main() {
  late MockSettingsRepository settingsRepository;

  setUp(() {
    settingsRepository = MockSettingsRepository();
  });

  blocTest<AppSettingsCubit, AppSettingsState>(
    'watch() emitting settings transitions to loaded',
    build: () {
      when(() => settingsRepository.watch()).thenAnswer((_) => Stream.value(_settings));
      return AppSettingsCubit(settingsRepository: settingsRepository);
    },
    expect: () => [const AppSettingsState.loaded(settings: _settings)],
  );

  blocTest<AppSettingsCubit, AppSettingsState>(
    'a watch() stream error transitions to error and falls back to system theme/locale',
    build: () {
      when(
        () => settingsRepository.watch(),
      ).thenAnswer((_) => Stream.error(const DatabaseFailure(null, code: 'boom')));
      return AppSettingsCubit(settingsRepository: settingsRepository);
    },
    expect: () => [isA<AppSettingsError>()],
    verify: (cubit) {
      expect(cubit.state.themeMode, ThemeMode.system);
      expect(cubit.state.locale, isNull);
    },
  );

  test('does not emit after the cubit is closed', () async {
    final controller = StreamController<UserSettings>();
    when(() => settingsRepository.watch()).thenAnswer((_) => controller.stream);
    final cubit = AppSettingsCubit(settingsRepository: settingsRepository);

    final closeFuture = cubit.close();
    controller.add(_settings);
    await closeFuture;

    expect(cubit.isClosed, isTrue);
    await controller.close();
  });
}
