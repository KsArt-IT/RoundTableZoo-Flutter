import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roundtablezoo/gen/app_localizations.dart';
import 'package:toastification/toastification.dart';

import '../support/test_app_root.dart';

void main() {
  testWidgets('remindersMuted shows the toast exactly once, even across a tab switch', (
    tester,
  ) async {
    await tester.pumpWidget(buildTestAppRoot(remindersMuted: true));
    await tester.pumpAndSettle();

    expect(find.byType(ToastificationConfigProvider), findsWidgets);
    final l10n = await AppLocalizations.delegate.load(
      Localizations.localeOf(tester.element(find.byType(NavigationBar))),
    );
    expect(find.text(l10n.reminderPermissionRevokedToast), findsOneWidget);

    await tester.pump();
    expect(find.text(l10n.reminderPermissionRevokedToast), findsOneWidget);

    await tester.tap(find.widgetWithText(NavigationDestination, l10n.sectionDiary));
    await tester.pumpAndSettle();

    // Still just the one toast — switching tabs doesn't show it again.
    expect(find.text(l10n.reminderPermissionRevokedToast), findsOneWidget);

    await tester.pump(const Duration(seconds: 5));
    await disposeTestAppRoot(tester);
  });

  testWidgets('remindersMuted false never shows the toast', (tester) async {
    await tester.pumpWidget(buildTestAppRoot());
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(
      Localizations.localeOf(tester.element(find.byType(NavigationBar))),
    );
    expect(find.text(l10n.reminderPermissionRevokedToast), findsNothing);

    await disposeTestAppRoot(tester);
  });
}
