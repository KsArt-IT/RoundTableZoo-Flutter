import 'dart:async';

import 'package:roundtablezoo/core/app_clock/app_clock.dart';
import 'package:roundtablezoo/core/bootstrap/storage_mode.dart';
import 'package:roundtablezoo/core/di/injection.dart';
import 'package:roundtablezoo/data/datasources/diary_local_datasource.dart';
import 'package:roundtablezoo/data/datasources/drift/app_database.dart';
import 'package:roundtablezoo/data/datasources/settings_local_datasource.dart';
import 'package:roundtablezoo/data/repositories/diary_repository_impl.dart';
import 'package:roundtablezoo/data/repositories/read_only_repositories.dart';
import 'package:roundtablezoo/data/repositories/settings_repository_impl.dart';
import 'package:roundtablezoo/domain/repositories/diary_repository.dart';
import 'package:roundtablezoo/domain/repositories/settings_repository.dart';
import 'package:roundtablezoo/domain/services/day_resolver.dart';

/// Re-registers the storage-backed DI graph at runtime, in response to
/// `StorageRecoveryCubit` transitions (`recovered`/`readOnlyAccepted`).
///
/// injectable's generated registrations are static (decided at build time),
/// so they can't react to "the database we open turned out to be a
/// different instance than the one from cold start" — this duplicates that
/// wiring deliberately, as the one place allowed to call
/// `getIt.unregister`/`registerLazySingleton` for these types.
///
/// It also publishes the resulting [StorageMode]: this is the only place that
/// knows it at runtime, and screens need it *before* acting (the Table screen
/// must not fire an AI request whose result has nowhere to be saved — FR-032
/// of `specs/004-table-screen`). `StorageMode.unavailable` is never registered
/// — the router redirects to `/storage-error` until the user picks a recovery
/// action, so nothing downstream can observe it.
abstract final class StorageDiSwitch {
  const StorageDiSwitch._();

  /// [database] is already open and probed (FR-021c1, FR-021e1).
  static void usePersistentStorage(AppDatabase database) {
    _unregisterIfPresent<AppDatabase>();
    _unregisterIfPresent<DiaryLocalDataSource>();
    _unregisterIfPresent<SettingsLocalDataSource>();
    _unregisterIfPresent<DiaryRepository>();
    _unregisterIfPresent<SettingsRepository>();
    _unregisterIfPresent<StorageMode>();

    getIt.registerSingleton<StorageMode>(StorageMode.persistent);
    getIt.registerLazySingleton<AppDatabase>(() => database);
    getIt.registerLazySingleton<DiaryLocalDataSource>(
      () => DiaryLocalDataSource(getIt<AppDatabase>()),
    );
    getIt.registerLazySingleton<SettingsLocalDataSource>(
      () => SettingsLocalDataSource(getIt<AppDatabase>()),
    );
    getIt.registerLazySingleton<DiaryRepository>(
      () => DiaryRepositoryImpl(
        db: getIt<AppDatabase>(),
        dataSource: getIt<DiaryLocalDataSource>(),
        settingsDataSource: getIt<SettingsLocalDataSource>(),
        clock: getIt<AppClock>(),
        dayResolver: getIt<DayResolver>(),
      ),
    );
    getIt.registerLazySingleton<SettingsRepository>(
      () => SettingsRepositoryImpl(dataSource: getIt<SettingsLocalDataSource>()),
    );
  }

  /// Nothing persists in this mode — only the repository interfaces need
  /// swapping, there's no database to register (FR-021d).
  static void useReadOnlyStorage() {
    _unregisterIfPresent<DiaryRepository>();
    _unregisterIfPresent<SettingsRepository>();
    _unregisterIfPresent<StorageMode>();

    getIt.registerSingleton<StorageMode>(StorageMode.readOnly);
    getIt.registerLazySingleton<DiaryRepository>(() => const UnavailableDiaryRepository());
    getIt.registerLazySingleton<SettingsRepository>(() => ReadOnlySettingsRepository());
  }

  static void _unregisterIfPresent<T extends Object>() {
    // unregister<T>() is typed FutureOr — none of these types register a
    // disposingFunction, so it always completes synchronously here.
    if (getIt.isRegistered<T>()) unawaited(Future.value(getIt.unregister<T>()));
  }
}
