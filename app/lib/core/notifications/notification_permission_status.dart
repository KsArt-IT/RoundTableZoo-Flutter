/// Notification permission status, read from the system on demand — never
/// persisted (data-model.md).
enum NotificationPermissionStatus {
  /// Notifications will be delivered.
  granted,

  /// Denied — a repeat system prompt may not appear (research.md, R4).
  denied,

  /// Not asked yet. Requesting will show the system prompt.
  unknown,
}
