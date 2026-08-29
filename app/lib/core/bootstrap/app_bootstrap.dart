import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:roundtablezoo/core/bootstrap/app_session.dart';
import 'package:roundtablezoo/core/bootstrap/storage_mode.dart';
import 'package:roundtablezoo/core/errors/app_failure.dart';
import 'package:roundtablezoo/core/errors/result.dart';
import 'package:roundtablezoo/core/utils/app_logger.dart';
import 'package:roundtablezoo/data/datasources/drift/app_database.dart';
import 'package:roundtablezoo/data/datasources/drift/database_file_location.dart';

/// Application startup sequence: open the database, confirm it's usable,
/// and report the outcome as a [StorageMode] instead of letting a broken
/// database crash the app (FR-021a).
abstract final class AppBootstrap {
  static const MethodChannel _backupExclusionChannel = MethodChannel(
    'roundtablezoo/backup_exclusion',
  );

  /// Marks [path] (a file or directory) as excluded from iCloud/iTunes
  /// device backups. No-op on platforms other than iOS — Android relies on
  /// `android:allowBackup="false"` in the manifest instead.
  static Future<void> excludeFromBackup(String path) async {
    if (!Platform.isIOS) return;
    try {
      await _backupExclusionChannel.invokeMethod<bool>('excludeFromBackup', path);
    } on PlatformException catch (e, st) {
      if (!kReleaseMode) {
        logger.w('Failed to exclude "$path" from backup', error: e, stackTrace: st);
      }
    } on MissingPluginException catch (e, st) {
      if (!kReleaseMode) {
        logger.w('Failed to exclude "$path" from backup', error: e, stackTrace: st);
      }
    }
  }

  /// Probes [database] with a trivial query. Never throws — a failed open
  /// is reported as `AppSession(mode: unavailable, cause: ...)`, not an
  /// exception (FR-021a, FR-018).
  static Future<Result<AppSession>> start(AppDatabase database) async {
    try {
      await database.customStatement('SELECT 1');
      // Touches the settings table too — an open-but-empty/corrupt schema
      // should fail here, not on the first real read.
      await database.select(database.userSettingsTable).get();
      // Only iOS needs the file path — Android's manifest flag doesn't
      // touch path_provider at all, so skip it there.
      if (Platform.isIOS) {
        await excludeFromBackup((await resolveDatabaseFile()).path);
      }
      return const Result.success(AppSession(mode: StorageMode.persistent));
    } on Object catch (e, st) {
      logger.e('Failed to open the database', error: e, stackTrace: st);
      return Result.success(
        AppSession(
          mode: StorageMode.unavailable,
          cause: DatabaseFailure(e.toString(), code: DatabaseFailure.storageUnavailable),
        ),
      );
    }
  }

  /// Deletes the database file and its `-wal`/`-shm` siblings. Irreversible
  /// — the caller must have already confirmed with the user (FR-021c) and
  /// must close any open connection to this database before calling this.
  static Future<Result<void>> resetData() async {
    try {
      final path = (await resolveDatabaseFile()).path;
      for (final suffix in ['', '-wal', '-shm']) {
        final file = File('$path$suffix');
        if (await file.exists()) await file.delete();
      }
      return const Result.success(null);
    } on Object catch (e, st) {
      logger.e('Failed to reset the database', error: e, stackTrace: st);
      return Result.failure(
        DatabaseFailure(e.toString(), code: DatabaseFailure.storageUnavailable),
      );
    }
  }
}
