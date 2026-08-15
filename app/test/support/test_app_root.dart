import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:roundtablezoo/app/app_root.dart';
import 'package:roundtablezoo/core/di/storage_di_switch.dart';
import 'package:roundtablezoo/data/datasources/drift/app_database.dart';
import 'package:roundtablezoo/presentation/storage_recovery/cubit/storage_recovery_cubit.dart';
import 'package:roundtablezoo/presentation/storage_recovery/cubit/storage_recovery_state.dart';

/// An [AppRoot] whose `StorageRecoveryCubit` already starts `recovered` —
/// widget tests that exercise the shell shouldn't have to know about the
/// storage-recovery flow at all.
///
/// `RootBlocListener` only reacts to state *transitions*, not the initial
/// state, so — mirroring what `main.dart` does before constructing the
/// cubit for a cold-start `recovered` session — this registers the
/// storage-backed DI graph itself. Skip that by passing a non-`recovered`
/// [initialState] if a test needs `DiaryRepository`/`SettingsRepository`
/// left unregistered.
Widget buildTestAppRoot({StorageRecoveryState? initialState}) {
  final database = AppDatabase(NativeDatabase.memory());
  final resolvedInitialState = initialState ?? StorageRecoveryState.recovered(database: database);
  if (resolvedInitialState is StorageRecoveryRecovered) {
    StorageDiSwitch.usePersistentStorage(resolvedInitialState.database);
  }

  return AppRoot(
    storageRecoveryCubit: StorageRecoveryCubit(
      createDatabase: () => AppDatabase(NativeDatabase.memory()),
      initialState: resolvedInitialState,
    ),
  );
}
