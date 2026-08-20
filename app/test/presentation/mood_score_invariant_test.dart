import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:roundtablezoo/core/errors/result.dart';
import 'package:roundtablezoo/domain/entities/character_reaction.dart';
import 'package:roundtablezoo/domain/entities/day_entry.dart';
import 'package:roundtablezoo/domain/entities/day_key.dart';
import 'package:roundtablezoo/domain/entities/diary_day_entry.dart';
import 'package:roundtablezoo/domain/entities/diary_page.dart';
import 'package:roundtablezoo/domain/entities/mood_chart_point.dart';
import 'package:roundtablezoo/domain/usecases/export_diary_to_csv.dart';
import 'package:roundtablezoo/domain/value_objects/mood_score.dart';
import 'package:roundtablezoo/domain/value_objects/reaction_tone.dart';
import 'package:roundtablezoo/presentation/diary/cubit/diary_state.dart';
import 'package:roundtablezoo/presentation/diary/widgets/mood_chart.dart';

import '../support/mocks.dart';

/// Cross-cutting check for FR-011/SC-007: the list, the chart and the CSV
/// export must all read `moodScore` and only `moodScore` — never
/// `CharacterReaction.tone`/`intensity`. This isn't exercised by any
/// single unit test elsewhere, since each of the three lives in a
/// different layer (`DiaryDay`, `mood_chart.dart`, `ExportDiaryToCsv`).
void main() {
  MoodScore mood(int value) =>
      MoodScore.create(value).valueOrGet(() => throw StateError('bad fixture'));

  const day = DayKey(year: 2026, month: 3, day: 10);
  final entry = DayEntry(
    id: 1,
    occurredAt: DateTime.utc(2026, 3, 10),
    moodScore: mood(3),
    createdAt: DateTime.utc(2026, 3, 10),
    updatedAt: DateTime.utc(2026, 3, 10),
    dayText: 'ok day',
  );
  final diaryDayEntry = DiaryDayEntry(day: day, entry: entry);

  CharacterReaction reactionWithTone(ReactionTone tone, double intensity) => CharacterReaction(
    dayEntryId: 1,
    characterId: 'cat',
    tone: tone,
    reply: 'meow',
    intensity: intensity,
    isFallback: false,
    createdAt: DateTime.utc(2026, 3, 10, 12),
  );

  test('the list card and the chart point equal the stored moodScore, regardless of reactions', () {
    final diaryDay = DiaryDay(record: diaryDayEntry);
    expect(diaryDay.entry.moodScore.value, 3);

    final point = MoodChartPoint(day: day, moodScore: entry.moodScore);
    final spots = aggregateMoodSeries([point], ChartGranularity.daily);
    expect(spots.single.y, 3);

    // Neither of the two builds above takes a reaction as input at all —
    // the type signatures are the guarantee. Attaching wildly different
    // reactions changes nothing about either value.
    for (final _ in [
      reactionWithTone(ReactionTone.warm, 0.1),
      reactionWithTone(ReactionTone.playful, 0.9),
    ]) {
      expect(diaryDay.entry.moodScore.value, 3);
      expect(point.moodScore.value, 3);
    }
  });

  test(
    "the CSV moodScore column stays 3 no matter the attached reactions' tone/intensity",
    () async {
      final repository = MockDiaryRepository();
      when(
        () => repository.entriesPage(
          beforeOccurredAt: any(named: 'beforeOccurredAt'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer(
        (_) async =>
            Result.success(DiaryPage(days: [diaryDayEntry], hasMore: false, nextCursor: null)),
      );
      when(() => repository.reactionsForEntries([1])).thenAnswer(
        (_) async => Result.success({
          1: [
            reactionWithTone(ReactionTone.warm, 0.1),
            reactionWithTone(ReactionTone.playful, 0.9),
          ],
        }),
      );

      final csv = await ExportDiaryToCsv(repository: repository)();
      final rows = csv.valueOrNull!.split('\r\n')..removeWhere((l) => l.isEmpty);
      // header + 2 reaction rows, both carrying the same moodScore column
      expect(rows, hasLength(3));
      expect(rows[1], startsWith('2026-03-10,3,'));
      expect(rows[2], startsWith('2026-03-10,3,'));
    },
  );
}
