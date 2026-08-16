import 'package:roundtablezoo/core/errors/result.dart';
import 'package:roundtablezoo/core/notifications/notification_permission_status.dart';
import 'package:roundtablezoo/domain/entities/reminder_occurrence.dart';

/// Abstraction over the system notification queue. Implementation is
/// `FlutterLocalNotificationScheduler`; tests substitute a mocktail mock —
/// the platform channel doesn't respond in unit tests
/// (contracts/notifications.md).
abstract interface class NotificationScheduler {
  /// Initializes the plugin and the tap callback. Idempotent.
  Future<Result<void>> initialize();

  /// Current permission status (data-model.md).
  Future<NotificationPermissionStatus> permissionStatus();

  /// System permission prompt (FR-020). Returns the status AFTER the user
  /// responds. If the system declines to show the prompt, returns `denied`
  /// — the caller doesn't distinguish "just refused" from "refused before"
  /// (FR-021).
  Future<NotificationPermissionStatus> requestPermission();

  /// Opens the app's system notification settings (FR-021, FR-025b). Same
  /// behavior on Android and iOS.
  Future<Result<void>> openSystemSettings();

  /// What's actually queued — the source of truth (data-model.md).
  Future<Result<Set<int>>> pendingIds();

  Future<Result<void>> schedule(
    ReminderOccurrence occurrence, {
    required String title,
    required String body,
  });

  Future<Result<void>> cancel(int notificationId);
}
