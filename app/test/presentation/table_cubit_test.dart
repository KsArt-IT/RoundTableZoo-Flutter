import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:roundtablezoo/core/bootstrap/storage_mode.dart';
import 'package:roundtablezoo/core/errors/app_failure.dart';
import 'package:roundtablezoo/core/errors/result.dart';
import 'package:roundtablezoo/domain/entities/day_entry.dart';
import 'package:roundtablezoo/domain/entities/day_key.dart';
import 'package:roundtablezoo/domain/value_objects/mood_score.dart';
import 'package:roundtablezoo/presentation/table/cubit/table_cubit.dart';
import 'package:roundtablezoo/presentation/table/cubit/table_state.dart';

import '../support/mocks.dart';

const _dayKey = DayKey(year: 2026, month: 3, day: 10);

MoodScore _mood(int value) => MoodScore.create(value).valueOrGet(() => throw StateError('bad fixture'));

DayEntry _entry({int id = 1, int mood = 3, String? dayText}) => DayEntry(
  id: id,
  occurredAt: DateTime.utc(2026, 3, 10, 12),
  moodScore: _mood(mood),
  createdAt: DateTime.utc(2026, 3, 10, 12),
  updatedAt: DateTime.utc(2026, 3, 10, 12),
  dayText: dayText,
);

void main() {
  late MockDiaryRepository diaryRepository;

  setUpAll(() {
    registerFallbackValue(_mood(3));
  });

  setUp(() {
    diaryRepository = MockDiaryRepository();
  });

  TableCubit build({StorageMode storageMode = StorageMode.persistent}) =>
      TableCubit(diaryRepository: diaryRepository, storageMode: storageMode);

  group('load', () {
    blocTest<TableCubit, TableState>(
      'an empty day loads with no mood and no entry',
      setUp: () => when(
        () => diaryRepository.entryForDay(_dayKey),
      ).thenAnswer((_) async => const Result.success(null)),
      build: build,
      act: (cubit) => cubit.load(_dayKey),
      expect: () => [
        const TableState.loading(),
        isA<TableLoaded>()
            .having((s) => s.data.moodScore, 'moodScore', isNull)
            .having((s) => s.data.entryId, 'entryId', isNull)
            .having((s) => s.data.dayText, 'dayText', ''),
      ],
    );

    blocTest<TableCubit, TableState>(
      'an existing entry restores mood, id and text',
      setUp: () => when(
        () => diaryRepository.entryForDay(_dayKey),
      ).thenAnswer((_) async => Result.success(_entry(dayText: 'hello'))),
      build: build,
      act: (cubit) => cubit.load(_dayKey),
      expect: () => [
        const TableState.loading(),
        isA<TableLoaded>()
            .having((s) => s.data.moodScore?.value, 'moodScore', 3)
            .having((s) => s.data.entryId, 'entryId', 1)
            .having((s) => s.data.dayText, 'dayText', 'hello'),
      ],
    );

    blocTest<TableCubit, TableState>(
      'a repository failure surfaces as an error state',
      setUp: () => when(() => diaryRepository.entryForDay(_dayKey)).thenAnswer(
        (_) async => const Result.failure(DatabaseFailure(null, code: 'boom')),
      ),
      build: build,
      act: (cubit) => cubit.load(_dayKey),
      expect: () => [const TableState.loading(), isA<TableError>()],
    );
  });

  group('setMood', () {
    blocTest<TableCubit, TableState>(
      'creates a new entry on an empty day',
      setUp: () {
        when(
          () => diaryRepository.entryForDay(_dayKey),
        ).thenAnswer((_) async => const Result.success(null));
        when(
          () => diaryRepository.saveTodayEntry(
            moodScore: any(named: 'moodScore'),
            dayText: any(named: 'dayText'),
          ),
        ).thenAnswer((_) async => Result.success(_entry(id: 5)));
      },
      build: build,
      act: (cubit) async {
        await cubit.load(_dayKey);
        await cubit.setMood(_mood(3));
      },
      skip: 2,
      expect: () => [
        isA<TableLoaded>()
            .having((s) => s.data.entryId, 'entryId', 5)
            .having((s) => s.data.moodScore?.value, 'moodScore', 3),
      ],
      verify: (_) {
        verify(() => diaryRepository.saveTodayEntry(moodScore: any(named: 'moodScore'))).called(1);
      },
    );

    blocTest<TableCubit, TableState>(
      'updates an existing entry, keeping its saved day text',
      setUp: () {
        when(() => diaryRepository.entryForDay(_dayKey)).thenAnswer(
          (_) async => Result.success(_entry(id: 5, mood: 2, dayText: 'yesterday-ish')),
        );
        when(
          () => diaryRepository.saveTodayEntry(
            moodScore: any(named: 'moodScore'),
            dayText: any(named: 'dayText'),
          ),
        ).thenAnswer((_) async => Result.success(_entry(id: 5, mood: 4, dayText: 'yesterday-ish')));
      },
      build: build,
      act: (cubit) async {
        await cubit.load(_dayKey);
        await cubit.setMood(_mood(4));
      },
      skip: 2,
      expect: () => [
        isA<TableLoaded>()
            .having((s) => s.data.moodScore?.value, 'moodScore', 4)
            .having((s) => s.data.dayText, 'dayText', 'yesterday-ish'),
      ],
      verify: (_) {
        verify(
          () => diaryRepository.saveTodayEntry(
            moodScore: any(named: 'moodScore'),
            dayText: 'yesterday-ish',
          ),
        ).called(1);
      },
    );

    blocTest<TableCubit, TableState>(
      'read-only mode never calls the repository and never emits',
      setUp: () => when(
        () => diaryRepository.entryForDay(_dayKey),
      ).thenAnswer((_) async => const Result.success(null)),
      build: () => build(storageMode: StorageMode.readOnly),
      act: (cubit) async {
        await cubit.load(_dayKey);
        await cubit.setMood(_mood(3));
      },
      skip: 2,
      expect: () => <TableState>[],
      verify: (_) {
        verifyNever(
          () => diaryRepository.saveTodayEntry(
            moodScore: any(named: 'moodScore'),
            dayText: any(named: 'dayText'),
          ),
        );
      },
    );

    test('a saveTodayEntry failure surfaces via failures, state unchanged', () async {
      when(
        () => diaryRepository.entryForDay(_dayKey),
      ).thenAnswer((_) async => const Result.success(null));
      when(
        () => diaryRepository.saveTodayEntry(
          moodScore: any(named: 'moodScore'),
          dayText: any(named: 'dayText'),
        ),
      ).thenAnswer((_) async => const Result.failure(DatabaseFailure(null, code: 'boom')));

      final cubit = build();
      await cubit.load(_dayKey);
      final stateBefore = cubit.state;
      final failureFuture = cubit.failures.first;

      await cubit.setMood(_mood(3));

      expect(await failureFuture, isA<DatabaseFailure>());
      expect(cubit.state, stateBefore);
      await cubit.close();
    });
  });
}
