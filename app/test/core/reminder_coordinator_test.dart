import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:roundtablezoo/core/constants/app_constants.dart';
import 'package:roundtablezoo/core/errors/result.dart';
import 'package:roundtablezoo/core/notifications/notification_permission_status.dart';
import 'package:roundtablezoo/core/notifications/reminder_coordinator.dart';
import 'package:roundtablezoo/domain/entities/day_entry.dart';
import 'package:roundtablezoo/domain/entities/day_key.dart';
import 'package:roundtablezoo/domain/entities/reminder_occurrence.dart';
import 'package:roundtablezoo/domain/entities/user_settings.dart';
import 'package:roundtablezoo/domain/services/day_resolver.dart';
import 'package:roundtablezoo/domain/services/reminder_planner.dart';
import 'package:roundtablezoo/domain/value_objects/day_start_hour.dart';
import 'package:roundtablezoo/domain/value_objects/locale_preference.dart';
import 'package:roundtablezoo/domain/value_objects/mood_score.dart';
import 'package:roundtablezoo/domain/value_objects/reminder_time.dart';
import 'package:roundtablezoo/domain/value_objects/theme_preference.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../support/fake_app_clock.dart';
import '../support/mocks.dart';

UserSettings _settings({bool reminderEnabled = true, int hour = 20, int minute = 0, int dayStartHour = 0}) =>
    UserSettings(
      installId: 'test',
      themeMode: ThemePreference.system,
      locale: LocalePreference.ru,
      soundEnabled: true,
      enabledCharacterIds: const ['cat'],
      hasSeenOnboarding: true,
      reminderEnabled: reminderEnabled,
      reminderTime: ReminderTime.create(hour: hour, minute: minute).valueOrGet(() => throw StateError('x')),
      dayStartHour: DayStartHour.create(dayStartHour).valueOrGet(() => throw StateError('x')),
    );

void main() {
  late MockSettingsRepository settingsRepository;
  late MockDiaryRepository diaryRepository;
  late MockNotificationScheduler scheduler;
  late FakeAppClock clock;
  late ReminderCoordinator coordinator;
  late Set<int> pending;
  late tz.Location utc;

  setUpAll(() {
    tz.initializeTimeZones();
    utc = tz.UTC;
    registerFallbackValue(ReminderOccurrence(day: const DayKey(year: 2026, month: 1, day: 1), scheduledAtUtc: DateTime.utc(2026)));
    registerFallbackValue(const DayKey(year: 2026, month: 1, day: 1));
  });

  void stubScheduler(NotificationPermissionStatus permission) {
    when(() => scheduler.permissionStatus()).thenAnswer((_) async => permission);
    when(() => scheduler.pendingIds()).thenAnswer((_) async => Result.success(Set.of(pending)));
    when(
      () => scheduler.schedule(any(), title: any(named: 'title'), body: any(named: 'body')),
    ).thenAnswer((invocation) async {
      final occurrence = invocation.positionalArguments[0] as ReminderOccurrence;
      pending.add(occurrence.notificationId);
      return const Result.success(null);
    });
    when(() => scheduler.cancel(any())).thenAnswer((invocation) async {
      pending.remove(invocation.positionalArguments[0] as int);
      return const Result.success(null);
    });
  }

  setUp(() {
    settingsRepository = MockSettingsRepository();
    diaryRepository = MockDiaryRepository();
    scheduler = MockNotificationScheduler();
    pending = <int>{};
    clock = FakeAppClock(now: DateTime.utc(2026, 3, 10, 10), location: utc);

    when(() => settingsRepository.watch()).thenAnswer((_) => const Stream.empty());
    when(() => diaryRepository.watchEntriesChanged()).thenAnswer((_) => const Stream.empty());
    when(() => settingsRepository.load()).thenAnswer((_) async => Result.success(_settings()));
    when(() => diaryRepository.entriesBetween(any(), any())).thenAnswer((_) async => const Result.success([]));
    stubScheduler(NotificationPermissionStatus.granted);

    coordinator = ReminderCoordinator(
      clock: clock,
      dayResolver: DayResolver(),
      reminderPlanner: ReminderPlanner(dayResolver: DayResolver()),
      notificationScheduler: scheduler,
      settingsRepository: settingsRepository,
      diaryRepository: diaryRepository,
    );
  });

  tearDown(() async {
    await coordinator.dispose();
    await clock.dispose();
  });

  test('reconcile plans the full horizon and settles on a stable queue', () async {
    await coordinator.reconcile();
    expect(pending, hasLength(AppConstants.reminderHorizonDays));
    verifyNever(() => scheduler.cancel(any()));

    final settledAfterFirst = Set.of(pending);
    // Contract: `schedule()` re-writes the desired set on every call
    // (contracts/notifications.md) — cheaper than diffing times, and safe
    // since overwriting the same id is a no-op for the system queue. So
    // idempotency here means the *resulting id set* is stable, not that
    // the call count stays at zero.
    await coordinator.reconcile();

    expect(pending, settledAfterFirst);
    verifyNever(() => scheduler.cancel(any()));
  });

  test("permission not granted clears only this coordinator's own ids", () async {
    pending
      ..add(20260310) // ours (YYYYMMDD)
      ..add(555); // some other feature's id — must survive
    stubScheduler(NotificationPermissionStatus.denied);

    await coordinator.reconcile();

    expect(pending, {555});
    verifyNever(() => scheduler.schedule(any(), title: any(named: 'title'), body: any(named: 'body')));
  });

  test('marking today recorded cancels today and keeps the rest of the plan', () async {
    await coordinator.reconcile();
    final todayId = const DayKey(year: 2026, month: 3, day: 10).let((key) => key.year * 10000 + key.month * 100 + key.day);
    expect(pending.contains(todayId), isTrue);

    final entry = DayEntry(
      occurredAt: DateTime.utc(2026, 3, 10, 9),
      moodScore: MoodScore.create(3).valueOrGet(() => throw StateError('x')),
      createdAt: DateTime.utc(2026, 3, 10, 9),
      updatedAt: DateTime.utc(2026, 3, 10, 9),
    );
    when(() => diaryRepository.entriesBetween(any(), any())).thenAnswer((_) async => Result.success([entry]));

    await coordinator.reconcile();

    expect(pending.contains(todayId), isFalse);
    expect(pending, hasLength(AppConstants.reminderHorizonDays - 1));
  });

  test('un-recording a day (entry deleted) restores its reminder', () async {
    final entry = DayEntry(
      occurredAt: DateTime.utc(2026, 3, 10, 9),
      moodScore: MoodScore.create(3).valueOrGet(() => throw StateError('x')),
      createdAt: DateTime.utc(2026, 3, 10, 9),
      updatedAt: DateTime.utc(2026, 3, 10, 9),
    );
    when(() => diaryRepository.entriesBetween(any(), any())).thenAnswer((_) async => Result.success([entry]));
    await coordinator.reconcile();
    final todayId = const DayKey(year: 2026, month: 3, day: 10).let((key) => key.year * 10000 + key.month * 100 + key.day);
    expect(pending.contains(todayId), isFalse);

    when(() => diaryRepository.entriesBetween(any(), any())).thenAnswer((_) async => const Result.success([]));
    await coordinator.reconcile();

    expect(pending.contains(todayId), isTrue);
  });

  test('overlapping reconcile() calls do not run concurrently, but one rerun follows', () async {
    final gate = Completer<void>();
    var loadCalls = 0;
    when(() => settingsRepository.load()).thenAnswer((_) async {
      loadCalls++;
      if (loadCalls == 1) await gate.future;
      return Result.success(_settings());
    });

    final first = coordinator.reconcile();
    final second = coordinator.reconcile();

    // A second call that arrives while the first is still in flight must
    // not start its own pass — it should wait and trigger exactly one
    // rerun once the first finishes, never overlap with it.
    await Future<void>.delayed(Duration.zero);
    expect(loadCalls, 1);

    gate.complete();
    await first;
    await second;

    expect(loadCalls, 2);
    expect(pending, hasLength(AppConstants.reminderHorizonDays));
  });

  test('changing the reminder time re-plans (same id set, re-scheduled)', () async {
    await coordinator.reconcile();
    final before = Set.of(pending);

    when(() => settingsRepository.load()).thenAnswer((_) async => Result.success(_settings(hour: 21)));
    await coordinator.reconcile();

    expect(pending, before);
    verify(
      () => scheduler.schedule(any(), title: any(named: 'title'), body: any(named: 'body')),
    ).called(AppConstants.reminderHorizonDays * 2);
  });
}

extension _Let<T> on T {
  R let<R>(R Function(T value) block) => block(this);
}
