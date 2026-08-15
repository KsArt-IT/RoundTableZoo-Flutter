import 'dart:math';

/// 32 hex characters from a cryptographically secure source (FR-015).
/// Shared by `SettingsLocalDataSource` (persisted) and
/// `ReadOnlySettingsRepository` (session-only, never persisted).
String generateInstallId() {
  final random = Random.secure();
  return List.generate(32, (_) => random.nextInt(16).toRadixString(16)).join();
}
