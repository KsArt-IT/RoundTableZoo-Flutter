import 'package:flutter_test/flutter_test.dart';
import 'package:roundtablezoo/core/errors/app_failure.dart';
import 'package:roundtablezoo/core/errors/failure_toast_gate.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../support/fake_app_clock.dart';

void main() {
  late FakeAppClock clock;
  late FailureToastGate gate;

  setUpAll(() {
    tzdata.initializeTimeZones();
  });

  setUp(() {
    clock = FakeAppClock(now: DateTime.utc(2026), location: tz.getLocation('Europe/Kyiv'));
    gate = FailureToastGate(clock);
  });

  tearDown(() => clock.dispose());

  test('ten identical failures within a second collapse into a single show', () {
    const failure = DatabaseFailure(null, code: DatabaseFailure.savingError);

    final shown = <bool>[];
    for (var i = 0; i < 10; i++) {
      clock.now = clock.nowUtc().add(const Duration(milliseconds: 100));
      shown.add(gate.shouldShow(failure));
    }

    expect(shown.where((s) => s).length, 1);
    expect(shown.first, isTrue);
  });

  test('a different failure kind shows immediately, even inside the window', () {
    const first = DatabaseFailure(null, code: DatabaseFailure.savingError);
    const second = ValidationFailure(null, code: ValidationFailure.moodScoreOutOfRange);

    expect(gate.shouldShow(first), isTrue);
    clock.now = clock.nowUtc().add(const Duration(milliseconds: 500));
    expect(gate.shouldShow(second), isTrue);
  });

  test('the same failure shows again once the 3s window has elapsed', () {
    const failure = DatabaseFailure(null, code: DatabaseFailure.savingError);

    expect(gate.shouldShow(failure), isTrue);
    clock.now = clock.nowUtc().add(const Duration(seconds: 2, milliseconds: 999));
    expect(gate.shouldShow(failure), isFalse);

    clock.now = clock.nowUtc().add(const Duration(milliseconds: 2));
    expect(gate.shouldShow(failure), isTrue);
  });

  test('same failure type but a different code is treated as a different key', () {
    const notFound = DatabaseFailure(null, code: DatabaseFailure.entityNotFound);
    const savingError = DatabaseFailure(null, code: DatabaseFailure.savingError);

    expect(gate.shouldShow(notFound), isTrue);
    expect(gate.shouldShow(savingError), isTrue);
  });
}
