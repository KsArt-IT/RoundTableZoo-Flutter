import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:roundtablezoo/core/errors/app_failure.dart';
import 'package:roundtablezoo/core/errors/result.dart';
import 'package:roundtablezoo/domain/entities/user_settings.dart';
import 'package:roundtablezoo/domain/value_objects/day_start_hour.dart';
import 'package:roundtablezoo/domain/value_objects/locale_preference.dart';
import 'package:roundtablezoo/domain/value_objects/reminder_time.dart';
import 'package:roundtablezoo/domain/value_objects/theme_preference.dart';
import 'package:roundtablezoo/presentation/onboarding/cubit/onboarding_cubit.dart';
import 'package:roundtablezoo/presentation/onboarding/cubit/onboarding_state.dart';

import '../support/mocks.dart';

UserSettings _settings({required bool hasSeenOnboarding}) => UserSettings(
  installId: 'test',
  themeMode: ThemePreference.system,
  locale: LocalePreference.system,
  soundEnabled: true,
  enabledCharacterIds: const ['cat'],
  hasSeenOnboarding: hasSeenOnboarding,
  reminderEnabled: false,
  reminderTime: ReminderTime.defaultValue,
  dayStartHour: DayStartHour.defaultValue,
);

const _writeFailure = DatabaseFailure(null, code: DatabaseFailure.storageUnavailable);

void main() {
  late MockSettingsRepository settingsRepository;

  setUp(() {
    settingsRepository = MockSettingsRepository();
  });

  group('resolve()', () {
    blocTest<OnboardingCubit, OnboardingState>(
      'from unknown, a flag of false emits required (C1)',
      build: () {
        when(() => settingsRepository.load()).thenAnswer((_) async => Result.success(_settings(hasSeenOnboarding: false)));
        return OnboardingCubit(
          settingsRepositoryLocator: () => settingsRepository,
          initialState: const OnboardingState.unknown(),
        );
      },
      act: (cubit) => cubit.resolve(),
      expect: () => [const OnboardingState.required()],
    );

    blocTest<OnboardingCubit, OnboardingState>(
      'from unknown, a flag of true emits completed (C1)',
      build: () {
        when(() => settingsRepository.load()).thenAnswer((_) async => Result.success(_settings(hasSeenOnboarding: true)));
        return OnboardingCubit(
          settingsRepositoryLocator: () => settingsRepository,
          initialState: const OnboardingState.unknown(),
        );
      },
      act: (cubit) => cubit.resolve(),
      expect: () => [const OnboardingState.completed()],
    );

    blocTest<OnboardingCubit, OnboardingState>(
      'a Result.failure from a registered repository emits required, not unknown (C8, FR-001a)',
      build: () {
        when(() => settingsRepository.load()).thenAnswer((_) async => const Result.failure(_writeFailure));
        return OnboardingCubit(
          settingsRepositoryLocator: () => settingsRepository,
          initialState: const OnboardingState.unknown(),
        );
      },
      act: (cubit) => cubit.resolve(),
      expect: () => [const OnboardingState.required()],
    );

    blocTest<OnboardingCubit, OnboardingState>(
      'an unavailable locator leaves the state unknown and does not throw (C5)',
      build: () => OnboardingCubit(
        settingsRepositoryLocator: () => throw StateError('SettingsRepository not registered'),
        initialState: const OnboardingState.unknown(),
      ),
      act: (cubit) => cubit.resolve(),
      expect: () => <OnboardingState>[],
      verify: (cubit) => expect(cubit.state, const OnboardingState.unknown()),
    );

    blocTest<OnboardingCubit, OnboardingState>(
      'is a no-op outside unknown (R3)',
      build: () => OnboardingCubit(
        settingsRepositoryLocator: () => settingsRepository,
        initialState: const OnboardingState.required(),
      ),
      act: (cubit) => cubit.resolve(),
      expect: () => <OnboardingState>[],
      verify: (_) => verifyNever(() => settingsRepository.load()),
    );
  });

  group('complete()', () {
    blocTest<OnboardingCubit, OnboardingState>(
      'required -> submitting -> completed on a successful write',
      build: () {
        when(() => settingsRepository.markOnboardingSeen()).thenAnswer((_) async => Result.success(_settings(hasSeenOnboarding: true)));
        return OnboardingCubit(
          settingsRepositoryLocator: () => settingsRepository,
          initialState: const OnboardingState.required(),
        );
      },
      act: (cubit) => cubit.complete(),
      expect: () => [const OnboardingState.submitting(), const OnboardingState.completed()],
    );

    blocTest<OnboardingCubit, OnboardingState>(
      'reaches completed even when the write fails (C2, FR-006)',
      build: () {
        when(() => settingsRepository.markOnboardingSeen()).thenAnswer((_) async => const Result.failure(_writeFailure));
        return OnboardingCubit(
          settingsRepositoryLocator: () => settingsRepository,
          initialState: const OnboardingState.required(),
        );
      },
      act: (cubit) => cubit.complete(),
      expect: () => [const OnboardingState.submitting(), const OnboardingState.completed()],
    );

    blocTest<OnboardingCubit, OnboardingState>(
      'a second complete() while submitting does not call the repository again (C3)',
      build: () {
        when(() => settingsRepository.markOnboardingSeen()).thenAnswer((_) async {
          await Future<void>.delayed(const Duration(milliseconds: 20));
          return Result.success(_settings(hasSeenOnboarding: true));
        });
        return OnboardingCubit(
          settingsRepositoryLocator: () => settingsRepository,
          initialState: const OnboardingState.required(),
        );
      },
      act: (cubit) async {
        final first = cubit.complete();
        await cubit.complete();
        await first;
      },
      expect: () => [const OnboardingState.submitting(), const OnboardingState.completed()],
      verify: (_) => verify(() => settingsRepository.markOnboardingSeen()).called(1),
    );

    blocTest<OnboardingCubit, OnboardingState>(
      'complete() while already completed does not call the repository again (C4, C3)',
      build: () => OnboardingCubit(
        settingsRepositoryLocator: () => settingsRepository,
        initialState: const OnboardingState.completed(),
      ),
      act: (cubit) => cubit.complete(),
      expect: () => <OnboardingState>[],
      verify: (_) => verifyNever(() => settingsRepository.markOnboardingSeen()),
    );

    blocTest<OnboardingCubit, OnboardingState>(
      'resolve() does not roll completed back to required (C4)',
      build: () {
        when(() => settingsRepository.load()).thenAnswer((_) async => Result.success(_settings(hasSeenOnboarding: false)));
        return OnboardingCubit(
          settingsRepositoryLocator: () => settingsRepository,
          initialState: const OnboardingState.completed(),
        );
      },
      act: (cubit) => cubit.resolve(),
      expect: () => <OnboardingState>[],
      verify: (cubit) => expect(cubit.state, const OnboardingState.completed()),
    );

    blocTest<OnboardingCubit, OnboardingState>(
      'a write that never responds still reaches completed after writeTimeout (C7, FR-005b, SC-003)',
      build: () {
        when(() => settingsRepository.markOnboardingSeen()).thenAnswer((_) => Completer<Result<UserSettings>>().future);
        return OnboardingCubit(
          settingsRepositoryLocator: () => settingsRepository,
          initialState: const OnboardingState.required(),
          writeTimeout: const Duration(milliseconds: 20),
        );
      },
      act: (cubit) => cubit.complete(),
      expect: () => [const OnboardingState.submitting(), const OnboardingState.completed()],
    );

    test('does not emit after the cubit is closed', () async {
      when(() => settingsRepository.markOnboardingSeen()).thenAnswer((_) async => Result.success(_settings(hasSeenOnboarding: true)));
      final cubit = OnboardingCubit(
        settingsRepositoryLocator: () => settingsRepository,
        initialState: const OnboardingState.required(),
      );

      final future = cubit.complete();
      await cubit.close();
      expect(cubit.isClosed, isTrue);
      await future;
    });
  });
}
