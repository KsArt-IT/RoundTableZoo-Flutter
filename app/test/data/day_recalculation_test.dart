import 'package:flutter_test/flutter_test.dart';
import 'package:roundtablezoo/data/datasources/diary_local_datasource.dart';
import 'package:roundtablezoo/data/datasources/drift/app_database.dart';
import 'package:roundtablezoo/data/datasources/settings_local_datasource.dart';
import 'package:roundtablezoo/data/repositories/diary_repository_impl.dart';
import 'package:roundtablezoo/data/repositories/settings_repository_impl.dart';
import 'package:roundtablezoo/domain/entities/day_key.dart';
import 'package:roundtablezoo/domain/services/day_resolver.dart';
import 'package:roundtablezoo/domain/value_objects/day_start_hour.dart';
import 'package:roundtablezoo/domain/value_objects/mood_score.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../support/fake_app_clock.dart';
import '../support/test_database.dart';

void main() {
  late AppDatabase db;
  late FakeAppClock clock;
  late DiaryRepositoryImpl diaryRepository;
  late SettingsRepositoryImpl settingsRepository;
  late tz.Location kyiv;

  setUpAll(() {
    tzdata.initializeTimeZones();
    kyiv = tz.getLocation('Europe/Kyiv');
  });

  setUp(() async {
    db = await openTestDatabase();
    // 2026-03-10T02:00 UTC = 04:00 Kyiv local.
    clock = FakeAppClock(now: DateTime.utc(2026, 3, 10, 2), location: kyiv);
    final settingsDataSource = SettingsLocalDataSource(db);
    diaryRepository = DiaryRepositoryImpl(
      db: db,
      dataSource: DiaryLocalDataSource(db),
      settingsDataSource: settingsDataSource,
      clock: clock,
      dayResolver: DayResolver(),
    );
    settingsRepository = SettingsRepositoryImpl(dataSource: settingsDataSource);
  });

  tearDown(() async {
    await clock.dispose();
    await db.close();
  });

  test('changing dayStartHour recomputes which day a saved moment belongs to', () async {
    // dayStartHour = 0: 04:00 Kyiv local -> day 2026-03-10.
    final saved = await diaryRepository.saveTodayEntry(
      moodScore: MoodScore.create(3).valueOrGet(() => throw StateError('bad fixture')),
    );
    expect(saved.isSuccess, isTrue);
    final entry = saved.valueOrNull!;
    final occurredAtBefore = entry.occurredAt;

    const oldDayKey = DayKey(year: 2026, month: 3, day: 10);
    final beforeChange = await diaryRepository.entryForDay(oldDayKey);
    expect(beforeChange.valueOrNull?.id, entry.id);

    // dayStartHour = 6: 04:00 Kyiv local is still "yesterday" (before the
    // new 06:00 boundary) -> the same moment now belongs to 2026-03-09.
    final hour6 = DayStartHour.create(6).valueOrGet(() => throw StateError('bad fixture'));
    final updateResult = await settingsRepository.updateDayStartHour(hour6);
    expect(updateResult.isSuccess, isTrue);

    // The stored instant itself never changes (FR-026).
    const newDayKey = DayKey(year: 2026, month: 3, day: 9);
    final afterChange = await diaryRepository.entryForDay(newDayKey);
    expect(afterChange.isSuccess, isTrue);
    expect(afterChange.valueOrNull?.id, entry.id);
    expect(afterChange.valueOrNull?.occurredAt, occurredAtBefore);

    // It's no longer found under the old key — the day is recomputed, not
    // duplicated or left ambiguous.
    final staleLookup = await diaryRepository.entryForDay(oldDayKey);
    expect(staleLookup.valueOrNull, isNull);

    // Still exactly one physical row — recomputing a day never mutates or
    // duplicates storage.
    final allRows = await db.select(db.dayEntries).get();
    expect(allRows, hasLength(1));
    expect(allRows.single.occurredAt.toUtc(), occurredAtBefore);
  });
}
