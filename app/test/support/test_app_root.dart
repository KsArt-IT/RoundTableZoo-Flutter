import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roundtablezoo/app/app_root.dart';
import 'package:roundtablezoo/core/app_clock/app_clock.dart';
import 'package:roundtablezoo/core/di/injection.dart';
import 'package:roundtablezoo/core/di/storage_di_switch.dart';
import 'package:roundtablezoo/data/datasources/drift/app_database.dart';
import 'package:roundtablezoo/domain/repositories/settings_repository.dart';
import 'package:roundtablezoo/presentation/app_settings/cubit/app_settings_cubit.dart';
import 'package:roundtablezoo/presentation/storage_recovery/cubit/storage_recovery_cubit.dart';
import 'package:roundtablezoo/presentation/storage_recovery/cubit/storage_recovery_state.dart';

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
Widget buildTestAppRoot({StorageRecoveryState? initialState}) {
  if (!getIt.isRegistered<AppClock>()) configureDependencies();

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
  }

  return AppRoot(
    storageRecoveryCubit: StorageRecoveryCubit(
      createDatabase: () => AppDatabase(NativeDatabase.memory()),
      initialState: resolvedInitialState,
    ),
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
Future<void> disposeTestAppRoot(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration());
}
