import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roundtablezoo/core/constants/app_constants.dart';
import 'package:roundtablezoo/presentation/table/widgets/round_table_layout.dart';
import 'package:roundtablezoo/presentation/table/widgets/table_surface_painter.dart';

List<RoundTableSeat> _seats(int count) => [
  for (var i = 0; i < count; i++)
    RoundTableSeat(
      characterId: 'char-$i',
      avatar: Container(key: ValueKey('avatar-$i')),
    ),
];

Future<void> _pumpTable(WidgetTester tester, int seatCount) => tester.pumpWidget(
  MaterialApp(
    home: Scaffold(
      body: SizedBox(
        width: 400,
        height: 400,
        child: RoundTableLayout(seats: _seats(seatCount)),
      ),
    ),
  ),
);

void main() {
  testWidgets('renders a CustomPaint with TableSurfacePainter for a single character', (
    tester,
  ) async {
    await _pumpTable(tester, 1);
    await tester.pumpAndSettle();

    expect(
      find.byWidgetPredicate(
        (widget) => widget is CustomPaint && widget.painter is TableSurfacePainter,
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'renders a CustomPaint with TableSurfacePainter at AppConstants.maxCharactersAtTable',
    (tester) async {
      await _pumpTable(tester, AppConstants.maxCharactersAtTable);
      await tester.pumpAndSettle();

      expect(
        find.byWidgetPredicate(
          (widget) => widget is CustomPaint && widget.painter is TableSurfacePainter,
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('table surface is wrapped in ExcludeSemantics and adds no announced node', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();

    await _pumpTable(tester, 3);
    await tester.pumpAndSettle();

    final excludeSemantics = find.ancestor(
      of: find.byWidgetPredicate(
        (widget) => widget is CustomPaint && widget.painter is TableSurfacePainter,
      ),
      matching: find.byType(ExcludeSemantics),
    );
    expect(excludeSemantics, findsOneWidget);

    handle.dispose();
  });
}
