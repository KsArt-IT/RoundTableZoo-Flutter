import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roundtablezoo/data/datasources/diary_local_datasource.dart';
import 'package:roundtablezoo/data/datasources/drift/app_database.dart';
import 'package:roundtablezoo/data/datasources/settings_local_datasource.dart';
import 'package:roundtablezoo/data/repositories/diary_repository_impl.dart';
import 'package:roundtablezoo/domain/entities/character_reaction.dart';
import 'package:roundtablezoo/domain/entities/day_key.dart';
import 'package:roundtablezoo/domain/services/day_resolver.dart';
import 'package:roundtablezoo/domain/value_objects/mood_score.dart';
import 'package:roundtablezoo/domain/value_objects/reaction_tone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../support/fake_app_clock.dart';
import '../support/test_database.dart';

void main() {
  late AppDatabase db;
  late FakeAppClock clock;
  late DiaryRepositoryImpl repository;
  late tz.Location kyiv;

  setUpAll(() {
    tzdata.initializeTimeZones();
    kyiv = tz.getLocation('Europe/Kyiv');
  });

  setUp(() async {
    db = await openTestDatabase();
    clock = FakeAppClock(now: DateTime.utc(2026, 3, 10, 10), location: kyiv);
    repository = DiaryRepositoryImpl(
      db: db,
      dataSource: DiaryLocalDataSource(db),
      settingsDataSource: SettingsLocalDataSource(db),
      clock: clock,
      dayResolver: DayResolver(),
    );
  });

  tearDown(() async {
    await clock.dispose();
    await db.close();
  });

  MoodScore mood(int value) => MoodScore.create(value).valueOrGet(() => throw StateError('bad fixture'));

  test('saving again on the same day updates the existing entry, not a new one', () async {
    final first = await repository.saveTodayEntry(moodScore: mood(3));
    expect(first.isSuccess, isTrue);

    clock.now = DateTime.utc(2026, 3, 10, 14);
    final second = await repository.saveTodayEntry(moodScore: mood(5), dayText: 'better');
    expect(second.isSuccess, isTrue);
    expect(second.valueOrNull?.id, first.valueOrNull?.id);
    expect(second.valueOrNull?.moodScore.value, 5);
    expect(second.valueOrNull?.dayText, 'better');

    final all = await db.select(db.dayEntries).get();
    expect(all, hasLength(1));
  });

  test('concurrent saves on the same day produce exactly one row', () async {
    final results = await Future.wait([
      repository.saveTodayEntry(moodScore: mood(2)),
      repository.saveTodayEntry(moodScore: mood(4)),
    ]);

    expect(results.every((r) => r.isSuccess), isTrue);
    final all = await db.select(db.dayEntries).get();
    expect(all, hasLength(1));
  });

  test('two entries that land in the same computed day (post dayStartHour change) both stay readable', () async {
    // dayStartHour = 12, Kyiv (UTC+2): day 2026-03-10 spans
    // [2026-03-10T10:00Z, 2026-03-11T10:00Z).
    await SettingsLocalDataSource(
      db,
    ).update(const UserSettingsTableCompanion(dayStartHour: Value(12)));

    final earlier = DateTime.utc(2026, 3, 10, 11);
    final later = DateTime.utc(2026, 3, 10, 20);
    final earlierId = await db
        .into(db.dayEntries)
        .insert(
          DayEntriesCompanion.insert(
            occurredAt: earlier,
            moodScore: 2,
            createdAt: earlier,
            updatedAt: earlier,
          ),
        );
    final laterId = await db
        .into(db.dayEntries)
        .insert(
          DayEntriesCompanion.insert(
            occurredAt: later,
            moodScore: 4,
            createdAt: later,
            updatedAt: later,
          ),
        );

    final key = const DayKey(year: 2026, month: 3, day: 10);
    final entries = await repository.entriesForDay(key);
    expect(entries.isSuccess, isTrue);
    expect(entries.valueOrNull?.map((e) => e.id).toSet(), {earlierId, laterId});

    final latest = await repository.entryForDay(key);
    expect(latest.valueOrNull?.id, laterId);
  });

  test('entryForDay returns the latest entry by occurredAt', () async {
    await repository.saveTodayEntry(moodScore: mood(2));
    await SettingsLocalDataSource(
      db,
    ).update(const UserSettingsTableCompanion(dayStartHour: Value(23)));
    clock.now = DateTime.utc(2026, 3, 10, 23);
    final later = await repository.saveTodayEntry(moodScore: mood(5));

    final key = const DayKey(year: 2026, month: 3, day: 10);
    final result = await repository.entryForDay(key);
    expect(result.isSuccess, isTrue);
    expect(result.valueOrNull?.id, later.valueOrNull?.id);
    expect(result.valueOrNull?.moodScore.value, 5);
  });

  test('when occurredAt ties, the later-created (higher id) entry wins', () async {
    final sameInstant = DateTime.utc(2026, 3, 10, 12);
    await db
        .into(db.dayEntries)
        .insert(
          DayEntriesCompanion.insert(
            occurredAt: sameInstant,
            moodScore: 1,
            createdAt: sameInstant,
            updatedAt: sameInstant,
          ),
        );
    final secondId = await db
        .into(db.dayEntries)
        .insert(
          DayEntriesCompanion.insert(
            occurredAt: sameInstant,
            moodScore: 5,
            createdAt: sameInstant,
            updatedAt: sameInstant,
          ),
        );

    final key = const DayKey(year: 2026, month: 3, day: 10);
    final result = await repository.entryForDay(key);
    expect(result.valueOrNull?.id, secondId);
    expect(result.valueOrNull?.moodScore.value, 5);
  });

  test("adding a reaction does not touch the entry's updatedAt", () async {
    final saved = await repository.saveTodayEntry(moodScore: mood(3));
    final entry = saved.valueOrNull!;

    final reactionResult = await repository.addReaction(
      CharacterReaction(
        dayEntryId: entry.id!,
        characterId: 'cat',
        tone: ReactionTone.warm,
        reply: 'nice!',
        intensity: 0.7,
        isFallback: false,
        createdAt: clock.nowUtc(),
      ),
    );
    expect(reactionResult.isSuccess, isTrue);

    final reloaded = await (db.select(
      db.dayEntries,
    )..where((row) => row.id.equals(entry.id!))).getSingle();
    expect(reloaded.updatedAt.toUtc(), entry.updatedAt);
  });
}
