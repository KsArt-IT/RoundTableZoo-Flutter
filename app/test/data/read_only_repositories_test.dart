import 'package:flutter_test/flutter_test.dart';
import 'package:roundtablezoo/core/errors/app_failure.dart';
import 'package:roundtablezoo/data/repositories/read_only_repositories.dart';
import 'package:roundtablezoo/domain/entities/character_reaction.dart';
import 'package:roundtablezoo/domain/entities/day_key.dart';
import 'package:roundtablezoo/domain/value_objects/mood_score.dart';
import 'package:roundtablezoo/domain/value_objects/reaction_tone.dart';
import 'package:roundtablezoo/domain/value_objects/theme_preference.dart';

void main() {
  group('ReadOnlySettingsRepository', () {
    test('load() returns default settings with a session-only installId', () async {
      final repo = ReadOnlySettingsRepository();
      final result = await repo.load();

      expect(result.isSuccess, isTrue);
      expect(result.valueOrNull?.themeMode, ThemePreference.system);
      expect(result.valueOrNull?.installId, isNotEmpty);
    });

    test('two instances never share an installId', () async {
      final first = await ReadOnlySettingsRepository().load();
      final second = await ReadOnlySettingsRepository().load();
      expect(first.valueOrNull?.installId, isNot(second.valueOrNull?.installId));
    });

    test('watch() emits the same session defaults load() returns', () async {
      final repo = ReadOnlySettingsRepository();
      final loaded = await repo.load();
      final watched = await repo.watch().first;
      expect(watched.installId, loaded.valueOrNull?.installId);
    });

    test('every update* call fails with storageReadOnly, nothing is saved', () async {
      final repo = ReadOnlySettingsRepository();

      final results = await Future.wait([
        repo.updateThemeMode(ThemePreference.dark),
        repo.updateSoundEnabled(value: false),
        repo.markOnboardingSeen(),
      ]);

      for (final result in results) {
        expect(result.isFailure, isTrue);
        expect(result.errorOrNull, isA<DatabaseFailure>());
        expect(result.errorOrNull?.code, DatabaseFailure.storageReadOnly);
      }
    });
  });

  group('UnavailableDiaryRepository', () {
    const repo = UnavailableDiaryRepository();
    const key = DayKey(year: 2026, month: 1, day: 1);

    test('reads come back empty rather than exposing stale data', () async {
      expect((await repo.entryForDay(key)).valueOrNull, isNull);
      expect((await repo.entriesForDay(key)).valueOrNull, isEmpty);
      expect((await repo.entriesBetween(key, key)).valueOrNull, isEmpty);
      expect((await repo.reactionsFor(1)).valueOrNull, isEmpty);
    });

    test('writes fail explicitly with storageReadOnly', () async {
      final saveResult = await repo.saveTodayEntry(
        moodScore: MoodScore.create(3).valueOrGet(() => throw StateError('bad fixture')),
      );
      expect(saveResult.isFailure, isTrue);
      expect(saveResult.errorOrNull?.code, DatabaseFailure.storageReadOnly);

      final deleteResult = await repo.deleteEntry(1);
      expect(deleteResult.errorOrNull?.code, DatabaseFailure.storageReadOnly);

      final reactionResult = await repo.addReaction(
        CharacterReaction(
          dayEntryId: 1,
          characterId: 'cat',
          tone: ReactionTone.neutral,
          reply: 'hi',
          intensity: 0.5,
          isFallback: false,
          createdAt: DateTime.utc(2026),
        ),
      );
      expect(reactionResult.errorOrNull?.code, DatabaseFailure.storageReadOnly);
    });
  });
}
