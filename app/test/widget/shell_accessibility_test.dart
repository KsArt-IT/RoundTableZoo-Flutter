import 'package:flutter_test/flutter_test.dart';
import 'package:roundtablezoo/app/app_root.dart';

void main() {
  testWidgets('navigation destinations meet Android tap-target and label guidelines', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();

    await tester.pumpWidget(const AppRoot());
    await tester.pumpAndSettle();

    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));

    handle.dispose();
  });
}
