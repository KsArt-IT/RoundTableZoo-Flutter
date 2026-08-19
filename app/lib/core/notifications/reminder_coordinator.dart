import 'dart:async';

import 'package:roundtablezoo/core/app_clock/app_clock.dart';
import 'package:roundtablezoo/core/constants/app_constants.dart';
import 'package:roundtablezoo/core/errors/result.dart';
import 'package:roundtablezoo/core/notifications/notification_permission_status.dart';
import 'package:roundtablezoo/core/notifications/notification_scheduler.dart';
import 'package:roundtablezoo/core/notifications/reminder_texts.dart';
import 'package:roundtablezoo/domain/entities/user_settings.dart';
import 'package:roundtablezoo/domain/repositories/diary_repository.dart';
import 'package:roundtablezoo/domain/repositories/settings_repository.dart';
import 'package:roundtablezoo/domain/services/day_resolver.dart';
import 'package:roundtablezoo/domain/services/reminder_planner.dart';

/// Brings the system notification queue in line with settings and recorded
/// days. Not a Cubit: it has no UI state, and a global Cubit that's
/// actually read somewhere would reproduce the widget-test failures in
/// `project/process/lessons-learned.md` (contracts/notifications.md).
class ReminderCoordinator {
  ReminderCoordinator({
    required AppClock clock,
    required DayResolver dayResolver,
    required ReminderPlanner reminderPlanner,
    required NotificationScheduler notificationScheduler,
    required SettingsRepository settingsRepository,
    required DiaryRepository diaryRepository,
  }) : _clock = clock,
       _dayResolver = dayResolver,
       _reminderPlanner = reminderPlanner,
       _notificationScheduler = notificationScheduler,
       _settingsRepository = settingsRepository,
       _diaryRepository = diaryRepository {
    _settingsSubscription = _settingsRepository.watch().listen((_) => unawaited(reconcile()));
    _diarySubscription = _diaryRepository.watchEntriesChanged().listen(
      (_) => unawaited(reconcile()),
    );
  }

  final AppClock _clock;
  final DayResolver _dayResolver;
  final ReminderPlanner _reminderPlanner;
  final NotificationScheduler _notificationScheduler;
  final SettingsRepository _settingsRepository;
  final DiaryRepository _diaryRepository;

  late final StreamSubscription<UserSettings> _settingsSubscription;
  late final StreamSubscription<void> _diarySubscription;

  /// Guards against overlapping runs: `settingsRepository.watch()` and
  /// `diaryRepository.watchEntriesChanged()` both re-emit their current
  /// value immediately on subscription, so constructing this coordinator
  /// and then calling `reconcile()` explicitly (`main.dart`) fires up to
  /// three concurrent runs. Without serialization, a `cancel()` from a
  /// stale run can land after a fresher run's `schedule()` for the same
  /// id, dropping an occurrence until the next trigger. A call that
  /// arrives while one is in flight doesn't start a second run — it waits
  /// for the current one and then triggers exactly one more, so the
  /// latest settings/entries are never silently skipped.
  Future<Result<void>>? _inFlight;
  bool _rerunRequested = false;

  Future<Result<void>> reconcile() {
    if (_inFlight case final inFlight?) {
      _rerunRequested = true;
      return inFlight;
    }
    final run = _reconcileNow();
    _inFlight = run;
    return run.whenComplete(() {
      _inFlight = null;
      if (_rerunRequested) {
        _rerunRequested = false;
        unawaited(reconcile());
      }
    });
  }

  /// Idempotent: computes the desired `(id, time)` set, compares against
  /// `pendingIds()`, cancels the extra, schedules the missing.
  Future<Result<void>> _reconcileNow() async {
    final settingsResult = await _settingsRepository.load();
    final settings = settingsResult.valueOrNull;
    if (settings == null) return settingsResult.map((_) {});

    final permission = await _notificationScheduler.permissionStatus();
    if (permission != NotificationPermissionStatus.granted) {
      // Planning without permission is pointless and would misrepresent
      // pendingIds() to the settings screen.
      return _cancelAllOwn();
    }

    final nowUtc = _clock.nowUtc();
    final zone = _clock.location;
    final dayStartHour = settings.dayStartHour.value;
    final today = _dayResolver.resolve(nowUtc, zone: zone, dayStartHour: dayStartHour);
    var horizonEnd = today;
    for (var i = 0; i < AppConstants.reminderHorizonDays; i++) {
      horizonEnd = horizonEnd.next;
    }

    final entriesResult = await _diaryRepository.entriesBetween(today, horizonEnd);
    final entries = entriesResult.valueOrNull;
    if (entries == null) return entriesResult.map((_) {});

    final recordedDays = entries
        .map(
          (entry) => _dayResolver.resolve(
            entry.occurredAt,
            zone: zone,
            dayStartHour: dayStartHour,
          ),
        )
        .toSet();

    final plan = _reminderPlanner.plan(
      nowUtc: nowUtc,
      zone: zone,
      settings: settings,
      recordedDays: recordedDays,
    );
    final desired = {for (final occurrence in plan) occurrence.notificationId: occurrence};

    final pendingResult = await _notificationScheduler.pendingIds();
    final pending = pendingResult.valueOrNull;
    if (pending == null) return pendingResult.map((_) {});

    final staleOwnIds = pending.where(_isOwnId).where((id) => !desired.containsKey(id));
    for (final id in staleOwnIds) {
      await _notificationScheduler.cancel(id);
    }

    if (desired.isEmpty) return const Result.success(null);

    final texts = await reminderTexts(settings.locale);
    for (final occurrence in desired.values) {
      final result = await _notificationScheduler.schedule(
        occurrence,
        title: texts.title,
        body: texts.body,
      );
      if (result.isFailure) return result;
    }

    return const Result.success(null);
  }

  Future<Result<void>> _cancelAllOwn() async {
    final pendingResult = await _notificationScheduler.pendingIds();
    final pending = pendingResult.valueOrNull;
    if (pending == null) return pendingResult.map((_) {});

    for (final id in pending.where(_isOwnId)) {
      await _notificationScheduler.cancel(id);
    }
    return const Result.success(null);
  }

  /// Only ids of the shape `YYYYMMDD` (`ReminderOccurrence.notificationId`)
  /// are ours to manage — other future notification kinds must not be
  /// touched (contracts/notifications.md).
  bool _isOwnId(int id) {
    if (id < 20000101 || id > 29991231) return false;
    final day = id % 100;
    final month = (id ~/ 100) % 100;
    return day >= 1 && day <= 31 && month >= 1 && month <= 12;
  }

  Future<void> dispose() async {
    await _settingsSubscription.cancel();
    await _diarySubscription.cancel();
  }
}
