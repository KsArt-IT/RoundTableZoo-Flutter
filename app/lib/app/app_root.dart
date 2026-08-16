import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:go_router/go_router.dart';
import 'package:roundtablezoo/app/app_material_router.dart';
import 'package:roundtablezoo/app/router/app_router.dart';
import 'package:roundtablezoo/app/router/app_routes.dart';
import 'package:roundtablezoo/core/app_clock/app_clock.dart';
import 'package:roundtablezoo/core/di/injection.dart';
import 'package:roundtablezoo/core/notifications/notification_launch_queue.dart';
import 'package:roundtablezoo/core/notifications/reminder_coordinator.dart';
import 'package:roundtablezoo/domain/repositories/settings_repository.dart';
import 'package:roundtablezoo/presentation/app_settings/cubit/app_settings_cubit.dart';
import 'package:roundtablezoo/presentation/app_settings/cubit/current_day_cubit.dart';
import 'package:roundtablezoo/presentation/storage_recovery/cubit/storage_recovery_cubit.dart';
import 'package:timezone/timezone.dart' as tz;

/// Application entry widget. [storageRecoveryCubit] is app-scoped and
/// already carries the outcome of the startup `AppBootstrap.start()` probe
/// (`main.dart`) — the shell, the recovery screen, and the read-only banner
/// all read from this one instance.
///
/// `CurrentDayCubit` is provided lazily from `getIt` — it isn't actually
/// built until something reads it, which never happens before storage is
/// usable (the router redirects everything to `/storage-error` until
/// then), so its `SettingsRepository` dependency is always ready by the
/// time it's needed.
///
/// `AppSettingsCubit` is provided the same lazy way, feeding
/// `AppMaterialRouter`'s `themeMode`/`locale` (US5).
class AppRoot extends StatelessWidget {
  const AppRoot({required this.storageRecoveryCubit, this.remindersMuted = false, super.key});

  final StorageRecoveryCubit storageRecoveryCubit;

  /// FR-021b: reminder enabled but permission not granted, computed once at
  /// startup (`main.dart`) before this widget is built.
  final bool remindersMuted;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: storageRecoveryCubit),
        // `create:` (not `.value()`) so building it stays lazy — but that
        // also means flutter_bloc will `close()` it if this provider is
        // ever removed from the tree while resolved. AppRoot is the root
        // widget and never unmounts in production, so that never happens
        // there; it only matters if a test rebuilds AppRoot after reading
        // this cubit, which would leave the cached getIt<CurrentDayCubit>()
        // singleton closed for the rest of the test run.
        BlocProvider(create: (_) => getIt<CurrentDayCubit>()),
        BlocProvider(create: (_) => getIt<AppSettingsCubit>()),
      ],
      child: _RoutedApp(storageRecoveryCubit: storageRecoveryCubit, remindersMuted: remindersMuted),
    );
  }
}

class _RoutedApp extends StatefulWidget {
  const _RoutedApp({required this.storageRecoveryCubit, required this.remindersMuted});

  final StorageRecoveryCubit storageRecoveryCubit;
  final bool remindersMuted;

  @override
  State<_RoutedApp> createState() => _RoutedAppState();
}

class _RoutedAppState extends State<_RoutedApp> with WidgetsBindingObserver {
  late final CubitRefreshListenable _refreshListenable = CubitRefreshListenable(
    widget.storageRecoveryCubit.stream,
  );
  late final GoRouter _router = buildAppRouter(
    storageRecoveryCubit: widget.storageRecoveryCubit,
    refreshListenable: _refreshListenable,
  );
  StreamSubscription<String>? _notificationTapSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Warm path only (FR-017): a tap while the app is alive. Cold start
    // already lands on `/table` via `initialLocation` (research.md, R6).
    _notificationTapSubscription = getIt<NotificationLaunchQueue>().taps.listen(
      (_) => _router.go(AppRoutes.tablePath),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_onResumed());
  }

  /// Re-reads the system timezone and, if it changed while backgrounded,
  /// updates `AppClock` and asks `CurrentDayCubit` to recompute without
  /// waiting for the next tick (FR-026a).
  Future<void> _onResumed() async {
    final clock = getIt<AppClock>();
    final systemTimezone = await FlutterTimezone.getLocalTimezone();
    final systemLocation = tz.getLocation(systemTimezone.identifier);
    if (systemLocation.name != clock.location.name) {
      clock.updateLocation(systemLocation);
    }

    // Guards against building CurrentDayCubit/ReminderCoordinator (and
    // their SettingsRepository dependency) before storage is usable —
    // resuming while still stuck on /storage-error must not crash.
    if (getIt.isRegistered<SettingsRepository>()) {
      getIt<CurrentDayCubit>().refresh();
      // Must run after `updateLocation` above — otherwise the reminder
      // plan would be computed in the stale timezone (FR-025).
      unawaited(getIt<ReminderCoordinator>().reconcile());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_notificationTapSubscription?.cancel());
    _router.dispose();
    _refreshListenable.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      AppMaterialRouter(router: _router, remindersMuted: widget.remindersMuted);
}
