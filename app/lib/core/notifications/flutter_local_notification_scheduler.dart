import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:injectable/injectable.dart';
import 'package:roundtablezoo/core/app_clock/app_clock.dart';
import 'package:roundtablezoo/core/errors/result.dart';
import 'package:roundtablezoo/core/errors/safe_call_mixin.dart';
import 'package:roundtablezoo/core/notifications/notification_launch_queue.dart';
import 'package:roundtablezoo/core/notifications/notification_permission_status.dart';
import 'package:roundtablezoo/core/notifications/notification_scheduler.dart';
import 'package:roundtablezoo/core/notifications/reminder_texts.dart';
import 'package:roundtablezoo/domain/entities/reminder_occurrence.dart';
import 'package:roundtablezoo/domain/value_objects/locale_preference.dart';
import 'package:timezone/timezone.dart' as tz;

const _channelId = 'reminder';

/// Notification payload — a constant, never the day or reminder text
/// itself (principle V).
const reminderNotificationPayload = 'reminder';

/// Only file in the app that imports `flutter_local_notifications`
/// (principle I). Wraps the plugin behind [NotificationScheduler].
@LazySingleton(as: NotificationScheduler)
class FlutterLocalNotificationScheduler with SafeCallMixin implements NotificationScheduler {
  FlutterLocalNotificationScheduler({required this._clock, required this._launchQueue});

  final AppClock _clock;
  final NotificationLaunchQueue _launchQueue;
  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  /// Whether a system permission request has been made this session — the
  /// only way to tell `unknown` from `denied` on Android, where
  /// `areNotificationsEnabled()` returns the same `false` for both
  /// (research.md, R4). Deliberately in-memory, not persisted.
  bool _permissionEverRequested = false;

  @override
  Future<Result<void>> initialize() => safeCall(() async {
    if (_initialized) return;

    // The channel's language is fixed at creation time — the system
    // doesn't rename an existing channel on locale change (FR-016b, R7);
    // recreating it would drop the user's per-channel sound settings.
    final channel = await channelTexts(LocalePreference.system);

    await _plugin.initialize(
      settings: InitializationSettings(
        android: const AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: const DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (response) => _launchQueue.add(response.payload),
    );

    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(
          AndroidNotificationChannel(_channelId, channel.name, description: channel.description),
        );

    _initialized = true;
  });

  @override
  Future<NotificationPermissionStatus> permissionStatus() async {
    final bool? enabled;
    if (Platform.isIOS) {
      final options = await _plugin
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
          ?.checkPermissions();
      enabled = options?.isEnabled;
    } else {
      enabled = await _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.areNotificationsEnabled();
    }
    if (enabled == true) return NotificationPermissionStatus.granted;
    return _permissionEverRequested ? NotificationPermissionStatus.denied : NotificationPermissionStatus.unknown;
  }

  @override
  Future<NotificationPermissionStatus> requestPermission() async {
    _permissionEverRequested = true;
    final bool? granted;
    if (Platform.isIOS) {
      granted = await _plugin
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    } else {
      granted = await _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    }
    return granted == true ? NotificationPermissionStatus.granted : NotificationPermissionStatus.denied;
  }

  @override
  Future<Result<void>> openSystemSettings() => safeCall(() async {
    await _plugin.openAppNotificationSettings();
  });

  @override
  Future<Result<Set<int>>> pendingIds() => safeCall(() async {
    final pending = await _plugin.pendingNotificationRequests();
    return pending.map((request) => request.id).toSet();
  });

  @override
  Future<Result<void>> schedule(
    ReminderOccurrence occurrence, {
    required String title,
    required String body,
  }) => safeCall(() async {
    final scheduledDate = tz.TZDateTime.from(occurrence.scheduledAtUtc, _clock.location);
    await _plugin.zonedSchedule(
      id: occurrence.notificationId,
      scheduledDate: scheduledDate,
      title: title,
      body: body,
      payload: reminderNotificationPayload,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      notificationDetails: const NotificationDetails(
        // Sound/vibration are the channel defaults — no custom sound set
        // (FR-016c). No `matchDateTimeComponents`: this is a one-shot
        // notification, one per day, keyed by `id` (research.md, R2).
        android: AndroidNotificationDetails(_channelId, _channelId),
        iOS: DarwinNotificationDetails(presentAlert: true, presentBanner: true, presentList: true, presentSound: true),
      ),
    );
  });

  @override
  Future<Result<void>> cancel(int notificationId) => safeCall(() async {
    await _plugin.cancel(id: notificationId);
  });
}
