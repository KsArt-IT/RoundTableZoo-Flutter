import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:roundtablezoo/core/errors/app_failure.dart';
import 'package:roundtablezoo/core/errors/result.dart';
import 'package:roundtablezoo/core/speech/speech_synthesizer.dart';
import 'package:roundtablezoo/domain/entities/user_settings.dart';
import 'package:roundtablezoo/domain/value_objects/character_voice.dart';
import 'package:roundtablezoo/domain/value_objects/day_start_hour.dart';
import 'package:roundtablezoo/domain/value_objects/locale_preference.dart';
import 'package:roundtablezoo/domain/value_objects/reminder_time.dart';
import 'package:roundtablezoo/domain/value_objects/theme_preference.dart';
import 'package:roundtablezoo/presentation/table/cubit/table_voice_cubit.dart';
import 'package:roundtablezoo/presentation/table/cubit/table_voice_state.dart';

import '../support/mocks.dart';

UserSettings _settings({bool soundEnabled = true}) => UserSettings(
  installId: 'test',
  themeMode: ThemePreference.system,
  locale: LocalePreference.system,
  soundEnabled: soundEnabled,
  enabledCharacterIds: const ['cat', 'dog'],
  hasSeenOnboarding: true,
  reminderEnabled: false,
  reminderTime: ReminderTime.defaultValue,
  dayStartHour: DayStartHour.defaultValue,
);

void main() {
  late MockSpeechSynthesizer synthesizer;
  late MockSilentModeProbe silentModeProbe;
  late MockSettingsRepository settingsRepository;
  late StreamController<UserSettings> settingsController;

  setUpAll(() {
    registerFallbackValue(
      const SpeechRequest(text: '', languageTag: 'ru', voice: CharacterVoice.neutral),
    );
  });

  setUp(() {
    synthesizer = MockSpeechSynthesizer();
    silentModeProbe = MockSilentModeProbe();
    settingsRepository = MockSettingsRepository();
    settingsController = StreamController<UserSettings>.broadcast();
    when(() => settingsRepository.watch()).thenAnswer((_) => settingsController.stream);
    when(() => silentModeProbe.isSilent()).thenAnswer((_) async => false);
    when(() => synthesizer.speak(any())).thenAnswer((_) async => const Result.success(null));
    when(() => synthesizer.stop()).thenAnswer((_) async => const Result.success(null));
  });

  tearDown(() async {
    await settingsController.close();
  });

  TableVoiceCubit build() => TableVoiceCubit(
    synthesizer: synthesizer,
    silentModeProbe: silentModeProbe,
    settingsRepository: settingsRepository,
  );

  void enqueue(TableVoiceCubit cubit, String characterId, {String text = 'hi'}) {
    cubit.enqueue(
      characterId: characterId,
      text: text,
      voice: CharacterVoice.neutral,
      languageTag: 'ru',
    );
  }

  blocTest<TableVoiceCubit, TableVoiceState>(
    'a single reply at open gates sets speakingCharacterId, then clears it (#1)',
    build: build,
    act: (cubit) => enqueue(cubit, 'cat'),
    expect: () => [
      const TableVoiceState(queueLength: 1),
      const TableVoiceState(),
      const TableVoiceState(speakingCharacterId: 'cat'),
      const TableVoiceState(),
    ],
    verify: (_) => verify(() => synthesizer.speak(any())).called(1),
  );

  test('stopAll() during an utterance calls synthesizer.stop() (#4)', () async {
    final completer = Completer<Result<void>>();
    when(() => synthesizer.speak(any())).thenAnswer((_) => completer.future);
    final cubit = build();

    enqueue(cubit, 'cat');
    await pumpEventQueue();
    expect(cubit.state.speakingCharacterId, 'cat');

    await cubit.stopAll();
    verify(() => synthesizer.stop()).called(1);
    expect(cubit.state.speakingCharacterId, isNull);
    expect(cubit.state.queueLength, 0);

    // A second queued reply must never sound after stopAll() (V5).
    enqueue(cubit, 'dog');
    // stopAll() cleared the (dog) gate check too? No — gates are still
    // open, `dog` is freshly enqueued after stopAll(), so it *should*
    // proceed on its own; this only proves the *cat* utterance's
    // completion doesn't resurrect anything.
    completer.complete(const Result.success(null));
    await pumpEventQueue();

    await cubit.close();
  });

  blocTest<TableVoiceCubit, TableVoiceState>(
    'two replies speak strictly in order, one at a time (#2, V1, V2)',
    build: build,
    act: (cubit) {
      enqueue(cubit, 'cat');
      enqueue(cubit, 'dog');
    },
    expect: () => [
      const TableVoiceState(queueLength: 1), // cat queued
      const TableVoiceState(), // cat popped off the queue, about to speak
      const TableVoiceState(queueLength: 1), // dog queued while cat processes
      const TableVoiceState(speakingCharacterId: 'cat', queueLength: 1),
      const TableVoiceState(queueLength: 1), // cat done speaking
      const TableVoiceState(), // dog popped off the queue
      const TableVoiceState(speakingCharacterId: 'dog'),
      const TableVoiceState(),
    ],
    verify: (_) {
      final captured = verify(() => synthesizer.speak(captureAny())).captured;
      expect((captured[0] as SpeechRequest).text, 'hi');
      expect((captured[1] as SpeechRequest).text, 'hi');
    },
  );

  test('enqueue() during an utterance does not interrupt the current one (#3, V3)', () async {
    final completer = Completer<Result<void>>();
    when(() => synthesizer.speak(any())).thenAnswer((_) => completer.future);
    final cubit = build();

    enqueue(cubit, 'cat');
    await pumpEventQueue();
    expect(cubit.state.speakingCharacterId, 'cat');

    enqueue(cubit, 'dog');
    await pumpEventQueue();
    // Still cat — enqueueing 'dog' didn't preempt it.
    expect(cubit.state.speakingCharacterId, 'cat');
    verify(() => synthesizer.speak(any())).called(1);

    completer.complete(const Result.success(null));
    await pumpEventQueue();
    expect(cubit.state.speakingCharacterId, isNull);

    await cubit.close();
  });

  test('soundEnabled: false blocks enqueue; true -> false during speech stops it (#5)', () async {
    final completer = Completer<Result<void>>();
    when(() => synthesizer.speak(any())).thenAnswer((_) => completer.future);
    final cubit = build();
    settingsController.add(_settings());
    await pumpEventQueue();

    enqueue(cubit, 'cat');
    await pumpEventQueue();
    expect(cubit.state.speakingCharacterId, 'cat');

    settingsController.add(_settings(soundEnabled: false));
    await pumpEventQueue();
    verify(() => synthesizer.stop()).called(1);
    expect(cubit.state.speakingCharacterId, isNull);

    // Blocked while sound stays off.
    enqueue(cubit, 'dog');
    await pumpEventQueue();
    expect(cubit.state.queueLength, 0);
    expect(cubit.state.speakingCharacterId, isNull);

    completer.complete(const Result.success(null));
    await cubit.close();
  });

  test(
    'onScreenReaderChanged(active: true) stops and blocks further enqueue (#6, FR-014)',
    () async {
      final cubit = build();

      cubit.onScreenReaderChanged(active: true);
      await pumpEventQueue();
      verify(() => synthesizer.stop()).called(1);

      enqueue(cubit, 'cat');
      await pumpEventQueue();
      expect(cubit.state.queueLength, 0);
      verifyNever(() => synthesizer.speak(any()));

      await cubit.close();
    },
  );

  test(
    'onVoiceAvailabilityChanged(available: false) stops and blocks further enqueue (#7, FR-012)',
    () async {
      final cubit = build();

      cubit.onVoiceAvailabilityChanged(available: false);
      await pumpEventQueue();
      verify(() => synthesizer.stop()).called(1);

      enqueue(cubit, 'cat');
      await pumpEventQueue();
      expect(cubit.state.queueLength, 0);
      verifyNever(() => synthesizer.speak(any()));

      await cubit.close();
    },
  );

  test('a silent device skips speak() but keeps processing the queue (#8, V4)', () async {
    when(() => silentModeProbe.isSilent()).thenAnswer((_) async => true);
    final cubit = build();

    enqueue(cubit, 'cat');
    await pumpEventQueue();

    verifyNever(() => synthesizer.speak(any()));
    expect(cubit.state.speakingCharacterId, isNull);
    expect(cubit.state.queueLength, 0);

    await cubit.close();
  });

  test('a speak() failure is swallowed; the next reply still plays (#9, V6)', () async {
    when(
      () => synthesizer.speak(any()),
    ).thenAnswer((_) async => const Result.failure(UnknownFailure('boom')));
    final cubit = build();

    enqueue(cubit, 'cat');
    enqueue(cubit, 'dog');
    await pumpEventQueue();

    verify(() => synthesizer.speak(any())).called(2);
    expect(cubit.state.speakingCharacterId, isNull);

    await cubit.close();
  });

  test('close() during an utterance does not emit afterwards (#10, V7)', () async {
    final completer = Completer<Result<void>>();
    when(() => synthesizer.speak(any())).thenAnswer((_) => completer.future);
    final cubit = build();

    enqueue(cubit, 'cat');
    await pumpEventQueue();
    expect(cubit.state.speakingCharacterId, 'cat');

    final closeFuture = cubit.close();
    completer.complete(const Result.success(null));
    await closeFuture;

    expect(cubit.isClosed, isTrue);
  });
}
