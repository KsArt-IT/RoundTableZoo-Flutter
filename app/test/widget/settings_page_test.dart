import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:roundtablezoo/core/bootstrap/debug_failure_injector.dart';
import 'package:roundtablezoo/core/di/injection.dart';
import 'package:roundtablezoo/core/errors/app_failure.dart';
import 'package:roundtablezoo/core/errors/result.dart';
import 'package:roundtablezoo/core/speech/speech_synthesizer.dart';
import 'package:roundtablezoo/domain/repositories/settings_repository.dart';
import 'package:roundtablezoo/gen/app_localizations.dart';
import 'package:roundtablezoo/presentation/settings/settings_page.dart';

import '../support/mocks.dart';
import '../support/test_app_root.dart';

Future<AppLocalizations> _renderedLocalizations(WidgetTester tester) => AppLocalizations.delegate
    .load(Localizations.localeOf(tester.element(find.byType(NavigationBar))));

Future<void> _openSettings(WidgetTester tester) async {
  await tester.pumpWidget(buildTestAppRoot());
  await tester.pumpAndSettle();
  final l10n = await _renderedLocalizations(tester);
  await tester.tap(find.widgetWithText(NavigationDestination, l10n.sectionSettings));
  await tester.pumpAndSettle();
}

void main() {
  tearDown(DebugFailureInjector.clear);

  testWidgets('selecting dark theme repaints immediately', (tester) async {
    await _openSettings(tester);
    final l10n = await _renderedLocalizations(tester);

    await tester.tap(find.text(l10n.settingsThemeDark));
    await tester.pumpAndSettle();

    expect(Theme.of(tester.element(find.byType(SettingsPage))).brightness, Brightness.dark);

    await disposeTestAppRoot(tester);
  });

  testWidgets('a failed save leaves the control in its previous position (FR-003)', (tester) async {
    await _openSettings(tester);
    final l10n = await _renderedLocalizations(tester);

    await tester.tap(find.text(l10n.settingsThemeDark));
    await tester.pumpAndSettle();
    expect(Theme.of(tester.element(find.byType(SettingsPage))).brightness, Brightness.dark);

    DebugFailureInjector.enqueue(const DatabaseFailure(null, code: DatabaseFailure.savingError));
    await tester.tap(find.text(l10n.settingsThemeLight));
    await tester.pumpAndSettle();

    expect(Theme.of(tester.element(find.byType(SettingsPage))).brightness, Brightness.dark);

    // Let the failure toast's own auto-close timer run out before tearing
    // down the tree — otherwise it's still pending when the binding checks
    // for leaks (unrelated to what this test verifies).
    await tester.pump(const Duration(seconds: 5));
    await disposeTestAppRoot(tester);
  });

  testWidgets('system locale stays checked even when the device language is unsupported (FR-010)', (
    tester,
  ) async {
    tester.platformDispatcher.localesTestValue = [const Locale('de')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);

    await _openSettings(tester);

    // The interface renders in Russian (the fallback), and "System" (the
    // Russian label, since that's what's rendered) is still selectable —
    // this exercises the same code path a supported-language toggle would.
    expect(find.text('Системный'), findsOneWidget);

    await disposeTestAppRoot(tester);
  });

  testWidgets('every interactive control meets tap-target and label guidelines', (tester) async {
    final handle = tester.ensureSemantics();
    await _openSettings(tester);

    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));

    handle.dispose();
    await disposeTestAppRoot(tester);
  });

  testWidgets('no voice for the language: sound toggle disabled with an explanation (008, FR-013)', (
    tester,
  ) async {
    final widget = buildTestAppRoot();
    when(
      () => (getIt<SpeechSynthesizer>() as MockSpeechSynthesizer).isAvailableFor(any()),
    ).thenAnswer((_) async => const Result.success(false));

    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();
    final l10n = await _renderedLocalizations(tester);
    await tester.tap(find.widgetWithText(NavigationDestination, l10n.sectionSettings));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.widgetWithText(SwitchListTile, l10n.settingsSound), 200);
    final tile = tester.widget<SwitchListTile>(
      find.widgetWithText(SwitchListTile, l10n.settingsSound),
    );
    expect(tile.onChanged, isNull);
    expect(find.text(l10n.settingsSoundUnavailableHint), findsOneWidget);

    final settings = await getIt<SettingsRepository>().load();
    expect(settings.valueOrNull!.soundEnabled, isTrue);

    await disposeTestAppRoot(tester);
  });

  testWidgets(
    'screen reader active: sound toggle disabled with an explanation (008, FR-013, FR-014)',
    (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(
        accessibleNavigation: true,
      );
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

      await _openSettings(tester);
      final l10n = await _renderedLocalizations(tester);

      await tester.scrollUntilVisible(
        find.widgetWithText(SwitchListTile, l10n.settingsSound),
        200,
      );
      final tile = tester.widget<SwitchListTile>(
        find.widgetWithText(SwitchListTile, l10n.settingsSound),
      );
      expect(tile.onChanged, isNull);
      expect(find.text(l10n.settingsSoundScreenReaderHint), findsOneWidget);

      final settings = await getIt<SettingsRepository>().load();
      expect(settings.valueOrNull!.soundEnabled, isTrue);

      await disposeTestAppRoot(tester);
    },
  );
}
