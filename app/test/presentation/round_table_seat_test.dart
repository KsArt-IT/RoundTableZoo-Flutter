import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:roundtablezoo/presentation/table/widgets/round_table_layout.dart';

void main() {
  group('seatAngle', () {
    test('starts at the top and runs clockwise', () {
      expect(RoundTableLayout.seatAngle(0, 4), -math.pi / 2);
      expect(RoundTableLayout.seatAngle(1, 4), closeTo(0, 1e-12));
      expect(RoundTableLayout.seatAngle(2, 4), closeTo(math.pi / 2, 1e-12));
      expect(RoundTableLayout.seatAngle(3, 4), closeTo(math.pi, 1e-12));
    });
  });

  group('seatFacesRight', () {
    test('only the seats on the left half are mirrored', () {
      // Four seats: top, right, bottom, left. The animals are drawn facing
      // left, so only the last one has to be flipped to face the middle.
      expect(RoundTableLayout.seatFacesRight(0, 4), isFalse);
      expect(RoundTableLayout.seatFacesRight(1, 4), isFalse);
      expect(RoundTableLayout.seatFacesRight(2, 4), isFalse);
      expect(RoundTableLayout.seatFacesRight(3, 4), isTrue);
    });

    test('a full table mirrors exactly its left-hand side', () {
      final facing = [
        for (var i = 0; i < 6; i++) RoundTableLayout.seatFacesRight(i, 6),
      ];

      expect(facing, [false, false, false, false, true, true]);
    });

    test('a seat dead center at the top or bottom keeps the drawn facing', () {
      // Neither side of the table: flipping there would only make the
      // character switch direction for no reason.
      expect(RoundTableLayout.seatFacesRight(0, 2), isFalse);
      expect(RoundTableLayout.seatFacesRight(1, 2), isFalse);
    });

    test('a lone character is not mirrored', () {
      expect(RoundTableLayout.seatFacesRight(0, 1), isFalse);
    });
  });
}
