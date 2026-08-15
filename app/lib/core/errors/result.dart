import 'package:flutter/foundation.dart';
import 'package:roundtablezoo/core/errors/app_failure.dart';

/// A class that represents the result of an operation, which can be either
/// a success or a failure.
@immutable
sealed class Result<T> {
  const Result();

  /// Creates a successful [Result], completed with the specified [value].
  const factory Result.success(T value) = Success<T>._;

  /// Creates an error [Result], completed with the specified [error].
  const factory Result.failure(AppFailure error) = Failure<T>._;

  bool get isSuccess => this is Success<T>;
  bool get isFailure => this is Failure<T>;

  /// Converts the result into another value.
  R fold<R>({
    required R Function(T value) success,
    required R Function(AppFailure error) failure,
  }) => switch (this) {
    Success(:final value) => success(value),
    Failure(:final error) => failure(error),
  };

  /// Alias for [fold].
  R match<R>({
    required R Function(T value) success,
    required R Function(AppFailure error) failure,
  }) => fold(success: success, failure: failure);

  /// Maps only the success value.
  Result<R> map<R>(
    R Function(T value) mapper,
  ) => switch (this) {
    Success(:final value) => .success(mapper(value)),
    Failure(:final error) => .failure(error),
  };

  /// Maps only the failure.
  Result<T> mapError(
    AppFailure Function(AppFailure error) mapper,
  ) => switch (this) {
    Success() => this,
    Failure(:final error) => .failure(mapper(error)),
  };

  /// Chains another Result-producing operation.
  Result<R> flatMap<R>(Result<R> Function(T value) mapper) => switch (this) {
    Success(:final value) => mapper(value),
    Failure(:final error) => .failure(error),
  };

  /// Executes a callback when successful.
  Result<T> onSuccess(
    ValueChanged<T> callback,
  ) {
    if (this case Success(:final value)) {
      callback(value);
    }

    // ignore: avoid_returning_this
    return this;
  }

  /// Executes a callback when failed.
  Result<T> onFailure(
    ValueChanged<AppFailure> callback,
  ) {
    if (this case Failure(:final error)) {
      callback(error);
    }

    // ignore: avoid_returning_this
    return this;
  }

  /// Returns the value if the result is successful, otherwise returns null.
  T? get valueOrNull => switch (this) {
    Success(:final value) => value,
    Failure() => null,
  };

  T valueOrGet(T Function() fallback) => switch (this) {
    Success(:final value) => value,
    Failure() => fallback(),
  };

  /// Returns the error if the result is unsuccessful, otherwise returns null.
  AppFailure? get errorOrNull => switch (this) {
    Success() => null,
    Failure(:final error) => error,
  };
}

/// Subclass of Result for values
final class Success<T> extends Result<T> {
  const Success._(this.value);

  /// Returned value in result
  final T value;

  @override
  String toString() => '$value';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Success<T> && runtimeType == other.runtimeType && other.value == value;

  @override
  int get hashCode => value.hashCode;
}

/// Subclass of Result for errors
final class Failure<T> extends Result<T> {
  const Failure._(this.error);

  /// Returned error in result
  final AppFailure error;

  @override
  String toString() => 'Failure: $error';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Failure<T> && runtimeType == other.runtimeType && other.error == error;

  @override
  int get hashCode => error.hashCode;
}

extension FutureResultX<T> on Future<Result<T>> {
  Future<Result<R>> map<R>(
    R Function(T value) mapper,
  ) async => (await this).map(mapper);

  Future<Result<R>> flatMap<R>(
    Future<Result<R>> Function(T value) mapper,
  ) async => switch (await this) {
    Success(:final value) => await mapper(value),
    Failure(:final error) => .failure(error),
  };

  Future<Result<T>> onSuccess(
    ValueChanged<T> callback,
  ) async {
    final result = await this;
    result.onSuccess(callback);
    return result;
  }

  Future<Result<T>> onFailure(
    ValueChanged<AppFailure> callback,
  ) async {
    final result = await this;
    result.onFailure(callback);
    return result;
  }
}
