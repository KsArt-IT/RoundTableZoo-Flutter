import 'dart:async';

import 'package:flutter/material.dart';
import 'package:roundtablezoo/app/app_root.dart';
import 'package:roundtablezoo/core/app_clock/app_clock.dart';
import 'package:roundtablezoo/core/bootstrap/app_bootstrap.dart';
import 'package:roundtablezoo/core/bootstrap/storage_mode.dart';
import 'package:roundtablezoo/core/di/injection.dart';
import 'package:roundtablezoo/core/di/storage_di_switch.dart';
import 'package:roundtablezoo/core/notifications/notification_permission_status.dart';
import 'package:roundtablezoo/core/notifications/notification_scheduler.dart';
import 'package:roundtablezoo/core/notifications/reminder_coordinator.dart';
import 'package:roundtablezoo/core/time_zone/time_zones.dart';
import 'package:roundtablezoo/core/utils/app_logger.dart';
import 'package:roundtablezoo/data/datasources/drift/app_database.dart';
import 'package:roundtablezoo/domain/repositories/settings_repository.dart';
import 'package:roundtablezoo/presentation/storage_recovery/cubit/storage_recovery_cubit.dart';
import 'package:roundtablezoo/presentation/storage_recovery/cubit/storage_recovery_state.dart';
import 'package:roundtablezoo/presentation/storage_recovery/startup_error_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _start();
}

/// [TimeZones.initialize] and [configureDependencies] are the only startup
/// steps that aren't already failure-safe: `AppBootstrap.start` never
/// throws (it reports a broken database as `StorageMode.unavailable`
/// instead — FR-021a), but a failure here would otherwise crash before a
/// single frame is drawn. Caught and retried via [StartupErrorPage]
/// instead (FR-018a) — a path that must never fire for storage failures,
/// which have their own recovery flow (FR-021a).
Future<void> _start() async {
  try {
    await TimeZones.initialize();
    // Retrying after a partial `configureDependencies()` would otherwise
    // hit get_it's "already registered" — safe to reset since nothing has
    // read from `getIt` yet at this point in startup.
    if (getIt.isRegistered<AppClock>()) await getIt.reset();
    configureDependencies();
  } on Object catch (e, st) {
    logger.e('Non-storage startup failure', error: e, stackTrace: st);
    runApp(StartupErrorPage(onRetry: () => unawaited(_start())));
    return;
  }

  // Idempotent, storage-independent: creates the reminder channel and
  // registers the tap callback so a tap works even before the first
  // reconcile() plans anything.
  await getIt<NotificationScheduler>().initialize();
  // No cold-start deep-link handling needed here: `/table` is already
  // `initialLocation` (`app_router.dart`), so a cold start via notification
  // tap already lands on the right screen without reading
  // `getNotificationAppLaunchDetails()` (research.md, R6). Only the warm
  // path — tapping while the app is alive — needs code, via
  // `NotificationLaunchQueue`.

  final initialDatabase = AppDatabase();
  final session = (await AppBootstrap.start(initialDatabase)).valueOrGet(
    () => throw StateError('AppBootstrap.start never returns Result.failure'),
  );

  final StorageRecoveryState initialState;
  var remindersMuted = false;
  if (session.mode == StorageMode.persistent) {
    StorageDiSwitch.usePersistentStorage(initialDatabase);
    initialState = StorageRecoveryState.recovered(database: initialDatabase);

    final settings = (await getIt<SettingsRepository>().load()).valueOrNull;
    final permission = await getIt<NotificationScheduler>().permissionStatus();
    remindersMuted =
        settings != null &&
        settings.reminderEnabled &&
        permission != NotificationPermissionStatus.granted;

    unawaited(getIt<ReminderCoordinator>().reconcile());
  } else {
    // DiaryRepository/SettingsRepository stay unregistered until the user
    // picks a recovery action — the router redirects everything to
    // /storage-error until then, so nothing tries to resolve them.
    await initialDatabase.close();
    initialState = StorageRecoveryState.idle(cause: session.cause!);
  }

  runApp(
    AppRoot(
      storageRecoveryCubit: StorageRecoveryCubit(
        createDatabase: AppDatabase.new,
        initialState: initialState,
      ),
      remindersMuted: remindersMuted,
    ),
  );
}
