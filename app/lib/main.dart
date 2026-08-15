import 'package:flutter/material.dart';
import 'package:roundtablezoo/app/app_root.dart';
import 'package:roundtablezoo/core/bootstrap/app_bootstrap.dart';
import 'package:roundtablezoo/core/bootstrap/storage_mode.dart';
import 'package:roundtablezoo/core/di/injection.dart';
import 'package:roundtablezoo/core/di/storage_di_switch.dart';
import 'package:roundtablezoo/core/time_zone/time_zones.dart';
import 'package:roundtablezoo/data/datasources/drift/app_database.dart';
import 'package:roundtablezoo/presentation/storage_recovery/cubit/storage_recovery_cubit.dart';
import 'package:roundtablezoo/presentation/storage_recovery/cubit/storage_recovery_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await TimeZones.initialize();
  configureDependencies();

  final initialDatabase = AppDatabase();
  final session = (await AppBootstrap.start(initialDatabase)).valueOrGet(
    () => throw StateError('AppBootstrap.start never returns Result.failure'),
  );

  final StorageRecoveryState initialState;
  if (session.mode == StorageMode.persistent) {
    StorageDiSwitch.usePersistentStorage(initialDatabase);
    initialState = StorageRecoveryState.recovered(database: initialDatabase);
  } else {
    // DiaryRepository/SettingsRepository stay unregistered until the user
    // picks a recovery action — the router redirects everything to
    // /storage-error until then, so nothing tries to resolve them.
    await initialDatabase.close();
    initialState = StorageRecoveryState.idle(cause: session.cause!);
  }

  runApp(
    AppRoot(
      storageRecoveryCubit: StorageRecoveryCubit(
        createDatabase: AppDatabase.new,
        initialState: initialState,
      ),
    ),
  );
}
