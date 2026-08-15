import 'package:flutter_test/flutter_test.dart';
import '../support/test_app_root.dart';

void main() {
  testWidgets('navigation destinations meet Android tap-target and label guidelines', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();

    await tester.pumpWidget(buildTestAppRoot());
    await tester.pumpAndSettle();

    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));

    handle.dispose();
  });
}
