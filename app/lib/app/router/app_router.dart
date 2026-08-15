import 'package:go_router/go_router.dart';
import 'package:roundtablezoo/app/router/app_routes.dart';
import 'package:roundtablezoo/app/shell/shell_page.dart';
import 'package:roundtablezoo/presentation/diary/diary_placeholder_page.dart';
import 'package:roundtablezoo/presentation/onboarding/onboarding_placeholder_page.dart';
import 'package:roundtablezoo/presentation/settings/settings_placeholder_page.dart';
import 'package:roundtablezoo/presentation/table/table_placeholder_page.dart';

/// `StatefulShellRoute.indexedStack` with three branches — switching tabs
/// preserves each branch's navigation state and never rebuilds the shell
/// (FR-002, FR-004, SC-002). `/table` is the initial location (FR-002);
/// nothing persists the last open tab across process death (FR-004a).
///
/// `/storage-error` joins once `StorageRecoveryPage` exists (Phase 5).
GoRouter buildAppRouter() => GoRouter(
  initialLocation: AppRoutes.tablePath,
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
              builder: (context, state) => const SettingsPlaceholderPage(),
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
  ],
);
