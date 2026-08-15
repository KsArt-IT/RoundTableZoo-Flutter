import 'package:flutter/foundation.dart';
import 'package:roundtablezoo/core/bootstrap/storage_mode.dart';
import 'package:roundtablezoo/core/errors/app_failure.dart';

/// Outcome of `AppBootstrap.start()`.
@immutable
class AppSession {
  const AppSession({required this.mode, this.cause})
    : assert(
        mode != StorageMode.readOnly,
        'readOnly is only reached via StorageRecoveryCubit.continueWithoutSaving(), never at cold start',
      ),
      assert(
        mode != StorageMode.unavailable || cause != null,
        'unavailable sessions must carry the failure that caused them',
      );

  final StorageMode mode;

  /// Present only when [mode] is [StorageMode.unavailable].
  final AppFailure? cause;
}
