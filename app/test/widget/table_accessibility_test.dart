import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roundtablezoo/gen/app_localizations.dart';

import '../support/test_app_root.dart';

Future<AppLocalizations> _renderedLocalizations(WidgetTester tester) => AppLocalizations.delegate
    .load(Localizations.localeOf(tester.element(find.byType(Scaffold).first)));

void main() {
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
}
