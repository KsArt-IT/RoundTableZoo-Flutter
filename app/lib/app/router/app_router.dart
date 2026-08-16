import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:roundtablezoo/app/router/app_routes.dart';
import 'package:roundtablezoo/app/shell/shell_page.dart';
import 'package:roundtablezoo/presentation/diary/diary_placeholder_page.dart';
import 'package:roundtablezoo/presentation/onboarding/onboarding_placeholder_page.dart';
import 'package:roundtablezoo/presentation/settings/settings_page.dart';
import 'package:roundtablezoo/presentation/storage_recovery/cubit/storage_recovery_cubit.dart';
import 'package:roundtablezoo/presentation/storage_recovery/cubit/storage_recovery_state.dart';
import 'package:roundtablezoo/presentation/storage_recovery/storage_recovery_page.dart';
import 'package:roundtablezoo/presentation/table/table_placeholder_page.dart';

/// `StatefulShellRoute.indexedStack` with three branches — switching tabs
/// preserves each branch's navigation state and never rebuilds the shell
/// (FR-002, FR-004, SC-002). `/table` is the initial location (FR-002);
/// nothing persists the last open tab across process death (FR-004a).
///
/// [storageRecoveryCubit] drives the `/storage-error` redirect: any state
/// other than `recovered`/`readOnlyAccepted` means storage isn't usable
/// yet, so every route redirects there instead of exposing a shell with
/// nothing behind it (FR-021a, FR-021b).
///
/// [refreshListenable] must be a [CubitRefreshListenable] wrapping the same
/// [storageRecoveryCubit] — the caller owns and disposes it (this function
/// doesn't, so a `GoRouter.dispose()` alone won't leak it, but forgetting
/// to dispose the listenable itself will).
GoRouter buildAppRouter({
  required StorageRecoveryCubit storageRecoveryCubit,
  required Listenable refreshListenable,
}) => GoRouter(
  initialLocation: AppRoutes.tablePath,
  refreshListenable: refreshListenable,
  redirect: (context, state) {
    final storageUsable = switch (storageRecoveryCubit.state) {
      StorageRecoveryRecovered() || StorageRecoveryReadOnlyAccepted() => true,
      StorageRecoveryIdle() || StorageRecoveryWorking() || StorageRecoveryError() => false,
    };
    final atStorageError = state.matchedLocation == AppRoutes.storageErrorPath;

    if (!storageUsable) return atStorageError ? null : AppRoutes.storageErrorPath;
    if (atStorageError) return AppRoutes.tablePath;
    return null;
  },
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) => ShellPage(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.tablePath,
              name: AppRoutes.tableName,
              builder: (context, state) => const TablePlaceholderPage(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.diaryPath,
              name: AppRoutes.diaryName,
              builder: (context, state) => const DiaryPlaceholderPage(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.settingsPath,
              name: AppRoutes.settingsName,
              builder: (context, state) => const SettingsPage(),
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: AppRoutes.onboardingPath,
      name: AppRoutes.onboardingName,
      builder: (context, state) => const OnboardingPlaceholderPage(),
    ),
    GoRoute(
      path: AppRoutes.storageErrorPath,
      name: AppRoutes.storageErrorName,
      builder: (context, state) => const StorageRecoveryPage(),
    ),
  ],
);

/// Bridges a Cubit's state stream to the `Listenable` go_router's
/// `redirect` expects to be re-evaluated against. The caller owns this and
/// must call [dispose] itself (e.g. alongside the `GoRouter` it feeds).
class CubitRefreshListenable extends ChangeNotifier {
  CubitRefreshListenable(Stream<Object?> stream) {
    _subscription = stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<Object?> _subscription;

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    super.dispose();
  }
}
