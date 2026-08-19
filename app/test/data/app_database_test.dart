import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roundtablezoo/data/datasources/drift/app_database.dart';
import 'package:roundtablezoo/data/mappers/character_reaction_mapper.dart';
import 'package:roundtablezoo/data/mappers/day_entry_mapper.dart';
import 'package:roundtablezoo/domain/value_objects/reaction_tone.dart';

import '../support/test_database.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = await openTestDatabase();
  });

  tearDown(() => db.close());

  test('creating the database seeds exactly one default settings row', () async {
    final rows = await db.select(db.userSettingsTable).get();
    expect(rows, hasLength(1));
    expect(rows.single.id, 1);
    expect(rows.single.themeMode, 'system');
    expect(rows.single.locale, 'system');
    expect(rows.single.dayStartHour, 0);
  });

  test('deleting a day entry cascades to its character reactions', () async {
    final now = DateTime.utc(2026, 1, 1, 12);
    final entryId = await db
        .into(db.dayEntries)
        .insert(
          DayEntriesCompanion.insert(
            occurredAt: now,
            moodScore: 3,
            createdAt: now,
            updatedAt: now,
          ),
        );
    await db
        .into(db.characterReactions)
        .insert(
          CharacterReactionsCompanion.insert(
            dayEntryId: entryId,
            characterId: 'cat',
            reply: 'meow',
            intensity: 0.5,
            createdAt: now,
          ),
        );

    await (db.delete(db.dayEntries)..where((row) => row.id.equals(entryId))).go();

    final remainingReactions = await db.select(db.characterReactions).get();
    expect(remainingReactions, isEmpty);
  });

  test(
    'a reaction with a tone outside the enum is stored with neutral tone, text unchanged',
    () async {
      final now = DateTime.utc(2026, 1, 1, 12);
      final entryId = await db
          .into(db.dayEntries)
          .insert(
            DayEntriesCompanion.insert(
              occurredAt: now,
              moodScore: 3,
              createdAt: now,
              updatedAt: now,
            ),
          );
      await db
          .into(db.characterReactions)
          .insert(
            CharacterReactionsCompanion.insert(
              dayEntryId: entryId,
              characterId: 'dog',
              tone: const Value('ecstatic-not-a-real-tone'),
              reply: 'woof but weird',
              intensity: 0.9,
              createdAt: now,
            ),
          );

      final row = await db.select(db.characterReactions).getSingle();
      final entity = row.toEntity();

      expect(entity.tone, ReactionTone.neutral);
      expect(entity.reply, 'woof but weird');
    },
  );

  test('mapping a stored day entry round-trips through toEntity', () async {
    final now = DateTime.utc(2026, 1, 1, 12);
    await db
        .into(db.dayEntries)
        .insert(
          DayEntriesCompanion.insert(
            occurredAt: now,
            moodScore: 4,
            dayText: const Value('a fine day'),
            createdAt: now,
            updatedAt: now,
          ),
        );

    final entity = (await db.select(db.dayEntries).getSingle()).toEntity();
    expect(entity.moodScore.value, 4);
    expect(entity.dayText, 'a fine day');
    expect(entity.occurredAt, now);
  });
}
