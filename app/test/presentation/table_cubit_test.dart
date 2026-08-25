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
import 'package:roundtablezoo/domain/value_objects/character_voice.dart';
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

MoodScore _mood(int value) =>
    MoodScore.create(value).valueOrGet(() => throw StateError('bad fixture'));

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
  voice: CharacterVoice.neutral,
);

const _characters = [
  Character(
    id: 'cat',
    name: 'cat',
    colorHex: 0xFF000000,
    fallbackReply: 'Мяу',
    maxReplyLength: 200,
    voice: CharacterVoice.neutral,
  ),
];

CharacterReaction _reaction({int? id, String characterId = 'cat', bool isFallback = false}) =>
    CharacterReaction(
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
    when(
      () => diaryRepository.reactionsFor(any()),
    ).thenAnswer((_) async => const Result.success(<CharacterReaction>[]));
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
      'restores the latest reply per character, marked restored (FR-003a, FR-003b)',
      setUp: () {
        when(
          () => diaryRepository.entryForDay(_dayKey),
        ).thenAnswer((_) async => Result.success(_entry(id: 1)));
        when(() => diaryRepository.reactionsFor(1)).thenAnswer(
          (_) async => Result.success([
            _reaction(id: 1, characterId: 'cat').copyWith(createdAt: DateTime.utc(2026, 3, 10, 10)),
            _reaction(id: 2, characterId: 'cat').copyWith(createdAt: DateTime.utc(2026, 3, 10, 11)),
          ]),
        );
      },
      build: build,
      act: (cubit) => cubit.load(_dayKey),
      expect: () => [
        const TableState.loading(),
        isA<TableLoaded>().having(
          (s) => s.data.slots['cat'],
          'slots[cat]',
          isA<CharacterSlotSpoken>()
              .having((slot) => slot.reaction.id, 'reaction.id', 2)
              .having((slot) => slot.restored, 'restored', isTrue)
              .having((slot) => slot.stale, 'stale', isFalse),
        ),
      ],
      verify: (_) {
        verifyNever(
          () => aiReactionRepository.requestReaction(
            characterId: any(named: 'characterId'),
            dayText: any(named: 'dayText'),
            dayEntryId: any(named: 'dayEntryId'),
            moodScore: any(named: 'moodScore'),
            attempt: any(named: 'attempt'),
          ),
        );
      },
    );

    blocTest<TableCubit, TableState>(
      "a reaction for a character no longer at the table (removed/disabled) doesn't break restore",
      setUp: () {
        when(
          () => diaryRepository.entryForDay(_dayKey),
        ).thenAnswer((_) async => Result.success(_entry(id: 1)));
        when(
          () => diaryRepository.reactionsFor(1),
        ).thenAnswer(
          (_) async => Result.success([_reaction(id: 1, characterId: 'ghost-character')]),
        );
      },
      build: build,
      act: (cubit) => cubit.load(_dayKey),
      expect: () => [
        const TableState.loading(),
        isA<TableLoaded>().having(
          (s) => s.data.slots.containsKey('ghost-character'),
          'no ghost slot',
          isFalse,
        ),
      ],
    );

    blocTest<TableCubit, TableState>(
      'a broken character catalog degrades to an empty table, not a screen error (FR-010d)',
      setUp: () {
        when(() => diaryRepository.entryForDay(_dayKey))
            .thenAnswer((_) async => const Result.success(null));
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
        () => diaryRepository.saveTodayEntry(
          moodScore: any(named: 'moodScore'),
          dayText: 'typed early',
        ),
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
          () => diaryRepository.saveTodayEntry(
            moodScore: any(named: 'moodScore'),
            dayText: 'abc',
          ),
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
        () => diaryRepository.saveTodayEntry(
          moodScore: any(named: 'moodScore'),
          dayText: 'unsaved',
        ),
      ).called(1);
    });

    test(
      'flushDayText() (called by TablePage on AppLifecycleState.paused) saves immediately',
      () async {
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
          () => diaryRepository.saveTodayEntry(
            moodScore: any(named: 'moodScore'),
            dayText: 'paused-save',
          ),
        ).called(1);
        await cubit.close();
      },
    );
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
          moodScore: any(named: 'moodScore'),
          attempt: any(named: 'attempt'),
        ),
      ).thenAnswer((_) async => Result.success(_reaction(id: 9)));
      when(() => diaryRepository.addReaction(any()))
          .thenAnswer((_) async => Result.success(_reaction(id: 9)));

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
          moodScore: any(named: 'moodScore'),
          attempt: any(named: 'attempt'),
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

    test(
      "invalidResponse falls back to the character's canned reply, saved as isFallback",
      () async {
        when(
          () => aiReactionRepository.requestReaction(
            characterId: 'cat',
            dayText: 'today was fine',
            dayEntryId: 1,
            moodScore: any(named: 'moodScore'),
            attempt: any(named: 'attempt'),
          ),
        ).thenAnswer(
          (_) async =>
              const Result.failure(AiProxyFailure(null, code: AiProxyFailure.invalidResponse)),
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
      },
    );

    test('timeout falls back to the canned reply, same as invalidResponse (FR-027b)', () async {
      when(
        () => aiReactionRepository.requestReaction(
          characterId: 'cat',
          dayText: 'today was fine',
          dayEntryId: 1,
          moodScore: any(named: 'moodScore'),
          attempt: any(named: 'attempt'),
        ),
      ).thenAnswer(
        (_) async => const Result.failure(AiProxyFailure(null, code: AiProxyFailure.timeout)),
      );
      when(() => diaryRepository.addReaction(any())).thenAnswer(
        (invocation) async =>
            Result.success(invocation.positionalArguments.first as CharacterReaction),
      );

      final cubit = build();
      await cubit.load(_dayKey);
      await cubit.requestReaction('cat');

      final slot = (cubit.state as TableLoaded).data.slots['cat']! as CharacterSlotSpoken;
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
          moodScore: any(named: 'moodScore'),
          attempt: any(named: 'attempt'),
        ),
      ).thenAnswer(
        (_) async => const Result.failure(AiProxyFailure(null, code: AiProxyFailure.network)),
      );

      final cubit = build();
      await cubit.load(_dayKey);
      final failureFuture = cubit.failures.first;
      await cubit.requestReaction('cat');

      expect((cubit.state as TableLoaded).data.slots['cat'], const CharacterSlot.idle());
      expect(await failureFuture, isA<AiProxyFailure>());
      verifyNever(() => diaryRepository.addReaction(any()));
      await cubit.close();
    });

    test('rateLimited reverts the slot and publishes the failure (FR-025, FR-029a)', () async {
      when(
        () => aiReactionRepository.requestReaction(
          characterId: 'cat',
          dayText: 'today was fine',
          dayEntryId: 1,
          moodScore: any(named: 'moodScore'),
          attempt: any(named: 'attempt'),
        ),
      ).thenAnswer(
        (_) async => const Result.failure(AiProxyFailure(null, code: AiProxyFailure.rateLimitedDevice)),
      );

      final cubit = build();
      await cubit.load(_dayKey);
      final failureFuture = cubit.failures.first;
      await cubit.requestReaction('cat');

      expect((cubit.state as TableLoaded).data.slots['cat'], const CharacterSlot.idle());
      expect(
        await failureFuture,
        isA<AiProxyFailure>().having((f) => f.code, 'code', AiProxyFailure.rateLimitedDevice),
      );
      verifyNever(() => diaryRepository.addReaction(any()));
      await cubit.close();
    });

    test('aiDisabled reverts the slot and publishes the failure (FR-026, FR-029a)', () async {
      when(
        () => aiReactionRepository.requestReaction(
          characterId: 'cat',
          dayText: 'today was fine',
          dayEntryId: 1,
          moodScore: any(named: 'moodScore'),
          attempt: any(named: 'attempt'),
        ),
      ).thenAnswer(
        (_) async => const Result.failure(AiProxyFailure(null, code: AiProxyFailure.aiDisabled)),
      );

      final cubit = build();
      await cubit.load(_dayKey);
      final failureFuture = cubit.failures.first;
      await cubit.requestReaction('cat');

      expect((cubit.state as TableLoaded).data.slots['cat'], const CharacterSlot.idle());
      expect(
        await failureFuture,
        isA<AiProxyFailure>().having((f) => f.code, 'code', AiProxyFailure.aiDisabled),
      );
      verifyNever(() => diaryRepository.addReaction(any()));
      await cubit.close();
    });

    test(
      'network failure on a retap reverts to the previous reply, not to idle (FR-029a)',
      () async {
        when(() => diaryRepository.addReaction(any())).thenAnswer(
          (invocation) async =>
              Result.success(invocation.positionalArguments.first as CharacterReaction),
        );

        var callCount = 0;
        when(
          () => aiReactionRepository.requestReaction(
            characterId: 'cat',
            dayText: 'today was fine',
            dayEntryId: 1,
            moodScore: any(named: 'moodScore'),
            attempt: any(named: 'attempt'),
          ),
        ).thenAnswer((_) async {
          callCount++;
          return callCount == 1
              ? Result.success(_reaction(id: 1))
              : const Result.failure(AiProxyFailure(null, code: AiProxyFailure.network));
        });

        final cubit = build();
        await cubit.load(_dayKey);
        await cubit.requestReaction('cat');
        final priorSlot = (cubit.state as TableLoaded).data.slots['cat'];
        expect(priorSlot, isA<CharacterSlotSpoken>());

        await cubit.requestReaction('cat');

        expect((cubit.state as TableLoaded).data.slots['cat'], priorSlot);
        await cubit.close();
      },
    );

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
          moodScore: any(named: 'moodScore'),
          attempt: any(named: 'attempt'),
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
          moodScore: any(named: 'moodScore'),
          attempt: any(named: 'attempt'),
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
          moodScore: any(named: 'moodScore'),
          attempt: any(named: 'attempt'),
        ),
      );
      await cubit.close();
    });
  });

  group('generation counter and racing taps (US3, research.md R6)', () {
    setUp(() {
      when(
        () => diaryRepository.entryForDay(_dayKey),
      ).thenAnswer((_) async => Result.success(_entry(dayText: 'today was fine')));
      when(() => diaryRepository.addReaction(any())).thenAnswer(
        (invocation) async =>
            Result.success(invocation.positionalArguments.first as CharacterReaction),
      );
    });

    test(
      'two rapid taps on the same character: only the later response is shown and persisted '
      '(FR-019, FR-020)',
      () async {
        final firstCompleter = Completer<Result<CharacterReaction>>();
        var callCount = 0;
        when(
          () => aiReactionRepository.requestReaction(
            characterId: 'cat',
            dayText: 'today was fine',
            dayEntryId: 1,
            moodScore: any(named: 'moodScore'),
            attempt: any(named: 'attempt'),
          ),
        ).thenAnswer((_) {
          callCount++;
          return callCount == 1
              ? firstCompleter.future
              : Future.value(Result.success(_reaction(id: 2)));
        });

        final cubit = build();
        await cubit.load(_dayKey);

        final firstFuture = cubit.requestReaction('cat');
        await pumpEventQueue();
        await cubit.requestReaction('cat');

        // The stale (first) response arrives last — it must not overwrite
        // the newer one, nor be persisted.
        firstCompleter.complete(Result.success(_reaction(id: 1)));
        await firstFuture;
        await pumpEventQueue();

        final slot = (cubit.state as TableLoaded).data.slots['cat']! as CharacterSlotSpoken;
        expect(slot.reaction.id, 2);
        verify(() => diaryRepository.addReaction(any())).called(1);
        await cubit.close();
      },
    );

    test('taps on two different characters run concurrently, not serialized (FR-019)', () async {
      when(
        () => characterCatalog.load(),
      ).thenAnswer((_) async => Result.success([_character('cat'), _character('dog')]));
      when(
        () => settingsRepository.load(),
      ).thenAnswer((_) async => Result.success(_settings(enabled: const ['cat', 'dog'])));

      final catCompleter = Completer<Result<CharacterReaction>>();
      final dogCompleter = Completer<Result<CharacterReaction>>();
      when(
        () => aiReactionRepository.requestReaction(
          characterId: 'cat',
          dayText: 'today was fine',
          dayEntryId: 1,
          moodScore: any(named: 'moodScore'),
          attempt: any(named: 'attempt'),
        ),
      ).thenAnswer((_) => catCompleter.future);
      when(
        () => aiReactionRepository.requestReaction(
          characterId: 'dog',
          dayText: 'today was fine',
          dayEntryId: 1,
          moodScore: any(named: 'moodScore'),
          attempt: any(named: 'attempt'),
        ),
      ).thenAnswer((_) => dogCompleter.future);

      final cubit = build();
      await cubit.load(_dayKey);

      final catFuture = cubit.requestReaction('cat');
      await pumpEventQueue();
      final dogFuture = cubit.requestReaction('dog');
      await pumpEventQueue();

      final mid = cubit.state as TableLoaded;
      expect(mid.data.slots['cat'], const CharacterSlot.loading());
      expect(mid.data.slots['dog'], const CharacterSlot.loading());

      catCompleter.complete(Result.success(_reaction(id: 1, characterId: 'cat')));
      dogCompleter.complete(Result.success(_reaction(id: 2, characterId: 'dog')));
      await Future.wait([catFuture, dogFuture]);
      await cubit.close();
    });

    test('a response arriving after close() is dropped, not persisted (FR-021d)', () async {
      final completer = Completer<Result<CharacterReaction>>();
      when(
        () => aiReactionRepository.requestReaction(
          characterId: 'cat',
          dayText: 'today was fine',
          dayEntryId: 1,
          moodScore: any(named: 'moodScore'),
          attempt: any(named: 'attempt'),
        ),
      ).thenAnswer((_) => completer.future);

      final cubit = build();
      await cubit.load(_dayKey);
      final future = cubit.requestReaction('cat');
      await pumpEventQueue();

      await cubit.close();
      completer.complete(Result.success(_reaction(id: 1)));
      await future;

      verifyNever(() => diaryRepository.addReaction(any()));
    });

    test(
      'three sequential retaps of the same character save three reactions, the table shows the '
      'last (FR-021a, FR-021b)',
      () async {
        var replyId = 0;
        when(
          () => aiReactionRepository.requestReaction(
            characterId: 'cat',
            dayText: 'today was fine',
            dayEntryId: 1,
            moodScore: any(named: 'moodScore'),
            attempt: any(named: 'attempt'),
          ),
        ).thenAnswer((_) async => Result.success(_reaction(id: ++replyId)));

        final cubit = build();
        await cubit.load(_dayKey);
        await cubit.requestReaction('cat');
        await cubit.requestReaction('cat');
        await cubit.requestReaction('cat');

        verify(() => diaryRepository.addReaction(any())).called(3);
        final slot = (cubit.state as TableLoaded).data.slots['cat']! as CharacterSlotSpoken;
        expect(slot.reaction.id, 3);
        await cubit.close();
      },
    );

    test(
      'editing text after a reply marks the slot stale; a new reply clears it (FR-023, FR-023a)',
      () async {
        when(
          () => aiReactionRepository.requestReaction(
            characterId: 'cat',
            dayText: any(named: 'dayText'),
            dayEntryId: 1,
            moodScore: any(named: 'moodScore'),
            attempt: any(named: 'attempt'),
          ),
        ).thenAnswer((_) async => Result.success(_reaction(id: 1)));
        when(
          () => diaryRepository.saveTodayEntry(
            moodScore: any(named: 'moodScore'),
            dayText: any(named: 'dayText'),
          ),
        ).thenAnswer((_) async => Result.success(_entry(dayText: 'edited')));

        final cubit = build();
        await cubit.load(_dayKey);
        await cubit.requestReaction('cat');

        cubit.onDayTextChanged('edited');
        final staleSlot = (cubit.state as TableLoaded).data.slots['cat']! as CharacterSlotSpoken;
        expect(staleSlot.stale, isTrue);

        await cubit.flushDayText();
        await cubit.requestReaction('cat');
        final freshSlot = (cubit.state as TableLoaded).data.slots['cat']! as CharacterSlotSpoken;
        expect(freshSlot.stale, isFalse);

        await cubit.close();
      },
    );
  });

  group('onDayChanged (research.md R13, FR-006)', () {
    const newDayKey = DayKey(year: 2026, month: 3, day: 11);

    test('flushes unsaved text to the outgoing day before switching (FR-006a)', () async {
      when(
        () => diaryRepository.entryForDay(_dayKey),
      ).thenAnswer((_) async => Result.success(_entry(id: 1, mood: 3)));
      when(
        () => diaryRepository.saveTodayEntry(
          moodScore: any(named: 'moodScore'),
          dayText: any(named: 'dayText'),
        ),
      ).thenAnswer((_) async => Result.success(_entry(id: 1, dayText: 'leftover')));
      when(
        () => diaryRepository.entryForDay(newDayKey),
      ).thenAnswer((_) async => const Result.success(null));

      final cubit = build();
      await cubit.load(_dayKey);
      cubit.onDayTextChanged('leftover');
      await cubit.onDayChanged(newDayKey);

      verify(
        () => diaryRepository.saveTodayEntry(
          moodScore: any(named: 'moodScore'),
          dayText: 'leftover',
        ),
      ).called(1);
      expect((cubit.state as TableLoaded).data.dayKey, newDayKey);
      await cubit.close();
    });

    test('resets slots — no leftover reactions from the previous day', () async {
      when(
        () => diaryRepository.entryForDay(_dayKey),
      ).thenAnswer((_) async => Result.success(_entry(id: 1, mood: 3)));
      when(
        () => diaryRepository.reactionsFor(1),
      ).thenAnswer((_) async => Result.success([_reaction(id: 1, characterId: 'cat')]));
      when(
        () => diaryRepository.entryForDay(newDayKey),
      ).thenAnswer((_) async => const Result.success(null));

      final cubit = build();
      await cubit.load(_dayKey);
      expect((cubit.state as TableLoaded).data.slots['cat'], isA<CharacterSlotSpoken>());

      await cubit.onDayChanged(newDayKey);

      expect((cubit.state as TableLoaded).data.slots['cat'], const CharacterSlot.idle());
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
      when(() => settingsRepository.load())
          .thenAnswer((_) async => Result.success(_settings(enabled: const ['cat'])));
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

  group('attempt counter (research.md R20, R21)', () {
    setUp(() {
      when(
        () => diaryRepository.entryForDay(_dayKey),
      ).thenAnswer((_) async => Result.success(_entry(dayText: 'today was fine')));
      when(() => diaryRepository.addReaction(any())).thenAnswer(
        (invocation) async =>
            Result.success(invocation.positionalArguments.first as CharacterReaction),
      );
    });

    test('the first request of the day sends attempt: 0', () async {
      when(
        () => aiReactionRepository.requestReaction(
          characterId: 'cat',
          dayText: 'today was fine',
          dayEntryId: 1,
          moodScore: any(named: 'moodScore'),
          attempt: 0,
        ),
      ).thenAnswer((_) async => Result.success(_reaction(id: 1)));

      final cubit = build();
      await cubit.load(_dayKey);
      await cubit.requestReaction('cat');

      verify(
        () => aiReactionRepository.requestReaction(
          characterId: 'cat',
          dayText: 'today was fine',
          dayEntryId: 1,
          moodScore: any(named: 'moodScore'),
          attempt: 0,
        ),
      ).called(1);
      await cubit.close();
    });

    test('a real AI response bumps attempt for the next request of the same character', () async {
      var call = 0;
      when(
        () => aiReactionRepository.requestReaction(
          characterId: 'cat',
          dayText: 'today was fine',
          dayEntryId: 1,
          moodScore: any(named: 'moodScore'),
          attempt: any(named: 'attempt'),
        ),
      ).thenAnswer((_) async => Result.success(_reaction(id: ++call)));

      final cubit = build();
      await cubit.load(_dayKey);
      await cubit.requestReaction('cat');
      await cubit.requestReaction('cat');

      verify(
        () => aiReactionRepository.requestReaction(
          characterId: 'cat',
          dayText: 'today was fine',
          dayEntryId: 1,
          moodScore: any(named: 'moodScore'),
          attempt: 1,
        ),
      ).called(1);
      await cubit.close();
    });

    test('a fallback reply does not bump attempt — the next request repeats it', () async {
      when(
        () => aiReactionRepository.requestReaction(
          characterId: 'cat',
          dayText: 'today was fine',
          dayEntryId: 1,
          moodScore: any(named: 'moodScore'),
          attempt: 0,
        ),
      ).thenAnswer(
        (_) async => const Result.failure(AiProxyFailure(null, code: AiProxyFailure.timeout)),
      );

      final cubit = build();
      await cubit.load(_dayKey);
      await cubit.requestReaction('cat');
      await cubit.requestReaction('cat');

      verify(
        () => aiReactionRepository.requestReaction(
          characterId: 'cat',
          dayText: 'today was fine',
          dayEntryId: 1,
          moodScore: any(named: 'moodScore'),
          attempt: 0,
        ),
      ).called(2);
      await cubit.close();
    });

    test('restores the counter on load from today\'s already-saved real reactions', () async {
      when(
        () => diaryRepository.entryForDay(_dayKey),
      ).thenAnswer((_) async => Result.success(_entry(id: 1, dayText: 'today was fine')));
      when(() => diaryRepository.reactionsFor(1)).thenAnswer(
        (_) async => Result.success([
          _reaction(id: 1, characterId: 'cat'),
          _reaction(id: 2, characterId: 'cat', isFallback: true),
          _reaction(id: 3, characterId: 'cat'),
        ]),
      );
      when(
        () => aiReactionRepository.requestReaction(
          characterId: 'cat',
          dayText: 'today was fine',
          dayEntryId: 1,
          moodScore: any(named: 'moodScore'),
          attempt: 2,
        ),
      ).thenAnswer((_) async => Result.success(_reaction(id: 4)));

      final cubit = build();
      await cubit.load(_dayKey);
      await cubit.requestReaction('cat');

      // Two real reactions were restored (the fallback one doesn't count,
      // R21) — the next request must continue at attempt 2, not 1 or 3.
      verify(
        () => aiReactionRepository.requestReaction(
          characterId: 'cat',
          dayText: 'today was fine',
          dayEntryId: 1,
          moodScore: any(named: 'moodScore'),
          attempt: 2,
        ),
      ).called(1);
      await cubit.close();
    });
  });

  group('per-character failure isolation (US3, FR-026)', () {
    test(
      'a failure on one character leaves an unrelated idle character untouched',
      () async {
        when(
          () => characterCatalog.load(),
        ).thenAnswer((_) async => Result.success([_character('cat'), _character('dog')]));
        when(
          () => settingsRepository.load(),
        ).thenAnswer((_) async => Result.success(_settings(enabled: const ['cat', 'dog'])));
        when(
          () => diaryRepository.entryForDay(_dayKey),
        ).thenAnswer((_) async => Result.success(_entry(dayText: 'today was fine')));
        when(
          () => aiReactionRepository.requestReaction(
            characterId: 'cat',
            dayText: 'today was fine',
            dayEntryId: 1,
            moodScore: any(named: 'moodScore'),
            attempt: any(named: 'attempt'),
          ),
        ).thenAnswer(
          (_) async => const Result.failure(AiProxyFailure(null, code: AiProxyFailure.network)),
        );

        final cubit = build();
        await cubit.load(_dayKey);
        await cubit.requestReaction('cat');

        final state = cubit.state as TableLoaded;
        expect(state.data.slots['cat'], const CharacterSlot.idle());
        // The character never tapped stays idle too — one seat's failure
        // must not ripple into a sibling seat's state.
        expect(state.data.slots['dog'], const CharacterSlot.idle());
        verifyNever(
          () => aiReactionRepository.requestReaction(
            characterId: 'dog',
            dayText: any(named: 'dayText'),
            dayEntryId: any(named: 'dayEntryId'),
            moodScore: any(named: 'moodScore'),
            attempt: any(named: 'attempt'),
          ),
        );
        await cubit.close();
      },
    );
  });
}
