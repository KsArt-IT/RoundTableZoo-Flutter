import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roundtablezoo/core/di/injection.dart';
import 'package:roundtablezoo/domain/repositories/settings_repository.dart';
import 'package:roundtablezoo/domain/value_objects/locale_preference.dart';
import 'package:roundtablezoo/domain/value_objects/theme_preference.dart';
import 'package:roundtablezoo/presentation/diary/diary_placeholder_page.dart';
import 'package:roundtablezoo/presentation/settings/settings_page.dart';
import 'package:roundtablezoo/presentation/table/table_page.dart';

import '../support/test_app_root.dart';

// `intl_uk.arb`'s `sectionTable`/`sectionDiary`/`sectionSettings` values —
// distinct enough from the ru/en template strings to prove the locale
// actually switched, without pulling in AppLocalizations.delegate.
const _ukTable = 'Стіл';
const _ukDiary = 'Щоденник';
const _ukSettings = 'Налаштування';

Finder _bodyText(Type page, String text) =>
    find.descendant(of: find.byType(page), matching: find.text(text));

void main() {
  testWidgets('changing theme mode repaints without a restart', (tester) async {
    await tester.pumpWidget(buildTestAppRoot());
    await tester.pumpAndSettle();

    expect(Theme.of(tester.element(find.byType(TablePage))).brightness, Brightness.light);

    await getIt<SettingsRepository>().updateThemeMode(ThemePreference.dark);
    await tester.pumpAndSettle();

    expect(Theme.of(tester.element(find.byType(TablePage))).brightness, Brightness.dark);

    await disposeTestAppRoot(tester);
  });

  testWidgets('changing locale re-renders all three sections without a restart', (tester) async {
    await tester.pumpWidget(buildTestAppRoot());
    await tester.pumpAndSettle();

    await getIt<SettingsRepository>().updateLocale(LocalePreference.uk);
    await tester.pumpAndSettle();

    expect(_bodyText(TablePage, _ukTable), findsOneWidget);

    await tester.tap(find.widgetWithText(NavigationDestination, _ukDiary));
    await tester.pumpAndSettle();
    expect(_bodyText(DiaryPlaceholderPage, _ukDiary), findsOneWidget);

    await tester.tap(find.widgetWithText(NavigationDestination, _ukSettings));
    await tester.pumpAndSettle();
    expect(_bodyText(SettingsPage, _ukSettings), findsOneWidget);

    await disposeTestAppRoot(tester);
  });

  testWidgets('an unsupported device language falls back to Russian', (tester) async {
    tester.platformDispatcher.localesTestValue = [const Locale('de')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);

    await tester.pumpWidget(buildTestAppRoot());
    await tester.pumpAndSettle();

    expect(_bodyText(TablePage, 'Стол'), findsOneWidget);

    await disposeTestAppRoot(tester);
  });
}
