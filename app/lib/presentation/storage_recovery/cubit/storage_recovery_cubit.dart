import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:roundtablezoo/core/bootstrap/app_bootstrap.dart';
import 'package:roundtablezoo/core/bootstrap/storage_mode.dart';
import 'package:roundtablezoo/data/datasources/drift/app_database.dart';
import 'package:roundtablezoo/presentation/storage_recovery/cubit/storage_recovery_state.dart';

/// Drives the `/storage-error` recovery flow (FR-021b…FR-021e). Never
/// touches DI or navigation directly — `RootBlocListener` reacts to
/// `recovered`/`readOnlyAccepted` to swap repositories and leave this
/// screen.
class StorageRecoveryCubit extends Cubit<StorageRecoveryState> {
  StorageRecoveryCubit({
    required AppDatabase Function() createDatabase,
    required StorageRecoveryState initialState,
  }) : _createDatabase = createDatabase,
       super(initialState);

  final AppDatabase Function() _createDatabase;

  Future<void> retry() async {
    emit(const StorageRecoveryState.working());
    final database = _createDatabase();
    final result = await AppBootstrap.start(database);
    if (isClosed) return;

    final session = result.valueOrGet(
      () => throw StateError('AppBootstrap.start never returns Result.failure'),
    );
    if (session.mode == StorageMode.persistent) {
      emit(StorageRecoveryState.recovered(database: database));
    } else {
      unawaited(database.close());
      emit(StorageRecoveryState.idle(cause: session.cause!));
    }
  }

  /// Deletes all local data and starts fresh, as though this were the
  /// first launch. Callers must have already confirmed this with the user
  /// (FR-021c, FR-021c2) — this method performs no confirmation itself.
  Future<void> resetData() async {
    emit(const StorageRecoveryState.working());
    final resetResult = await AppBootstrap.resetData();
    if (isClosed) return;

    if (resetResult.isFailure) {
      emit(StorageRecoveryState.error(failure: resetResult.errorOrNull!));
      return;
    }

    final database = _createDatabase();
    final result = await AppBootstrap.start(database);
    if (isClosed) return;

    final session = result.valueOrGet(
      () => throw StateError('AppBootstrap.start never returns Result.failure'),
    );
    if (session.mode == StorageMode.persistent) {
      emit(StorageRecoveryState.recovered(database: database));
    } else {
      unawaited(database.close());
      emit(StorageRecoveryState.error(failure: session.cause!));
    }
  }

  /// Opens the shell with read-only repositories; nothing here is
  /// persisted, and the next launch retries opening storage normally
  /// (FR-021d, FR-021d1).
  void continueWithoutSaving() {
    emit(const StorageRecoveryState.readOnlyAccepted());
  }
}
