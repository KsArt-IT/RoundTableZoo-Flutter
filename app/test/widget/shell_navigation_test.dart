import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roundtablezoo/app/app_root.dart';
import 'package:roundtablezoo/gen/app_localizations.dart';
import 'package:roundtablezoo/presentation/diary/diary_placeholder_page.dart';
import 'package:roundtablezoo/presentation/settings/settings_placeholder_page.dart';
import 'package:roundtablezoo/presentation/table/table_placeholder_page.dart';

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
    await tester.pumpWidget(const AppRoot());
    await tester.pumpAndSettle();

    final l10n = await _renderedLocalizations(tester);
    expect(_bodyText(TablePlaceholderPage, l10n.sectionTable), findsOneWidget);
    expect(find.byType(DiaryPlaceholderPage), findsNothing);
    expect(find.byType(SettingsPlaceholderPage), findsNothing);
  });

  testWidgets('switches through all three tabs', (tester) async {
    await tester.pumpWidget(const AppRoot());
    await tester.pumpAndSettle();

    final l10n = await _renderedLocalizations(tester);

    await tester.tap(find.widgetWithText(NavigationDestination, l10n.sectionDiary));
    await tester.pumpAndSettle();
    expect(_bodyText(DiaryPlaceholderPage, l10n.sectionDiary), findsOneWidget);

    await tester.tap(find.widgetWithText(NavigationDestination, l10n.sectionSettings));
    await tester.pumpAndSettle();
    expect(_bodyText(SettingsPlaceholderPage, l10n.sectionSettings), findsOneWidget);

    await tester.tap(find.widgetWithText(NavigationDestination, l10n.sectionTable));
    await tester.pumpAndSettle();
    expect(_bodyText(TablePlaceholderPage, l10n.sectionTable), findsOneWidget);
  });

  testWidgets('branch state survives a tab switch — IndexedStack keeps branches mounted', (
    tester,
  ) async {
    await tester.pumpWidget(const AppRoot());
    await tester.pumpAndSettle();

    final l10n = await _renderedLocalizations(tester);

    await tester.tap(find.widgetWithText(NavigationDestination, l10n.sectionDiary));
    await tester.pumpAndSettle();

    // The Table branch is offstage, not torn down: IndexedStack (not a
    // route push/pop) backs the shell, so its widget stays in the tree.
    expect(find.byType(TablePlaceholderPage, skipOffstage: false), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
  });
}
