import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:roundtablezoo/app/app_root.dart';
import 'package:roundtablezoo/core/app_clock/app_clock.dart';
import 'package:roundtablezoo/core/di/injection.dart';
import 'package:roundtablezoo/core/di/storage_di_switch.dart';
import 'package:roundtablezoo/core/errors/result.dart';
import 'package:roundtablezoo/core/notifications/notification_permission_status.dart';
import 'package:roundtablezoo/core/notifications/notification_scheduler.dart';
import 'package:roundtablezoo/data/datasources/drift/app_database.dart';
import 'package:roundtablezoo/domain/entities/day_key.dart';
import 'package:roundtablezoo/domain/entities/reminder_occurrence.dart';
import 'package:roundtablezoo/domain/repositories/settings_repository.dart';
import 'package:roundtablezoo/domain/services/day_resolver.dart';
import 'package:roundtablezoo/presentation/app_settings/cubit/app_settings_cubit.dart';
import 'package:roundtablezoo/presentation/app_settings/cubit/current_day_cubit.dart';
import 'package:roundtablezoo/presentation/onboarding/cubit/onboarding_cubit.dart';
import 'package:roundtablezoo/presentation/onboarding/cubit/onboarding_state.dart';
import 'package:roundtablezoo/presentation/storage_recovery/cubit/storage_recovery_cubit.dart';
import 'package:roundtablezoo/presentation/storage_recovery/cubit/storage_recovery_state.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'fake_app_clock.dart';
import 'mocks.dart';

/// An [AppRoot] whose `StorageRecoveryCubit` already starts `recovered` —
/// widget tests that exercise the shell shouldn't have to know about the
/// storage-recovery flow at all.
///
/// `RootBlocListener` only reacts to state *transitions*, not the initial
/// state, so — mirroring what `main.dart` does before constructing the
/// cubit for a cold-start `recovered` session — this registers the
/// storage-backed DI graph itself. Skip that by passing a non-`recovered`
/// [initialState] if a test needs `DiaryRepository`/`SettingsRepository`
/// left unregistered.
///
/// Also runs `configureDependencies()` once per isolate (idempotent, guarded
/// by [AppClock] presence) — `AppMaterialRouter` reads `AppSettingsCubit`
/// unconditionally via `BlocBuilder`, so it must already be resolvable by
/// the time `AppRoot` builds.
///
/// [onboardingSeen] defaults to `true` — existing shell widget tests
/// shouldn't have to know about onboarding at all; each call's fresh
/// in-memory database would otherwise default `hasSeenOnboarding` to
/// `false` and send every one of them to `/onboarding` instead
/// (research.md, R7). Pass `false` for gate tests that need to start there.
Widget buildTestAppRoot({
  StorageRecoveryState? initialState,
  bool remindersMuted = false,
  bool onboardingSeen = true,
}) {
  if (!getIt.isRegistered<AppClock>()) {
    // `main.dart` sets this via `TimeZones.initialize()` before
    // `configureDependencies()` runs — its platform channel has no
    // responder under `flutter test`, so `InjectionModule.appClock`
    // (`tz.local`) would otherwise throw `LateInitializationError` the
    // first time anything actually builds `CurrentDayCubit`/`TableCubit`
    // through `getIt` (research.md R13, `project/process/lessons-learned.md`).
    tzdata.initializeTimeZones();
    tz.setLocalLocation(tz.UTC);
    configureDependencies();

    // `InjectionModule.appClock` registers the real `SystemAppClock`,
    // which arms a genuine `Timer` for the next minute boundary on
    // construction — meant to outlive the whole app, so it's never
    // cancelled. The Table screen (`specs/004-table-screen`) is the first
    // widget-tree code to actually resolve `AppClock` (via
    // `DiaryRepository`/`CurrentDayCubit`), and that Timer then outlives
    // whichever test first triggers it, tripping
    // `TestWidgetsFlutterBinding`'s "no pending timers" invariant no
    // matter how many frames get pumped. Swapped for `FakeAppClock` here
    // — same one-time-per-isolate registration as everything else in this
    // block — so no widget test ever constructs a real `SystemAppClock`.
    unawaited(Future.value(getIt.unregister<AppClock>()));
    getIt.registerLazySingleton<AppClock>(
      () => FakeAppClock(now: DateTime.utc(2026), location: tz.UTC),
    );
  }
  _useFakeNotificationScheduler();

  final database = AppDatabase(NativeDatabase.memory());
  final resolvedInitialState = initialState ?? StorageRecoveryState.recovered(database: database);
  if (resolvedInitialState is StorageRecoveryRecovered) {
    StorageDiSwitch.usePersistentStorage(resolvedInitialState.database);

    // `AppSettingsCubit` is a `@lazySingleton` — correct in the app (one
    // instance for its lifetime), but each `buildTestAppRoot()` call is a
    // fresh "app instance" with its own `SettingsRepository`. Without this,
    // the second test in a file would read a cubit still wired to the
    // first test's (by-then-closed) repository and never see its changes.
    if (getIt.isRegistered<AppSettingsCubit>()) unawaited(Future.value(getIt.unregister<AppSettingsCubit>()));
    getIt.registerLazySingleton<AppSettingsCubit>(
      () => AppSettingsCubit(settingsRepository: getIt<SettingsRepository>()),
    );

    // Same freshening reasoning as `AppSettingsCubit` above: a fresh
    // `CurrentDayCubit` per call, tied to this call's `SettingsRepository`
    // — the Table screen (`specs/004-table-screen`) reads it via
    // `BlocListener` (research.md R13).
    if (getIt.isRegistered<CurrentDayCubit>()) unawaited(Future.value(getIt.unregister<CurrentDayCubit>()));
    getIt.registerLazySingleton<CurrentDayCubit>(
      () => CurrentDayCubit(
        clock: getIt<AppClock>(),
        dayResolver: getIt<DayResolver>(),
        settingsRepository: getIt<SettingsRepository>(),
      ),
    );
  }

  // Same freshening reasoning as `AppSettingsCubit` above — a fresh
  // `OnboardingCubit` per call, tied to this call's `SettingsRepository`.
  if (getIt.isRegistered<OnboardingCubit>()) unawaited(Future.value(getIt.unregister<OnboardingCubit>()));
  getIt.registerLazySingleton<OnboardingCubit>(
    () => OnboardingCubit(
      settingsRepositoryLocator: () => getIt<SettingsRepository>(),
      initialState: onboardingSeen ? const OnboardingState.completed() : const OnboardingState.required(),
    ),
  );

  return AppRoot(
    storageRecoveryCubit: StorageRecoveryCubit(
      createDatabase: () => AppDatabase(NativeDatabase.memory()),
      initialState: resolvedInitialState,
    ),
    onboardingCubit: getIt<OnboardingCubit>(),
    remindersMuted: remindersMuted,
  );
}

/// `AppMaterialRouter` reads `AppSettingsCubit` via `BlocBuilder`, so every
/// test built with [buildTestAppRoot] actually builds and closes it.
/// `AppSettingsCubit.close()` cancels a real Drift `watch()` subscription,
/// which schedules a zero-duration `Timer` internally — harmless in the app,
/// but `TestWidgetsFlutterBinding`'s own end-of-test teardown disposes the
/// tree with a `pump()` call that uses a `null` duration (never elapses
/// fake time), so that Timer is still "pending" when the binding asserts
/// none are — and `addTearDown` runs too late to help, after that check.
/// Call this as the last step of the test body (not via `addTearDown`) to
/// dispose deterministically and flush the Timer before the test returns.
/// `CurrentDayCubit.close()` (`specs/004-table-screen`) cancels its own
/// Drift `watch()` subscription the same way — same fix, same reason.
Future<void> disposeTestAppRoot(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration());
}

/// `NotificationScheduler`'s real implementation talks to the
/// `flutter_local_notifications` platform channel, which has no responder
/// under `flutter test` — any widget test that reaches `/settings` would
/// otherwise throw `MissingPluginException`. A fresh stubbed mock per call
/// keeps widget tests hermetic and avoids one test's stubbing leaking into
/// the next (mirrors the `AppSettingsCubit` freshening above).
void _useFakeNotificationScheduler() {
  registerFallbackValue(ReminderOccurrence(day: DayKey.fromDateTime(DateTime(2026)), scheduledAtUtc: DateTime(2026)));

  if (getIt.isRegistered<NotificationScheduler>()) {
    unawaited(Future.value(getIt.unregister<NotificationScheduler>()));
  }
  final scheduler = MockNotificationScheduler();
  when(() => scheduler.initialize()).thenAnswer((_) async => const Result.success(null));
  when(
    () => scheduler.permissionStatus(),
  ).thenAnswer((_) async => NotificationPermissionStatus.unknown);
  when(
    () => scheduler.requestPermission(),
  ).thenAnswer((_) async => NotificationPermissionStatus.granted);
  when(() => scheduler.openSystemSettings()).thenAnswer((_) async => const Result.success(null));
  when(() => scheduler.pendingIds()).thenAnswer((_) async => const Result.success(<int>{}));
  when(
    () => scheduler.schedule(any(), title: any(named: 'title'), body: any(named: 'body')),
  ).thenAnswer((_) async => const Result.success(null));
  when(() => scheduler.cancel(any())).thenAnswer((_) async => const Result.success(null));
  getIt.registerLazySingleton<NotificationScheduler>(() => scheduler);
}
