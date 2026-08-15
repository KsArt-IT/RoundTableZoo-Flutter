import 'dart:async';

import 'package:roundtablezoo/core/errors/result.dart';
import 'package:roundtablezoo/core/utils/app_logger.dart';

mixin SafeCallMixin {
  /// Executes asynchronous code and converts Exceptions into Result.
  Future<Result<T>> safeCall<T>(
    Future<T> Function() invoke,
  ) async {
    try {
      return .success(await invoke());
    } on Object catch (error, stackTrace) {
      if (error is Error) {
        rethrow;
      }

      logger.e(
        error.toString(),
        error: error,
        stackTrace: stackTrace,
      );

      return .failure(.fromError(error));
    }
  }

  /// Executes synchronous code and converts Exceptions into Result.
  Result<T> safeCallSync<T>(
    T Function() invoke,
  ) {
    try {
      return Result.success(invoke());
    } on Object catch (error, stackTrace) {
      if (error is Error) {
        rethrow;
      }

      logger.e(
        error.toString(),
        error: error,
        stackTrace: stackTrace,
      );

      return .failure(.fromError(error));
    }
  }
}
