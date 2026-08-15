import 'package:injectable/injectable.dart';
import 'package:roundtablezoo/core/app_clock/app_clock.dart';
import 'package:roundtablezoo/core/constants/app_constants.dart';
import 'package:roundtablezoo/core/errors/app_failure.dart';

/// Collapses repeated identical failures into a single toast (FR-021f,
/// SC-014) — `RootBlocListener` is the only caller.
@lazySingleton
class FailureToastGate {
  FailureToastGate(this._clock);

  final AppClock _clock;

  (Type, String?)? _lastKey;
  DateTime? _lastShownAt;

  /// Whether a toast should be shown for [failure]. `true` for the first
  /// occurrence of a `(runtimeType, code)` key, or whenever that key
  /// differs from the last one shown; `false` for a repeat of the same key
  /// within [AppConstants.duplicateFailureWindow].
  bool shouldShow(AppFailure failure) {
    final key = (failure.runtimeType, failure.code);
    final now = _clock.nowUtc();

    if (key == _lastKey && _lastShownAt != null) {
      final elapsed = now.difference(_lastShownAt!);
      if (elapsed < AppConstants.duplicateFailureWindow) return false;
    }

    _lastKey = key;
    _lastShownAt = now;
    return true;
  }
}
