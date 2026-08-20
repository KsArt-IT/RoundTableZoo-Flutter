import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roundtablezoo/gen/app_localizations.dart';
import 'package:roundtablezoo/presentation/diary/diary_page.dart';
import 'package:roundtablezoo/presentation/settings/settings_page.dart';
import 'package:roundtablezoo/presentation/table/table_page.dart';

import '../support/test_app_root.dart';

// The test harness's platform locale doesn't drive `WidgetsApp`'s locale
// resolution the way a real device's does, so these tests read whatever
// locale actually rendered instead of forcing one.
Future<AppLocalizations> _renderedLocalizations(WidgetTester tester) => AppLocalizations.delegate
    .load(Localizations.localeOf(tester.element(find.byType(NavigationBar))));

// `NavigationDestination` always shows its label alongside the placeholder
// page's own centered text, so a bare `find.text(...)` matches both —
// scope the check to the page body to avoid ambiguity.
Finder _bodyText(Type page, String text) =>
    find.descendant(of: find.byType(page), matching: find.text(text));

void main() {
  testWidgets('starts on the Table section', (tester) async {
    await tester.pumpWidget(buildTestAppRoot());
    await tester.pumpAndSettle();

    // `TablePage` has no title of its own — the round table fills the
    // screen instead (it's the only content the shell shows here).
    expect(find.byType(TablePage), findsOneWidget);
    expect(find.byType(DiaryPage), findsNothing);
    expect(find.byType(SettingsPage), findsNothing);

    await disposeTestAppRoot(tester);
  });

  testWidgets('switches through all three tabs', (tester) async {
    await tester.pumpWidget(buildTestAppRoot());
    await tester.pumpAndSettle();

    final l10n = await _renderedLocalizations(tester);

    await tester.tap(find.widgetWithText(NavigationDestination, l10n.sectionDiary));
    await tester.pumpAndSettle();
    expect(find.byType(DiaryPage), findsOneWidget);

    await tester.tap(find.widgetWithText(NavigationDestination, l10n.sectionSettings));
    await tester.pumpAndSettle();
    expect(_bodyText(SettingsPage, l10n.sectionSettings), findsOneWidget);

    await tester.tap(find.widgetWithText(NavigationDestination, l10n.sectionTable));
    await tester.pumpAndSettle();
    expect(find.byType(TablePage), findsOneWidget);

    await disposeTestAppRoot(tester);
  });

  testWidgets('branch state survives a tab switch — IndexedStack keeps branches mounted', (
    tester,
  ) async {
    await tester.pumpWidget(buildTestAppRoot());
    await tester.pumpAndSettle();

    final l10n = await _renderedLocalizations(tester);

    await tester.tap(find.widgetWithText(NavigationDestination, l10n.sectionDiary));
    await tester.pumpAndSettle();

    // The Table branch is offstage, not torn down: IndexedStack (not a
    // route push/pop) backs the shell, so its widget stays in the tree.
    expect(find.byType(TablePage, skipOffstage: false), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);

    await disposeTestAppRoot(tester);
  });
}
