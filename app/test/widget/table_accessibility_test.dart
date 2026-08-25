import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:roundtablezoo/core/di/injection.dart';
import 'package:roundtablezoo/core/network/stub_ai_proxy_client.dart';
import 'package:roundtablezoo/core/speech/speech_synthesizer.dart';
import 'package:roundtablezoo/gen/app_localizations.dart';

import '../support/mocks.dart';
import '../support/test_app_root.dart';

Future<AppLocalizations> _renderedLocalizations(WidgetTester tester) => AppLocalizations.delegate
    .load(Localizations.localeOf(tester.element(find.byType(Scaffold).first)));

Finder _idleSeats(AppLocalizations l10n) => find.byWidgetPredicate(
  (widget) =>
      widget is Semantics &&
      (widget.properties.label?.endsWith(l10n.tableCharacterStateIdle) ?? false),
);

void main() {
  tearDown(StubAiProxyClient.clearFailure);

  testWidgets(
    'mood scale, day text field and character seats meet Android tap-target and label '
    'guidelines (SC-008)',
    (tester) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(buildTestAppRoot());
      await tester.pumpAndSettle();

      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));

      handle.dispose();
      await disposeTestAppRoot(tester);
    },
  );

  testWidgets('every character seat carries a state label (SC-008, FR-011, FR-012)', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();

    await tester.pumpWidget(buildTestAppRoot());
    await tester.pumpAndSettle();

    final l10n = await _renderedLocalizations(tester);
    // No mood has been picked yet, so all four MVP characters are idle
    // (`character_avatar.dart` — the state suffix is part of the label,
    // not a separate announcement, FR-012: not color alone).
    final idleSeats = find.byWidgetPredicate(
      (widget) =>
          widget is Semantics &&
          (widget.properties.label?.endsWith(l10n.tableCharacterStateIdle) ?? false),
    );
    expect(idleSeats, findsNWidgets(4));

    handle.dispose();
    await disposeTestAppRoot(tester);
  });

  testWidgets('with a screen reader active, a reply never gets voiced (008, FR-014)', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(
      accessibleNavigation: true,
    );
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

    final handle = tester.ensureSemantics();
    await tester.pumpWidget(buildTestAppRoot());
    await tester.pumpAndSettle();

    final l10n = await _renderedLocalizations(tester);
    await tester.tap(find.bySemanticsLabel(l10n.moodScaleGood));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'привет мир');
    await tester.pump();

    await tester.tap(_idleSeats(l10n).first);
    await tester.pumpAndSettle();

    verifyNever(() => (getIt<SpeechSynthesizer>() as MockSpeechSynthesizer).speak(any()));

    handle.dispose();
    await disposeTestAppRoot(tester);
  });
}
