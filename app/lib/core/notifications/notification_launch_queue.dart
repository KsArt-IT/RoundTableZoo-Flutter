import 'dart:async';

import 'package:injectable/injectable.dart';

/// Carries a tapped notification's `payload` from
/// `onDidReceiveNotificationResponse` (no `BuildContext` there) to
/// `AppRoot`, which owns navigation (research.md, R6).
@lazySingleton
class NotificationLaunchQueue {
  final StreamController<String> _controller = StreamController<String>.broadcast();

  /// Emits a `payload` every time a notification is tapped while the app is
  /// alive (warm path — the cold-start path is handled separately via
  /// `getNotificationAppLaunchDetails()` in `main.dart`).
  Stream<String> get taps => _controller.stream;

  void add(String? payload) {
    if (payload == null) return;
    _controller.add(payload);
  }

  Future<void> dispose() => _controller.close();
}
