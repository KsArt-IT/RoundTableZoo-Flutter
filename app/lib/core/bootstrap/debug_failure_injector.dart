import 'package:flutter/foundation.dart';
import 'package:roundtablezoo/core/errors/app_failure.dart';

/// Debug-only controllable failure source for manual QA (SC-004, SC-016).
/// Every method is a no-op in release builds — nothing here can affect a
/// shipped build, and there is no way to enable it there.
///
/// `SafeCallMixin.safeCall`/`safeCallSync` consult [maybeThrow] before
/// running the real operation, so any repository call can be made to fail
/// with a chosen [AppFailure] without touching real storage:
///
/// ```dart
/// DebugFailureInjector.enqueue(
///   const DatabaseFailure(null, code: DatabaseFailure.storageUnavailable),
/// );
/// // the next repository call now fails with that DatabaseFailure instead
/// // of running; DebugFailureInjector.clear()'s automatic once it fires.
/// ```
abstract final class DebugFailureInjector {
  static AppFailure? _queuedFailure;
  static bool _persistent = false;

  /// Forces the next storage operation to fail with [failure] instead of
  /// running. Pass `persistent: true` to keep failing every subsequent
  /// call until [clear] — used for the SC-004 half-hour walkthrough, where
  /// failures need to keep happening across many screens.
  static void enqueue(AppFailure failure, {bool persistent = false}) {
    if (kReleaseMode) return;
    _queuedFailure = failure;
    _persistent = persistent;
  }

  /// Stops injecting failures, whether one-shot or persistent.
  static void clear() {
    _queuedFailure = null;
    _persistent = false;
  }

  /// Called by `SafeCallMixin` before every storage operation. Throws the
  /// queued failure — once, unless [enqueue] was called with
  /// `persistent: true` — instead of letting the real operation run.
  static void maybeThrow() {
    if (kReleaseMode) return;
    final failure = _queuedFailure;
    if (failure == null) return;
    if (!_persistent) _queuedFailure = null;
    throw failure;
  }
}
