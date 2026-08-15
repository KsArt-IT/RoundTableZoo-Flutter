import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:roundtablezoo/core/errors/app_failure.dart';
import 'package:roundtablezoo/data/datasources/drift/app_database.dart';

part 'storage_recovery_state.freezed.dart';

@freezed
sealed class StorageRecoveryState with _$StorageRecoveryState {
  /// Waiting for a user action; [cause] explains why storage isn't
  /// available yet.
  const factory StorageRecoveryState.idle({required AppFailure cause}) = StorageRecoveryIdle;

  /// A retry or reset is in flight.
  const factory StorageRecoveryState.working() = StorageRecoveryWorking;

  /// Storage opened successfully — [database] is the connection the app
  /// should register in DI before leaving this screen (FR-021c1).
  const factory StorageRecoveryState.recovered({required AppDatabase database}) =
      StorageRecoveryRecovered;

  /// The user chose to continue without saving. Session-only — never
  /// persisted (FR-021d1).
  const factory StorageRecoveryState.readOnlyAccepted() = StorageRecoveryReadOnlyAccepted;

  /// A reset attempt itself failed. Stays on this screen with both
  /// `retry()` and `continueWithoutSaving()` still available — no
  /// automatic re-attempt (FR-021c1).
  const factory StorageRecoveryState.error({required AppFailure failure}) = StorageRecoveryError;
}
