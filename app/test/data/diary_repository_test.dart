import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roundtablezoo/core/errors/app_failure.dart';
import 'package:roundtablezoo/data/datasources/diary_local_datasource.dart';
import 'package:roundtablezoo/data/datasources/drift/app_database.dart';
import 'package:roundtablezoo/data/datasources/settings_local_datasource.dart';
import 'package:roundtablezoo/data/repositories/diary_repository_impl.dart';
import 'package:roundtablezoo/domain/entities/character_reaction.dart';
import 'package:roundtablezoo/domain/entities/day_key.dart';
import 'package:roundtablezoo/domain/entities/diary_page.dart';
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

  MoodScore mood(int value) =>
      MoodScore.create(value).valueOrGet(() => throw StateError('bad fixture'));

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

  test(
    'two entries that land in the same computed day (post dayStartHour change) both stay readable',
    () async {
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
    },
  );

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

  group('entriesPage / moodHistory / reactionsForEntries (005-diary-screen)', () {
    // A UTC clock keeps day boundaries at plain UTC midnight — dayStartHour
    // stays at its default (0), so `DateTime.utc(y, m, d)` is both an
    // `occurredAt` and the start of that computed day.
    late FakeAppClock utcClock;
    late DiaryRepositoryImpl utcRepository;

    setUp(() {
      utcClock = FakeAppClock(now: DateTime.utc(2026, 3, 10), location: tz.UTC);
      utcRepository = DiaryRepositoryImpl(
        db: db,
        dataSource: DiaryLocalDataSource(db),
        settingsDataSource: SettingsLocalDataSource(db),
        clock: utcClock,
        dayResolver: DayResolver(),
      );
    });

    tearDown(() async {
      await utcClock.dispose();
    });

    Future<int> insertEntry(DateTime occurredAt, int score) => db
        .into(db.dayEntries)
        .insert(
          DayEntriesCompanion.insert(
            occurredAt: occurredAt,
            moodScore: score,
            createdAt: occurredAt,
            updatedAt: occurredAt,
          ),
        );

    test('first page, no cursor: newest days first', () async {
      await insertEntry(DateTime.utc(2026, 3, 1), 1);
      await insertEntry(DateTime.utc(2026, 3, 2), 2);
      await insertEntry(DateTime.utc(2026, 3, 3), 3);

      final result = await utcRepository.entriesPage(limit: 10);
      expect(result.isSuccess, isTrue);
      final page = result.valueOrNull!;
      expect(page.days.map((d) => d.day), [
        const DayKey(year: 2026, month: 3, day: 3),
        const DayKey(year: 2026, month: 3, day: 2),
        const DayKey(year: 2026, month: 3, day: 1),
      ]);
      expect(page.hasMore, isFalse);
    });

    test('second page continues strictly before the previous page\'s nextCursor', () async {
      await insertEntry(DateTime.utc(2026, 3, 1), 1);
      await insertEntry(DateTime.utc(2026, 3, 2), 2);
      await insertEntry(DateTime.utc(2026, 3, 3), 3);

      final first = await utcRepository.entriesPage(limit: 2);
      final firstPage = first.valueOrNull!;
      expect(firstPage.hasMore, isTrue);
      expect(firstPage.days.map((d) => d.day.day), [3, 2]);

      final second = await utcRepository.entriesPage(
        beforeOccurredAt: firstPage.nextCursor,
        limit: 2,
      );
      final secondPage = second.valueOrNull!;
      expect(secondPage.days.map((d) => d.day.day), [1]);
      expect(secondPage.hasMore, isFalse);
    });

    test('several entries on the same day collapse to the latest by occurredAt', () async {
      await insertEntry(DateTime.utc(2026, 3, 1, 8), 2);
      await insertEntry(DateTime.utc(2026, 3, 1, 20), 5);

      final result = await utcRepository.entriesPage(limit: 10);
      final page = result.valueOrNull!;
      expect(page.days, hasLength(1));
      expect(page.days.single.entry.moodScore.value, 5);
    });

    test('hasMore is true exactly when the datasource returned a full page of rows', () async {
      await insertEntry(DateTime.utc(2026, 3, 1), 1);
      await insertEntry(DateTime.utc(2026, 3, 2), 2);

      final full = await utcRepository.entriesPage(limit: 2);
      expect(full.valueOrNull!.hasMore, isTrue);

      final short = await utcRepository.entriesPage(limit: 3);
      expect(short.valueOrNull!.hasMore, isFalse);
    });

    test(
      'nextCursor is the start of the last day on the page, not the row\'s occurredAt',
      () async {
        await insertEntry(DateTime.utc(2026, 3, 1, 15), 1);
        await insertEntry(DateTime.utc(2026, 3, 2, 9), 2);

        final result = await utcRepository.entriesPage(limit: 10);
        final page = result.valueOrNull!;
        expect(page.nextCursor, DateTime.utc(2026, 3, 1));
      },
    );

    test('a day whose entries span a page boundary is not returned twice', () async {
      // Two entries on 2026-03-02: one lands on each page if the cursor
      // were the row's occurredAt instead of the day's start.
      await insertEntry(DateTime.utc(2026, 3, 1), 1);
      await insertEntry(DateTime.utc(2026, 3, 2, 8), 2);
      await insertEntry(DateTime.utc(2026, 3, 2, 20), 3);

      final first = await utcRepository.entriesPage(limit: 1);
      final firstPage = first.valueOrNull!;
      expect(firstPage.days.single.day.day, 2);

      final second = await utcRepository.entriesPage(
        beforeOccurredAt: firstPage.nextCursor,
        limit: 10,
      );
      final allDays = [...firstPage.days, ...second.valueOrNull!.days].map((d) => d.day.day);
      expect(allDays.toSet(), {1, 2});
      expect(allDays, hasLength(2));
    });

    test('a whole page landing on one day still advances the cursor', () async {
      await insertEntry(DateTime.utc(2026, 3, 5, 1), 1);
      await insertEntry(DateTime.utc(2026, 3, 5, 12), 2);
      await insertEntry(DateTime.utc(2026, 3, 5, 20), 3);
      await insertEntry(DateTime.utc(2026, 3, 4), 4);

      final first = await utcRepository.entriesPage(limit: 3);
      final firstPage = first.valueOrNull!;
      expect(firstPage.days, hasLength(1));
      expect(firstPage.days.single.day.day, 5);
      expect(firstPage.hasMore, isTrue);
      expect(firstPage.nextCursor, DateTime.utc(2026, 3, 5));

      final second = await utcRepository.entriesPage(
        beforeOccurredAt: firstPage.nextCursor,
        limit: 3,
      );
      expect(second.valueOrNull!.days.single.day.day, 4);
    });

    test('empty database returns an empty page', () async {
      final result = await utcRepository.entriesPage(limit: 10);
      expect(result.valueOrNull, const DiaryPage(days: [], hasMore: false, nextCursor: null));
    });

    test('limit <= 0 is a ValidationFailure', () async {
      final result = await utcRepository.entriesPage(limit: 0);
      expect(result.isFailure, isTrue);
      expect(result.errorOrNull, isA<ValidationFailure>());
    });

    test('moodHistory returns one point per day, ascending', () async {
      await insertEntry(DateTime.utc(2026, 3, 1), 1);
      await insertEntry(DateTime.utc(2026, 3, 2, 8), 3);
      await insertEntry(DateTime.utc(2026, 3, 2, 20), 5);

      final result = await utcRepository.moodHistory();
      expect(result.isSuccess, isTrue);
      final points = result.valueOrNull!;
      expect(points.map((p) => p.day.day), [1, 2]);
      expect(points.map((p) => p.moodScore.value), [1, 5]);
    });

    test('moodHistory on an empty database returns an empty list', () async {
      final result = await utcRepository.moodHistory();
      expect(result.valueOrNull, isEmpty);
    });

    test('reactionsForEntries groups by dayEntryId, ordered by createdAt', () async {
      final entryId = await insertEntry(DateTime.utc(2026, 3, 1), 3);
      final otherEntryId = await insertEntry(DateTime.utc(2026, 3, 2), 4);

      final early = DateTime.utc(2026, 3, 1, 8);
      final late = DateTime.utc(2026, 3, 1, 9);
      await db
          .into(db.characterReactions)
          .insert(
            CharacterReactionsCompanion.insert(
              dayEntryId: entryId,
              characterId: 'dog',
              reply: 'second',
              intensity: 0.5,
              createdAt: late,
            ),
          );
      await db
          .into(db.characterReactions)
          .insert(
            CharacterReactionsCompanion.insert(
              dayEntryId: entryId,
              characterId: 'cat',
              reply: 'first',
              intensity: 0.5,
              createdAt: early,
            ),
          );

      final result = await utcRepository.reactionsForEntries([entryId, otherEntryId]);
      final byEntry = result.valueOrNull!;
      expect(byEntry[entryId]?.map((r) => r.reply), ['first', 'second']);
      expect(byEntry.containsKey(otherEntryId), isFalse);
    });

    test('reactionsForEntries on an empty input returns an empty map without querying', () async {
      final result = await utcRepository.reactionsForEntries(const []);
      expect(result.valueOrNull, isEmpty);
    });
  });
}
