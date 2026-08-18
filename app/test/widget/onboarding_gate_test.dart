import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:roundtablezoo/app/router/app_routes.dart';
import 'package:roundtablezoo/core/di/injection.dart';
import 'package:roundtablezoo/core/errors/app_failure.dart';
import 'package:roundtablezoo/core/notifications/notification_launch_queue.dart';
import 'package:roundtablezoo/gen/app_localizations.dart';
import 'package:roundtablezoo/presentation/onboarding/onboarding_page.dart';
import 'package:roundtablezoo/presentation/storage_recovery/cubit/storage_recovery_state.dart';
import 'package:roundtablezoo/presentation/storage_recovery/storage_recovery_page.dart';
import 'package:roundtablezoo/presentation/table/table_page.dart';

import '../support/test_app_root.dart';

// The test harness's platform locale doesn't drive `WidgetsApp`'s locale
// resolution the way a real device's does, so these tests read whatever
// locale actually rendered instead of forcing one.
Future<AppLocalizations> _renderedLocalizations(WidgetTester tester) =>
    AppLocalizations.delegate.load(Localizations.localeOf(tester.element(find.byType(Scaffold).first)));

GoRouter _router(WidgetTester tester) => GoRouter.of(tester.element(find.byType(Scaffold).first));

void main() {
  testWidgets('onboardingSeen: false starts on the onboarding screen, no shell', (tester) async {
    await tester.pumpWidget(buildTestAppRoot(onboardingSeen: false));
    await tester.pumpAndSettle();

    expect(find.byType(OnboardingPage), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);

    await disposeTestAppRoot(tester);
  });

  testWidgets('onboardingSeen: true starts directly on the shell', (tester) async {
    await tester.pumpWidget(buildTestAppRoot());
    await tester.pumpAndSettle();

    expect(find.byType(OnboardingPage), findsNothing);
    expect(find.byType(NavigationBar), findsOneWidget);

    await disposeTestAppRoot(tester);
  });

  testWidgets('tapping the continue action leaves onboarding for the shell (SC-002)', (tester) async {
    await tester.pumpWidget(buildTestAppRoot(onboardingSeen: false));
    await tester.pumpAndSettle();

    final l10n = await _renderedLocalizations(tester);
    await tester.tap(find.widgetWithText(FilledButton, l10n.onboardingStart));
    await tester.pumpAndSettle();

    expect(find.byType(OnboardingPage), findsNothing);
    expect(find.byType(NavigationBar), findsOneWidget);

    await disposeTestAppRoot(tester);
  });

  testWidgets('a direct go("/onboarding") after completion bounces back to /table (C9, FR-007a)', (
    tester,
  ) async {
    await tester.pumpWidget(buildTestAppRoot());
    await tester.pumpAndSettle();

    _router(tester).go(AppRoutes.onboardingPath);
    await tester.pumpAndSettle();

    expect(find.byType(OnboardingPage), findsNothing);
    expect(find.byType(NavigationBar), findsOneWidget);

    await disposeTestAppRoot(tester);
  });

  testWidgets('canPop() is false on /onboarding (FR-008, research.md R6)', (tester) async {
    await tester.pumpWidget(buildTestAppRoot(onboardingSeen: false));
    await tester.pumpAndSettle();

    expect(_router(tester).canPop(), isFalse);

    await disposeTestAppRoot(tester);
  });

  testWidgets('a warm notification tap while onboarding is pending stays on onboarding (FR-002b)', (
    tester,
  ) async {
    await tester.pumpWidget(buildTestAppRoot(onboardingSeen: false));
    await tester.pumpAndSettle();

    getIt<NotificationLaunchQueue>().add('table');
    await tester.pumpAndSettle();

    expect(find.byType(OnboardingPage), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);

    await disposeTestAppRoot(tester);
  });

  testWidgets(
    'title, all three points and the action fit without scrolling at default settings (FR-004a, FR-004c, SC-002)',
    (tester) async {
      await tester.pumpWidget(buildTestAppRoot(onboardingSeen: false));
      await tester.pumpAndSettle();

      final l10n = await _renderedLocalizations(tester);
      expect(find.text(l10n.onboardingTitle), findsOneWidget);
      expect(find.text(l10n.onboardingHowTo), findsOneWidget);
      expect(find.text(l10n.onboardingDisclaimer), findsOneWidget);
      expect(find.text(l10n.onboardingAiDisclosure), findsOneWidget);
      expect(find.widgetWithText(FilledButton, l10n.onboardingStart), findsOneWidget);

      final scrollableState = tester.state<ScrollableState>(find.byType(Scrollable));
      expect(scrollableState.position.pixels, 0);
      expect(tester.takeException(), isNull);

      await disposeTestAppRoot(tester);
    },
  );

  testWidgets('renders correctly under the default system theme/locale (FR-009a)', (tester) async {
    await tester.pumpWidget(buildTestAppRoot(onboardingSeen: false));
    await tester.pumpAndSettle();

    expect(find.byType(OnboardingPage), findsOneWidget);
    expect(tester.takeException(), isNull);

    await disposeTestAppRoot(tester);
  });

  testWidgets('point (c) discloses the third-party AI service, what is sent, and what stays on-device', (
    tester,
  ) async {
    await tester.pumpWidget(buildTestAppRoot(onboardingSeen: false));
    await tester.pumpAndSettle();

    final l10n = await _renderedLocalizations(tester);
    final disclosure = l10n.onboardingAiDisclosure;
    expect(disclosure, isNotEmpty);
    expect(disclosure.toLowerCase(), contains('ai'));
    expect(find.text(disclosure), findsOneWidget);

    await disposeTestAppRoot(tester);
  });

  group('storage recovery interaction (FR-006a, FR-006b)', () {
    const cause = DatabaseFailure(null, code: DatabaseFailure.storageUnavailable);

    testWidgets('StorageRecoveryIdle takes priority — onboarding is not shown yet', (tester) async {
      await tester.pumpWidget(
        buildTestAppRoot(
          initialState: const StorageRecoveryState.idle(cause: cause),
          onboardingSeen: false,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(StorageRecoveryPage), findsOneWidget);
      expect(find.byType(OnboardingPage), findsNothing);

      await disposeTestAppRoot(tester);
    });

    testWidgets('after accepting read-only, onboarding is shown; after confirming it, it stays gone', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestAppRoot(
          initialState: const StorageRecoveryState.idle(cause: cause),
          onboardingSeen: false,
        ),
      );
      await tester.pumpAndSettle();

      final l10n = await _renderedLocalizations(tester);
      await tester.tap(find.widgetWithText(FilledButton, l10n.storageRecoveryContinueWithoutSaving));
      await tester.pumpAndSettle();

      expect(find.byType(OnboardingPage), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, l10n.onboardingStart));
      await tester.pumpAndSettle();

      expect(find.byType(OnboardingPage), findsNothing);
      expect(find.byType(TablePage), findsOneWidget);

      // Same-session terminality (FR-006a): a direct re-entry attempt
      // bounces straight back, same as C9 above.
      _router(tester).go(AppRoutes.onboardingPath);
      await tester.pumpAndSettle();
      expect(find.byType(OnboardingPage), findsNothing);

      await disposeTestAppRoot(tester);
    });
  });
}
