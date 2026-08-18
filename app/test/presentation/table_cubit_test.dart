import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:roundtablezoo/core/bootstrap/storage_mode.dart';
import 'package:roundtablezoo/core/constants/app_constants.dart';
import 'package:roundtablezoo/core/errors/app_failure.dart';
import 'package:roundtablezoo/core/errors/result.dart';
import 'package:roundtablezoo/domain/entities/character.dart';
import 'package:roundtablezoo/domain/entities/character_reaction.dart';
import 'package:roundtablezoo/domain/entities/day_entry.dart';
import 'package:roundtablezoo/domain/entities/day_key.dart';
import 'package:roundtablezoo/domain/entities/user_settings.dart';
import 'package:roundtablezoo/domain/value_objects/day_start_hour.dart';
import 'package:roundtablezoo/domain/value_objects/locale_preference.dart';
import 'package:roundtablezoo/domain/value_objects/mood_score.dart';
import 'package:roundtablezoo/domain/value_objects/reaction_tone.dart';
import 'package:roundtablezoo/domain/value_objects/reminder_time.dart';
import 'package:roundtablezoo/domain/value_objects/theme_preference.dart';
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

UserSettings _settings({List<String> enabled = const ['cat', 'dog']}) => UserSettings(
  installId: 'test-install',
  themeMode: ThemePreference.system,
  locale: LocalePreference.system,
  soundEnabled: true,
  enabledCharacterIds: enabled,
  hasSeenOnboarding: true,
  reminderEnabled: false,
  reminderTime: ReminderTime.defaultValue,
  dayStartHour: DayStartHour.defaultValue,
);

Character _character(String id, {String fallbackReply = 'fallback'}) => Character(
  id: id,
  name: id,
  colorHex: 0xFF000000,
  fallbackReply: fallbackReply,
  maxReplyLength: 200,
);

const _characters = [Character(id: 'cat', name: 'cat', colorHex: 0xFF000000, fallbackReply: 'Мяу', maxReplyLength: 200)];

CharacterReaction _reaction({int? id, String characterId = 'cat', bool isFallback = false}) => CharacterReaction(
  id: id,
  dayEntryId: 1,
  characterId: characterId,
  tone: ReactionTone.neutral,
  reply: 'hello',
  intensity: 0.5,
  isFallback: isFallback,
  createdAt: DateTime.utc(2026, 3, 10, 12),
);

void main() {
  late MockDiaryRepository diaryRepository;
  late MockSettingsRepository settingsRepository;
  late MockAiReactionRepository aiReactionRepository;
  late MockCharacterCatalog characterCatalog;
  late MockAppClock clock;

  setUpAll(() {
    registerFallbackValue(_mood(3));
    registerFallbackValue(_reaction());
  });

  setUp(() {
    diaryRepository = MockDiaryRepository();
    settingsRepository = MockSettingsRepository();
    aiReactionRepository = MockAiReactionRepository();
    characterCatalog = MockCharacterCatalog();
    clock = MockAppClock();

    when(() => clock.nowUtc()).thenReturn(DateTime.utc(2026, 3, 10, 12));
    when(() => settingsRepository.watch()).thenAnswer((_) => const Stream.empty());
    when(() => settingsRepository.load()).thenAnswer((_) async => Result.success(_settings()));
    when(() => characterCatalog.load()).thenAnswer((_) async => const Result.success(_characters));
  });

  TableCubit build({StorageMode storageMode = StorageMode.persistent}) => TableCubit(
    diaryRepository: diaryRepository,
    settingsRepository: settingsRepository,
    aiReactionRepository: aiReactionRepository,
    characterCatalog: characterCatalog,
    clock: clock,
    storageMode: storageMode,
  );

  group('load', () {
    blocTest<TableCubit, TableState>(
      'an empty day loads with no mood, no entry, and idle slots for enabled characters',
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
            .having((s) => s.data.dayText, 'dayText', '')
            .having((s) => s.data.characters.map((c) => c.id), 'characters', ['cat'])
            .having((s) => s.data.slots['cat'], 'slots[cat]', const CharacterSlot.idle()),
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

    blocTest<TableCubit, TableState>(
      'a broken character catalog degrades to an empty table, not a screen error (FR-010d)',
      setUp: () {
        when(() => diaryRepository.entryForDay(_dayKey)).thenAnswer((_) async => const Result.success(null));
        when(
          () => characterCatalog.load(),
        ).thenAnswer((_) async => const Result.failure(SerializationFailure('bad json')));
      },
      build: build,
      act: (cubit) => cubit.load(_dayKey),
      expect: () => [
        const TableState.loading(),
        isA<TableLoaded>().having((s) => s.data.characters, 'characters', isEmpty),
      ],
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

    test('text typed before a mood is picked is carried by the first setMood (FR-008c)', () async {
      when(
        () => diaryRepository.entryForDay(_dayKey),
      ).thenAnswer((_) async => const Result.success(null));
      when(
        () => diaryRepository.saveTodayEntry(
          moodScore: any(named: 'moodScore'),
          dayText: any(named: 'dayText'),
        ),
      ).thenAnswer((_) async => Result.success(_entry(id: 7, dayText: 'typed early')));

      final cubit = build();
      await cubit.load(_dayKey);
      cubit.onDayTextChanged('typed early');
      await cubit.setMood(_mood(3));

      verify(
        () => diaryRepository.saveTodayEntry(moodScore: any(named: 'moodScore'), dayText: 'typed early'),
      ).called(1);
      await cubit.close();
    });
  });

  group('day text autosave (research.md R10)', () {
    test('debounces a burst of edits into a single save', () {
      when(
        () => diaryRepository.entryForDay(_dayKey),
      ).thenAnswer((_) async => Result.success(_entry(id: 1, mood: 3)));
      when(
        () => diaryRepository.saveTodayEntry(
          moodScore: any(named: 'moodScore'),
          dayText: any(named: 'dayText'),
        ),
      ).thenAnswer((_) async => Result.success(_entry(dayText: 'abc')));

      fakeAsync((async) {
        final cubit = build();
        unawaited(cubit.load(_dayKey));
        async.flushMicrotasks();

        cubit.onDayTextChanged('a');
        cubit.onDayTextChanged('ab');
        cubit.onDayTextChanged('abc');
        async.elapse(AppConstants.dayTextAutosaveDebounce);

        verify(
          () => diaryRepository.saveTodayEntry(moodScore: any(named: 'moodScore'), dayText: 'abc'),
        ).called(1);

        unawaited(cubit.close());
        async.flushMicrotasks();
      });
    });

    test('close() flushes an unsaved edit', () async {
      when(
        () => diaryRepository.entryForDay(_dayKey),
      ).thenAnswer((_) async => Result.success(_entry(id: 1, mood: 3)));
      when(
        () => diaryRepository.saveTodayEntry(
          moodScore: any(named: 'moodScore'),
          dayText: any(named: 'dayText'),
        ),
      ).thenAnswer((_) async => Result.success(_entry(dayText: 'unsaved')));

      final cubit = build();
      await cubit.load(_dayKey);
      cubit.onDayTextChanged('unsaved');
      await cubit.close();

      verify(
        () => diaryRepository.saveTodayEntry(moodScore: any(named: 'moodScore'), dayText: 'unsaved'),
      ).called(1);
    });

    test('flushDayText() (called by TablePage on AppLifecycleState.paused) saves immediately', () async {
      when(
        () => diaryRepository.entryForDay(_dayKey),
      ).thenAnswer((_) async => Result.success(_entry(id: 1, mood: 3)));
      when(
        () => diaryRepository.saveTodayEntry(
          moodScore: any(named: 'moodScore'),
          dayText: any(named: 'dayText'),
        ),
      ).thenAnswer((_) async => Result.success(_entry(dayText: 'paused-save')));

      final cubit = build();
      await cubit.load(_dayKey);
      cubit.onDayTextChanged('paused-save');
      await cubit.flushDayText();

      verify(
        () => diaryRepository.saveTodayEntry(moodScore: any(named: 'moodScore'), dayText: 'paused-save'),
      ).called(1);
      await cubit.close();
    });
  });

  group('requestReaction', () {
    setUp(() {
      when(
        () => diaryRepository.entryForDay(_dayKey),
      ).thenAnswer((_) async => Result.success(_entry(dayText: 'today was fine')));
    });

    test('a successful response is persisted and shown in the slot', () async {
      when(
        () => aiReactionRepository.requestReaction(
          characterId: 'cat',
          dayText: 'today was fine',
          dayEntryId: 1,
        ),
      ).thenAnswer((_) async => Result.success(_reaction(id: 9)));
      when(() => diaryRepository.addReaction(any())).thenAnswer((_) async => Result.success(_reaction(id: 9)));

      final cubit = build();
      await cubit.load(_dayKey);
      await cubit.requestReaction('cat');

      final state = cubit.state as TableLoaded;
      final slot = state.data.slots['cat'];
      expect(slot, isA<CharacterSlotSpoken>());
      expect((slot! as CharacterSlotSpoken).reaction.id, 9);
      verify(() => diaryRepository.addReaction(any())).called(1);
      await cubit.close();
    });

    test('addReaction failing still shows the reply, marked persistFailed (FR-021c)', () async {
      when(
        () => aiReactionRepository.requestReaction(
          characterId: 'cat',
          dayText: 'today was fine',
          dayEntryId: 1,
        ),
      ).thenAnswer((_) async => Result.success(_reaction()));
      when(
        () => diaryRepository.addReaction(any()),
      ).thenAnswer((_) async => const Result.failure(DatabaseFailure(null, code: 'boom')));

      final cubit = build();
      await cubit.load(_dayKey);
      final failureFuture = cubit.failures.first;
      await cubit.requestReaction('cat');

      final state = cubit.state as TableLoaded;
      final slot = state.data.slots['cat']! as CharacterSlotSpoken;
      expect(slot.persistFailed, isTrue);
      expect(await failureFuture, isA<DatabaseFailure>());
      await cubit.close();
    });

    test("invalidResponse falls back to the character's canned reply, saved as isFallback", () async {
      when(
        () => aiReactionRepository.requestReaction(
          characterId: 'cat',
          dayText: 'today was fine',
          dayEntryId: 1,
        ),
      ).thenAnswer(
        (_) async => const Result.failure(AiProxyFailure(null, code: AiProxyFailure.invalidResponse)),
      );
      when(() => diaryRepository.addReaction(any())).thenAnswer(
        (invocation) async =>
            Result.success(invocation.positionalArguments.first as CharacterReaction),
      );

      final cubit = build();
      await cubit.load(_dayKey);
      await cubit.requestReaction('cat');

      final state = cubit.state as TableLoaded;
      final slot = state.data.slots['cat']! as CharacterSlotSpoken;
      expect(slot.reaction.isFallback, isTrue);
      expect(slot.reaction.reply, 'Мяу');
      await cubit.close();
    });

    test('network failure reverts the slot and publishes the failure (FR-029a)', () async {
      when(
        () => aiReactionRepository.requestReaction(
          characterId: 'cat',
          dayText: 'today was fine',
          dayEntryId: 1,
        ),
      ).thenAnswer((_) async => const Result.failure(AiProxyFailure(null, code: AiProxyFailure.network)));

      final cubit = build();
      await cubit.load(_dayKey);
      final failureFuture = cubit.failures.first;
      await cubit.requestReaction('cat');

      expect((cubit.state as TableLoaded).data.slots['cat'], const CharacterSlot.idle());
      expect(await failureFuture, isA<AiProxyFailure>());
      verifyNever(() => diaryRepository.addReaction(any()));
      await cubit.close();
    });

    test('no mood picked blocks the request (FR-014)', () async {
      when(
        () => diaryRepository.entryForDay(_dayKey),
      ).thenAnswer((_) async => const Result.success(null));

      final cubit = build();
      await cubit.load(_dayKey);
      final failureFuture = cubit.failures.first;
      await cubit.requestReaction('cat');

      expect(
        await failureFuture,
        isA<ValidationFailure>().having((f) => f.code, 'code', ValidationFailure.moodNotSelected),
      );
      verifyNever(
        () => aiReactionRepository.requestReaction(
          characterId: any(named: 'characterId'),
          dayText: any(named: 'dayText'),
          dayEntryId: any(named: 'dayEntryId'),
        ),
      );
      await cubit.close();
    });

    test('empty day text blocks the request (FR-014)', () async {
      when(
        () => diaryRepository.entryForDay(_dayKey),
      ).thenAnswer((_) async => Result.success(_entry()));

      final cubit = build();
      await cubit.load(_dayKey);
      final failureFuture = cubit.failures.first;
      await cubit.requestReaction('cat');

      expect(
        await failureFuture,
        isA<ValidationFailure>().having((f) => f.code, 'code', ValidationFailure.dayTextEmpty),
      );
      verifyNever(
        () => aiReactionRepository.requestReaction(
          characterId: any(named: 'characterId'),
          dayText: any(named: 'dayText'),
          dayEntryId: any(named: 'dayEntryId'),
        ),
      );
      await cubit.close();
    });

    test('read-only mode blocks the request', () async {
      final cubit = build(storageMode: StorageMode.readOnly);
      await cubit.load(_dayKey);
      final failureFuture = cubit.failures.first;
      await cubit.requestReaction('cat');

      expect(
        await failureFuture,
        isA<DatabaseFailure>().having((f) => f.code, 'code', DatabaseFailure.storageReadOnly),
      );
      verifyNever(
        () => aiReactionRepository.requestReaction(
          characterId: any(named: 'characterId'),
          dayText: any(named: 'dayText'),
          dayEntryId: any(named: 'dayEntryId'),
        ),
      );
      await cubit.close();
    });
  });

  group('enabled-character roster (FR-010, FR-010c)', () {
    test('a live settings change adds/removes characters without reopening the screen', () async {
      when(
        () => diaryRepository.entryForDay(_dayKey),
      ).thenAnswer((_) async => const Result.success(null));
      final settingsController = StreamController<UserSettings>.broadcast();
      when(() => settingsRepository.watch()).thenAnswer((_) => settingsController.stream);
      when(() => settingsRepository.load()).thenAnswer((_) async => Result.success(_settings(enabled: const ['cat'])));
      when(() => characterCatalog.load()).thenAnswer(
        (_) async => Result.success([_character('cat'), _character('dog')]),
      );

      final cubit = build();
      await cubit.load(_dayKey);
      expect((cubit.state as TableLoaded).data.characters.map((c) => c.id), ['cat']);

      settingsController.add(_settings(enabled: const ['dog']));
      await pumpEventQueue();

      expect((cubit.state as TableLoaded).data.characters.map((c) => c.id), ['dog']);
      expect((cubit.state as TableLoaded).data.slots.containsKey('cat'), isFalse);

      await cubit.close();
      await settingsController.close();
    });
  });
}
