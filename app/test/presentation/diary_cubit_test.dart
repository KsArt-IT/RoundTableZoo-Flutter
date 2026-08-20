import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:roundtablezoo/core/errors/app_failure.dart';
import 'package:roundtablezoo/core/errors/result.dart';
import 'package:roundtablezoo/domain/entities/character.dart';
import 'package:roundtablezoo/domain/entities/character_reaction.dart';
import 'package:roundtablezoo/domain/entities/day_entry.dart';
import 'package:roundtablezoo/domain/entities/day_key.dart';
import 'package:roundtablezoo/domain/entities/diary_day_entry.dart';
import 'package:roundtablezoo/domain/entities/diary_page.dart';
import 'package:roundtablezoo/domain/value_objects/mood_score.dart';
import 'package:roundtablezoo/domain/value_objects/reaction_tone.dart';
import 'package:roundtablezoo/presentation/diary/cubit/diary_cubit.dart';
import 'package:roundtablezoo/presentation/diary/cubit/diary_state.dart';
import 'package:timezone/timezone.dart' as tz;

import '../support/fake_app_clock.dart';
import '../support/mocks.dart';

MoodScore _mood(int value) =>
    MoodScore.create(value).valueOrGet(() => throw StateError('bad fixture'));

DayEntry _entry({int id = 1, int mood = 3, DateTime? occurredAt, String? dayText}) => DayEntry(
  id: id,
  occurredAt: occurredAt ?? DateTime.utc(2026, 3, id),
  moodScore: _mood(mood),
  createdAt: occurredAt ?? DateTime.utc(2026, 3, id),
  updatedAt: occurredAt ?? DateTime.utc(2026, 3, id),
  dayText: dayText,
);

DiaryDayEntry _record({required int day, int id = 1, int mood = 3}) => DiaryDayEntry(
  day: DayKey(year: 2026, month: 3, day: day),
  entry: _entry(id: id, mood: mood, occurredAt: DateTime.utc(2026, 3, day)),
);

CharacterReaction _reaction({
  required int dayEntryId,
  String characterId = 'cat',
  DateTime? createdAt,
}) => CharacterReaction(
  dayEntryId: dayEntryId,
  characterId: characterId,
  tone: ReactionTone.neutral,
  reply: 'hi',
  intensity: 0.5,
  isFallback: false,
  createdAt: createdAt ?? DateTime.utc(2026, 3, 1),
);

void main() {
  late MockDiaryRepository diaryRepository;
  late MockCharacterCatalog characterCatalog;
  late MockExportDiaryToCsv exportDiaryToCsv;
  late MockShareService shareService;
  late FakeAppClock clock;

  setUpAll(() {
    registerFallbackValue(DateTime.utc(2026));
  });

  setUp(() {
    diaryRepository = MockDiaryRepository();
    characterCatalog = MockCharacterCatalog();
    exportDiaryToCsv = MockExportDiaryToCsv();
    shareService = MockShareService();
    clock = FakeAppClock(now: DateTime.utc(2026, 3, 15), location: tz.UTC);
    when(() => diaryRepository.watchEntriesChanged()).thenAnswer((_) => const Stream.empty());
    when(() => diaryRepository.moodHistory()).thenAnswer((_) async => const Result.success([]));
    when(() => characterCatalog.load()).thenAnswer((_) async => const Result.success([]));
    when(
      () => shareService.shareCsv(any(), fileName: any(named: 'fileName')),
    ).thenAnswer((_) async {});
  });

  tearDown(() => clock.dispose());

  DiaryCubit build() => DiaryCubit(
    diaryRepository: diaryRepository,
    characterCatalog: characterCatalog,
    exportDiaryToCsv: exportDiaryToCsv,
    shareService: shareService,
    clock: clock,
  );

  void stubFirstPage(DiaryPage page) => when(
    () => diaryRepository.entriesPage(
      beforeOccurredAt: any(named: 'beforeOccurredAt'),
      limit: any(named: 'limit'),
    ),
  ).thenAnswer((_) async => Result.success(page));

  group('load', () {
    blocTest<DiaryCubit, DiaryState>(
      'a non-empty history loads with newest days first',
      setUp: () => stubFirstPage(
        DiaryPage(
          days: [_record(day: 3), _record(day: 2), _record(day: 1)],
          hasMore: false,
          nextCursor: DateTime.utc(2026, 3, 1),
        ),
      ),
      build: build,
      act: (cubit) => cubit.load(),
      expect: () => [
        const DiaryState.loading(),
        isA<DiaryLoaded>().having(
          (s) => s.data.days.map((d) => d.day.day),
          'days',
          [3, 2, 1],
        ),
      ],
    );

    blocTest<DiaryCubit, DiaryState>(
      'an empty history loads with export disabled',
      setUp: () => stubFirstPage(const DiaryPage(days: [], hasMore: false, nextCursor: null)),
      build: build,
      act: (cubit) => cubit.load(),
      expect: () => [
        const DiaryState.loading(),
        isA<DiaryLoaded>()
            .having((s) => s.data.isEmpty, 'isEmpty', isTrue)
            .having((s) => s.data.hasMore, 'hasMore', isFalse)
            .having((s) => s.data.canExport, 'canExport', isFalse),
      ],
    );

    blocTest<DiaryCubit, DiaryState>(
      'storageReadOnly maps to unavailable, never error',
      setUp: () =>
          when(
            () => diaryRepository.entriesPage(
              beforeOccurredAt: any(named: 'beforeOccurredAt'),
              limit: any(named: 'limit'),
            ),
          ).thenAnswer(
            (_) async =>
                const Result.failure(DatabaseFailure(null, code: DatabaseFailure.storageReadOnly)),
          ),
      build: build,
      act: (cubit) => cubit.load(),
      expect: () => [const DiaryState.loading(), const DiaryState.unavailable()],
    );

    blocTest<DiaryCubit, DiaryState>(
      'any other failure maps to error, and retry() can recover',
      setUp: () {
        var call = 0;
        when(
          () => diaryRepository.entriesPage(
            beforeOccurredAt: any(named: 'beforeOccurredAt'),
            limit: any(named: 'limit'),
          ),
        ).thenAnswer((_) async {
          call += 1;
          if (call == 1) {
            return const Result.failure(DatabaseFailure(null, code: DatabaseFailure.savingError));
          }
          return const Result.success(DiaryPage(days: [], hasMore: false, nextCursor: null));
        });
      },
      build: build,
      act: (cubit) async {
        await cubit.load();
        await cubit.retry();
      },
      expect: () => [
        const DiaryState.loading(),
        isA<DiaryError>(),
        const DiaryState.loading(),
        isA<DiaryLoaded>(),
      ],
    );

    blocTest<DiaryCubit, DiaryState>(
      'a second consecutive failure on retry() stays error, without accumulating state',
      setUp: () =>
          when(
            () => diaryRepository.entriesPage(
              beforeOccurredAt: any(named: 'beforeOccurredAt'),
              limit: any(named: 'limit'),
            ),
          ).thenAnswer(
            (_) async =>
                const Result.failure(DatabaseFailure(null, code: DatabaseFailure.savingError)),
          ),
      build: build,
      act: (cubit) async {
        await cubit.load();
        await cubit.retry();
      },
      expect: () => [
        const DiaryState.loading(),
        isA<DiaryError>(),
        const DiaryState.loading(),
        isA<DiaryError>(),
      ],
    );

    blocTest<DiaryCubit, DiaryState>(
      'nothing is emitted once the cubit is closed mid-load',
      setUp: () =>
          when(
            () => diaryRepository.entriesPage(
              beforeOccurredAt: any(named: 'beforeOccurredAt'),
              limit: any(named: 'limit'),
            ),
          ).thenAnswer((_) async {
            await Future<void>.delayed(const Duration(milliseconds: 20));
            return const Result.success(DiaryPage(days: [], hasMore: false, nextCursor: null));
          }),
      build: build,
      act: (cubit) async {
        final future = cubit.load();
        await cubit.close();
        await future;
      },
      expect: () => [const DiaryState.loading()],
    );
  });

  group('loadMore', () {
    blocTest<DiaryCubit, DiaryState>(
      'appends the next page without losing or duplicating days',
      setUp: () {
        var call = 0;
        when(
          () => diaryRepository.entriesPage(
            beforeOccurredAt: any(named: 'beforeOccurredAt'),
            limit: any(named: 'limit'),
          ),
        ).thenAnswer((_) async {
          call += 1;
          if (call == 1) {
            return Result.success(
              DiaryPage(
                days: [_record(day: 3)],
                hasMore: true,
                nextCursor: DateTime.utc(2026, 3, 3),
              ),
            );
          }
          return Result.success(
            DiaryPage(
              days: [_record(day: 2)],
              hasMore: false,
              nextCursor: DateTime.utc(2026, 3, 2),
            ),
          );
        });
      },
      build: build,
      act: (cubit) async {
        await cubit.load();
        await cubit.loadMore();
      },
      skip: 3,
      expect: () => [
        isA<DiaryLoaded>()
            .having((s) => s.data.days.map((d) => d.day.day), 'days', [3, 2])
            .having((s) => s.data.hasMore, 'hasMore', isFalse)
            .having((s) => s.data.loadingMore, 'loadingMore', isFalse),
      ],
    );

    blocTest<DiaryCubit, DiaryState>(
      'two loadMore() calls without awaiting the first only send one request',
      setUp: () => stubFirstPage(
        DiaryPage(days: [_record(day: 3)], hasMore: true, nextCursor: DateTime.utc(2026, 3, 3)),
      ),
      build: build,
      act: (cubit) async {
        await cubit.load();
        unawaited(cubit.loadMore());
        await cubit.loadMore();
      },
      verify: (_) {
        verify(
          () => diaryRepository.entriesPage(
            beforeOccurredAt: any(named: 'beforeOccurredAt'),
            limit: any(named: 'limit'),
          ),
        ).called(2); // load()'s first page + exactly one loadMore() call
      },
    );

    blocTest<DiaryCubit, DiaryState>(
      'hasMore: false means loadMore() never calls the repository again',
      setUp: () => stubFirstPage(const DiaryPage(days: [], hasMore: false, nextCursor: null)),
      build: build,
      act: (cubit) async {
        await cubit.load();
        await cubit.loadMore();
      },
      verify: (_) {
        verify(
          () => diaryRepository.entriesPage(
            beforeOccurredAt: any(named: 'beforeOccurredAt'),
            limit: any(named: 'limit'),
          ),
        ).called(1); // only load()'s first page
      },
    );

    blocTest<DiaryCubit, DiaryState>(
      'a loadMore() failure keeps the already-shown days and sets pageFailure',
      setUp: () {
        var call = 0;
        when(
          () => diaryRepository.entriesPage(
            beforeOccurredAt: any(named: 'beforeOccurredAt'),
            limit: any(named: 'limit'),
          ),
        ).thenAnswer((_) async {
          call += 1;
          if (call == 1) {
            return Result.success(
              DiaryPage(
                days: [_record(day: 3)],
                hasMore: true,
                nextCursor: DateTime.utc(2026, 3, 3),
              ),
            );
          }
          return const Result.failure(DatabaseFailure(null, code: DatabaseFailure.savingError));
        });
      },
      build: build,
      act: (cubit) async {
        await cubit.load();
        await cubit.loadMore();
      },
      skip: 3,
      expect: () => [
        isA<DiaryLoaded>()
            .having((s) => s.data.days.map((d) => d.day.day), 'days', [3])
            .having((s) => s.data.pageFailure, 'pageFailure', isNotNull)
            .having((s) => s.data.loadingMore, 'loadingMore', isFalse),
      ],
    );

    blocTest<DiaryCubit, DiaryState>(
      'a page whose day is already shown is not duplicated (defense-in-depth dedup)',
      setUp: () {
        var call = 0;
        when(
          () => diaryRepository.entriesPage(
            beforeOccurredAt: any(named: 'beforeOccurredAt'),
            limit: any(named: 'limit'),
          ),
        ).thenAnswer((_) async {
          call += 1;
          if (call == 1) {
            return Result.success(
              DiaryPage(
                days: [_record(day: 3)],
                hasMore: true,
                nextCursor: DateTime.utc(2026, 3, 3),
              ),
            );
          }
          // Same DayKey as page 1 — must not appear twice in the merged list.
          return Result.success(
            DiaryPage(days: [_record(day: 3, id: 99)], hasMore: false, nextCursor: null),
          );
        });
      },
      build: build,
      act: (cubit) async {
        await cubit.load();
        await cubit.loadMore();
      },
      skip: 3,
      expect: () => [
        isA<DiaryLoaded>().having((s) => s.data.days.map((d) => d.day.day), 'days', [3]),
      ],
    );
  });

  group('watchEntriesChanged', () {
    late StreamController<void> entriesChanged;

    setUp(() {
      entriesChanged = StreamController<void>.broadcast();
      when(() => diaryRepository.watchEntriesChanged()).thenAnswer((_) => entriesChanged.stream);
    });

    tearDown(() => entriesChanged.close());

    blocTest<DiaryCubit, DiaryState>(
      'a debounced signal re-reads only the first page, keeping already-loaded pages',
      setUp: () {
        var call = 0;
        when(
          () => diaryRepository.entriesPage(
            beforeOccurredAt: any(named: 'beforeOccurredAt'),
            limit: any(named: 'limit'),
          ),
        ).thenAnswer((_) async {
          call += 1;
          if (call == 1) {
            return Result.success(
              DiaryPage(
                days: [_record(day: 3)],
                hasMore: true,
                nextCursor: DateTime.utc(2026, 3, 3),
              ),
            );
          }
          if (call == 2) {
            return Result.success(
              DiaryPage(
                days: [_record(day: 2)],
                hasMore: false,
                nextCursor: DateTime.utc(2026, 3, 2),
              ),
            );
          }
          // Debounced re-read of the head after loadMore().
          return Result.success(
            DiaryPage(
              days: [_record(day: 3, mood: 5)],
              hasMore: true,
              nextCursor: DateTime.utc(2026, 3, 3),
            ),
          );
        });
      },
      build: build,
      act: (cubit) async {
        await cubit.load();
        await cubit.loadMore();
        entriesChanged.add(null);
        await Future<void>.delayed(const Duration(milliseconds: 400));
      },
      skip: 4,
      expect: () => [
        isA<DiaryLoaded>()
            .having((s) => s.data.days.map((d) => d.day.day), 'days', [3, 2])
            .having((s) => s.data.days.first.entry.moodScore.value, 'refreshed mood', 5),
      ],
    );

    blocTest<DiaryCubit, DiaryState>(
      'a debounced signal does not collapse already-expanded days',
      setUp: () {
        stubFirstPage(
          DiaryPage(days: [_record(day: 3, id: 1)], hasMore: false, nextCursor: null),
        );
        when(
          () => diaryRepository.reactionsFor(1),
        ).thenAnswer((_) async => const Result.success(<CharacterReaction>[]));
      },
      build: build,
      act: (cubit) async {
        await cubit.load();
        await cubit.toggleDay(1);
        entriesChanged.add(null);
        await Future<void>.delayed(const Duration(milliseconds: 400));
      },
      skip: 4,
      expect: () => [
        isA<DiaryLoaded>().having((s) => s.data.days.single.expanded, 'expanded', isTrue),
      ],
    );
  });

  group('toggleDay', () {
    blocTest<DiaryCubit, DiaryState>(
      'loads reactions once on first expansion; a second toggle round-trip does not refetch',
      setUp: () {
        stubFirstPage(DiaryPage(days: [_record(day: 3, id: 1)], hasMore: false, nextCursor: null));
        when(() => diaryRepository.reactionsFor(1)).thenAnswer(
          (_) async => Result.success([_reaction(dayEntryId: 1)]),
        );
      },
      build: build,
      act: (cubit) async {
        await cubit.load();
        await cubit.toggleDay(1); // expand — fetches
        await cubit.toggleDay(1); // collapse
        await cubit.toggleDay(1); // expand again — cached
      },
      verify: (_) {
        verify(() => diaryRepository.reactionsFor(1)).called(1);
      },
    );

    blocTest<DiaryCubit, DiaryState>(
      'two different days can be expanded at the same time (FR-014)',
      setUp: () {
        stubFirstPage(
          DiaryPage(
            days: [_record(day: 3, id: 1), _record(day: 2, id: 2)],
            hasMore: false,
            nextCursor: null,
          ),
        );
        when(
          () => diaryRepository.reactionsFor(any()),
        ).thenAnswer((_) async => const Result.success(<CharacterReaction>[]));
      },
      build: build,
      act: (cubit) async {
        await cubit.load();
        await cubit.toggleDay(1);
        await cubit.toggleDay(2);
      },
      verify: (cubit) {
        final data = (cubit.state as DiaryLoaded).data;
        expect(data.days.every((d) => d.expanded), isTrue);
      },
    );

    blocTest<DiaryCubit, DiaryState>(
      'a day with no saved reactions gets an empty list, not null (FR-018)',
      setUp: () {
        stubFirstPage(DiaryPage(days: [_record(day: 3, id: 1)], hasMore: false, nextCursor: null));
        when(
          () => diaryRepository.reactionsFor(1),
        ).thenAnswer((_) async => const Result.success(<CharacterReaction>[]));
      },
      build: build,
      act: (cubit) async {
        await cubit.load();
        await cubit.toggleDay(1);
      },
      verify: (cubit) {
        final data = (cubit.state as DiaryLoaded).data;
        expect(data.days.single.reactions, isEmpty);
        expect(data.days.single.reactions, isNotNull);
      },
    );

    blocTest<DiaryCubit, DiaryState>(
      'a reaction-fetch failure does not break the screen state',
      setUp: () {
        stubFirstPage(DiaryPage(days: [_record(day: 3, id: 1)], hasMore: false, nextCursor: null));
        when(() => diaryRepository.reactionsFor(1)).thenAnswer(
          (_) async =>
              const Result.failure(DatabaseFailure(null, code: DatabaseFailure.savingError)),
        );
      },
      build: build,
      act: (cubit) async {
        await cubit.load();
        await cubit.toggleDay(1);
      },
      verify: (cubit) {
        expect(cubit.state, isA<DiaryLoaded>());
      },
    );

    test('a reaction-fetch failure is published on failures, not swallowed', () async {
      stubFirstPage(DiaryPage(days: [_record(day: 3, id: 1)], hasMore: false, nextCursor: null));
      when(() => diaryRepository.reactionsFor(1)).thenAnswer(
        (_) async => const Result.failure(DatabaseFailure(null, code: DatabaseFailure.savingError)),
      );

      final cubit = build();
      await cubit.load();
      final failureFuture = cubit.failures.first;
      await cubit.toggleDay(1);

      expect(await failureFuture, isA<DatabaseFailure>());
      await cubit.close();
    });
  });

  group('export', () {
    blocTest<DiaryCubit, DiaryState>(
      'an empty history never calls ShareService',
      setUp: () => stubFirstPage(const DiaryPage(days: [], hasMore: false, nextCursor: null)),
      build: build,
      act: (cubit) async {
        await cubit.load();
        await cubit.export();
      },
      verify: (_) {
        verifyNever(() => shareService.shareCsv(any(), fileName: any(named: 'fileName')));
        verifyNever(() => exportDiaryToCsv());
      },
    );

    blocTest<DiaryCubit, DiaryState>(
      'a successful export shares the CSV once and clears exporting',
      setUp: () {
        stubFirstPage(
          DiaryPage(days: [_record(day: 3)], hasMore: false, nextCursor: null),
        );
        when(() => exportDiaryToCsv()).thenAnswer((_) async => const Result.success('csv'));
      },
      build: build,
      act: (cubit) async {
        await cubit.load();
        await cubit.export();
      },
      skip: 2,
      expect: () => [
        isA<DiaryLoaded>().having((s) => s.data.exporting, 'exporting', isTrue),
        isA<DiaryLoaded>().having((s) => s.data.exporting, 'exporting', isFalse),
      ],
      verify: (_) {
        verify(
          () => shareService.shareCsv('csv', fileName: 'roundtablezoo-2026-03-15.csv'),
        ).called(1);
      },
    );

    blocTest<DiaryCubit, DiaryState>(
      'a usecase failure publishes to failures and keeps the screen loaded',
      setUp: () {
        stubFirstPage(
          DiaryPage(days: [_record(day: 3)], hasMore: false, nextCursor: null),
        );
        when(() => exportDiaryToCsv()).thenAnswer(
          (_) async =>
              const Result.failure(DatabaseFailure(null, code: DatabaseFailure.savingError)),
        );
      },
      build: build,
      act: (cubit) async {
        await cubit.load();
        await cubit.export();
      },
      verify: (cubit) {
        expect(cubit.state, isA<DiaryLoaded>());
        verifyNever(() => shareService.shareCsv(any(), fileName: any(named: 'fileName')));
      },
    );

    test('a usecase failure is published on failures', () async {
      stubFirstPage(DiaryPage(days: [_record(day: 3)], hasMore: false, nextCursor: null));
      when(() => exportDiaryToCsv()).thenAnswer(
        (_) async => const Result.failure(DatabaseFailure(null, code: DatabaseFailure.savingError)),
      );

      final cubit = build();
      await cubit.load();
      final failureFuture = cubit.failures.first;
      await cubit.export();

      expect(await failureFuture, isA<DatabaseFailure>());
      await cubit.close();
    });
  });
}
