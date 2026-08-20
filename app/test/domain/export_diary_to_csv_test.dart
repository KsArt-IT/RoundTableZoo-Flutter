import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:roundtablezoo/core/errors/app_failure.dart';
import 'package:roundtablezoo/core/errors/result.dart';
import 'package:roundtablezoo/domain/entities/character_reaction.dart';
import 'package:roundtablezoo/domain/entities/day_entry.dart';
import 'package:roundtablezoo/domain/entities/day_key.dart';
import 'package:roundtablezoo/domain/entities/diary_day_entry.dart';
import 'package:roundtablezoo/domain/entities/diary_page.dart';
import 'package:roundtablezoo/domain/usecases/export_diary_to_csv.dart';
import 'package:roundtablezoo/domain/value_objects/mood_score.dart';
import 'package:roundtablezoo/domain/value_objects/reaction_tone.dart';

import '../support/mocks.dart';

MoodScore _mood(int value) =>
    MoodScore.create(value).valueOrGet(() => throw StateError('bad fixture'));

DiaryDayEntry _record({required int day, int id = 1, int mood = 3, String? dayText}) =>
    DiaryDayEntry(
      day: DayKey(year: 2026, month: 1, day: day),
      entry: DayEntry(
        id: id,
        occurredAt: DateTime.utc(2026, 1, day),
        moodScore: _mood(mood),
        createdAt: DateTime.utc(2026, 1, day),
        updatedAt: DateTime.utc(2026, 1, day),
        dayText: dayText,
      ),
    );

CharacterReaction _reaction({
  required int dayEntryId,
  String characterId = 'cat',
  String reply = 'hi',
  DateTime? createdAt,
}) => CharacterReaction(
  dayEntryId: dayEntryId,
  characterId: characterId,
  tone: ReactionTone.neutral,
  reply: reply,
  intensity: 0.5,
  isFallback: false,
  createdAt: createdAt ?? DateTime.utc(2026, 1, 1),
);

void main() {
  late MockDiaryRepository repository;
  late ExportDiaryToCsv usecase;

  setUpAll(() {
    registerFallbackValue(DateTime.utc(2026));
    registerFallbackValue(<int>[]);
  });

  setUp(() {
    repository = MockDiaryRepository();
    usecase = ExportDiaryToCsv(repository: repository);
  });

  void stubPage(DiaryPage page, {DateTime? beforeOccurredAt}) => when(
    () => repository.entriesPage(
      beforeOccurredAt: beforeOccurredAt,
      limit: any(named: 'limit'),
    ),
  ).thenAnswer((_) async => Result.success(page));

  void stubReactions(Map<int, List<CharacterReaction>> reactions) => when(
    () => repository.reactionsForEntries(any()),
  ).thenAnswer((_) async => Result.success(reactions));

  test('the file starts with the header row, then one row with empty trailing fields', () async {
    stubPage(
      DiaryPage(days: [_record(day: 1, id: 1, mood: 3)], hasMore: false, nextCursor: null),
    );
    stubReactions(const {});

    final result = await usecase();
    expect(result.isSuccess, isTrue);
    final lines = result.valueOrNull!.split('\r\n')..removeWhere((l) => l.isEmpty);
    expect(lines.first, 'date,moodScore,dayText,characterId,characterReply');
    expect(lines[1], '2026-01-01,3,,,');
  });

  test('date comes from DiaryDayEntry.day, not the raw occurredAt', () async {
    stubPage(
      DiaryPage(days: [_record(day: 15, id: 1)], hasMore: false, nextCursor: null),
    );
    stubReactions(const {});

    final result = await usecase();
    expect(result.valueOrNull, contains('2026-01-15,'));
  });

  test('a day with N reactions produces N rows, all sharing the same day fields', () async {
    stubPage(
      DiaryPage(
        days: [_record(day: 1, id: 1, mood: 4, dayText: 'hi')],
        hasMore: false,
        nextCursor: null,
      ),
    );
    stubReactions({
      1: [
        _reaction(dayEntryId: 1, characterId: 'cat', reply: 'meow'),
        _reaction(dayEntryId: 1, characterId: 'dog', reply: 'woof'),
      ],
    });

    final result = await usecase();
    final lines = result.valueOrNull!.split('\r\n')..removeWhere((l) => l.isEmpty);
    expect(lines, hasLength(3)); // header + 2 rows
    expect(lines[1], '2026-01-01,4,hi,cat,meow');
    expect(lines[2], '2026-01-01,4,hi,dog,woof');
  });

  test('dayText == null serializes as an empty field, not the text "null"', () async {
    stubPage(
      DiaryPage(days: [_record(day: 1, id: 1)], hasMore: false, nextCursor: null),
    );
    stubReactions(const {});

    final result = await usecase();
    expect(result.valueOrNull, isNot(contains('null')));
  });

  group('escaping', () {
    test('a field with a comma is quoted', () async {
      stubPage(
        DiaryPage(
          days: [_record(day: 1, id: 1, dayText: 'a, b')],
          hasMore: false,
          nextCursor: null,
        ),
      );
      stubReactions(const {});
      final result = await usecase();
      expect(result.valueOrNull, contains('"a, b"'));
    });

    test('a field with a double quote is quoted and the quote is doubled', () async {
      stubPage(
        DiaryPage(
          days: [_record(day: 1, id: 1, dayText: 'she said "hi"')],
          hasMore: false,
          nextCursor: null,
        ),
      );
      stubReactions(const {});
      final result = await usecase();
      expect(result.valueOrNull, contains('"she said ""hi"""'));
    });

    test('a field with an embedded newline is quoted', () async {
      stubPage(
        DiaryPage(
          days: [_record(day: 1, id: 1, dayText: 'line one\nline two')],
          hasMore: false,
          nextCursor: null,
        ),
      );
      stubReactions(const {});
      final result = await usecase();
      expect(result.valueOrNull, contains('"line one\nline two"'));
    });
  });

  test('an empty history is a ValidationFailure', () async {
    stubPage(const DiaryPage(days: [], hasMore: false, nextCursor: null));

    final result = await usecase();
    expect(result.isFailure, isTrue);
    expect(result.errorOrNull, isA<ValidationFailure>());
  });

  test('walks every page via nextCursor until hasMore is false', () async {
    stubPage(
      DiaryPage(
        days: [_record(day: 2, id: 2)],
        hasMore: true,
        nextCursor: DateTime.utc(2026, 1, 2),
      ),
    );
    stubPage(
      DiaryPage(days: [_record(day: 1, id: 1)], hasMore: false, nextCursor: null),
      beforeOccurredAt: DateTime.utc(2026, 1, 2),
    );
    stubReactions(const {});

    final result = await usecase();
    expect(result.isSuccess, isTrue);
    final lines = result.valueOrNull!.split('\r\n')..removeWhere((l) => l.isEmpty);
    expect(lines, hasLength(3)); // header + 2 days across 2 pages
    verify(
      () => repository.entriesPage(
        beforeOccurredAt: any(named: 'beforeOccurredAt'),
        limit: any(named: 'limit'),
      ),
    ).called(2);
  });

  test('a page failure aborts the export with that failure', () async {
    when(
      () => repository.entriesPage(
        beforeOccurredAt: any(named: 'beforeOccurredAt'),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer(
      (_) async => const Result.failure(DatabaseFailure(null, code: DatabaseFailure.savingError)),
    );

    final result = await usecase();
    expect(result.isFailure, isTrue);
    expect(result.errorOrNull, isA<DatabaseFailure>());
  });
}
