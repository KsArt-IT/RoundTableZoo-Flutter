import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'package:roundtablezoo/core/utils/app_logger.dart';

/// Application startup sequence.
///
/// Full implementation (DB open, storage-mode probe) lands with the storage
/// recovery flow; for now this only exposes the iOS backup-exclusion hook
/// required by FR-016d.
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
      if (!kReleaseMode) logger.w('Failed to exclude "$path" from backup', error: e, stackTrace: st);
    } on MissingPluginException catch (e, st) {
      if (!kReleaseMode) logger.w('Failed to exclude "$path" from backup', error: e, stackTrace: st);
    }
  }
}
