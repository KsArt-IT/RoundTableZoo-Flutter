import 'dart:async';

import 'package:roundtablezoo/core/app_clock/app_clock.dart';
import 'package:timezone/timezone.dart' as tz;

/// Deterministic [AppClock] for tests: no real timers, no real wall-clock
/// reads. Time only moves when the test tells it to.
class FakeAppClock implements AppClock {
  FakeAppClock({required DateTime now, required tz.Location location})
    : assert(now.isUtc, 'FakeAppClock requires a UTC instant'),
      _now = now,
      _location = location;

  DateTime _now;
  tz.Location _location;
  final StreamController<DateTime> _controller = StreamController<DateTime>.broadcast();

  @override
  DateTime nowUtc() => _now;

  @override
  tz.Location get location => _location;

  @override
  Stream<DateTime> get minuteTicks => _controller.stream;

  @override
  void updateLocation(tz.Location location) {
    _location = location;
  }

  /// Sets the current instant without emitting a tick.
  set now(DateTime value) {
    assert(value.isUtc, 'FakeAppClock requires a UTC instant');
    _now = value;
  }

  /// Sets the current instant and emits it on [minuteTicks], as
  /// `SystemAppClock` would on a real minute boundary.
  void emitTick(DateTime instantUtc) {
    assert(instantUtc.isUtc, 'FakeAppClock requires a UTC instant');
    _now = instantUtc;
    _controller.add(instantUtc);
  }

  Future<void> dispose() => _controller.close();
}
