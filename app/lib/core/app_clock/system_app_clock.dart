import 'dart:async';

import 'package:roundtablezoo/core/app_clock/app_clock.dart';
import 'package:timezone/timezone.dart' as tz;

/// Production [AppClock]: real wall-clock time, real device timezone, a
/// `Timer` aligned to the start of each minute.
class SystemAppClock implements AppClock {
  SystemAppClock({required tz.Location initialLocation}) : _location = initialLocation {
    _armNextTick();
  }

  tz.Location _location;
  Timer? _timer;
  final StreamController<DateTime> _controller = StreamController<DateTime>.broadcast();

  @override
  DateTime nowUtc() => DateTime.now().toUtc();

  @override
  tz.Location get location => _location;

  @override
  Stream<DateTime> get minuteTicks => _controller.stream;

  @override
  void updateLocation(tz.Location location) {
    _location = location;
  }

  void _armNextTick() {
    final now = nowUtc();
    final delay = Duration(
      seconds: 60 - now.second,
      milliseconds: -now.millisecond,
      microseconds: -now.microsecond,
    );
    _timer = Timer(delay, _onFirstTick);
  }

  void _onFirstTick() {
    _emitTick();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) => _emitTick());
  }

  void _emitTick() {
    if (_controller.isClosed) return;
    _controller.add(nowUtc());
  }

  /// Cancels the internal timer and closes the tick stream. Must be called
  /// exactly once, when the clock is no longer needed (app teardown).
  void dispose() {
    _timer?.cancel();
    _timer = null;
    unawaited(_controller.close());
  }
}
