import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:mocktail/mocktail.dart';
import 'package:roundtablezoo/core/errors/result.dart';
import 'package:roundtablezoo/core/speech/flutter_tts_speech_synthesizer.dart';
import 'package:roundtablezoo/core/speech/speech_synthesizer.dart';
import 'package:roundtablezoo/domain/value_objects/character_voice.dart';

class MockFlutterTts extends Mock implements FlutterTts {}

void main() {
  late MockFlutterTts tts;
  late FlutterTtsSpeechSynthesizer synthesizer;

  setUpAll(() {
    registerFallbackValue(IosTextToSpeechAudioCategory.ambient);
    registerFallbackValue(<IosTextToSpeechAudioCategoryOptions>[]);
  });

  setUp(() {
    tts = MockFlutterTts();
    synthesizer = FlutterTtsSpeechSynthesizer.test(tts);
    when(() => tts.awaitSpeakCompletion(any())).thenAnswer((_) async => 1);
    when(() => tts.setLanguage(any())).thenAnswer((_) async => 1);
    when(() => tts.setPitch(any())).thenAnswer((_) async => 1);
    when(() => tts.setSpeechRate(any())).thenAnswer((_) async => 1);
    when(() => tts.speak(any(), focus: any(named: 'focus'))).thenAnswer((_) async => 1);
    when(() => tts.stop()).thenAnswer((_) async => 1);
    when(() => tts.isLanguageInstalled(any())).thenAnswer((_) async => true);
    when(() => tts.isLanguageAvailable(any())).thenAnswer((_) async => true);
    when(
      () => tts.setIosAudioCategory(any(), any()),
    ).thenAnswer((_) async => 1);
  });

  test('speak() applies language/pitch/rate before speaking', () async {
    const request = SpeechRequest(
      text: 'мяу',
      languageTag: 'ru',
      voice: CharacterVoice(pitch: 1.5, rate: 0.62),
    );

    final result = await synthesizer.speak(request);

    expect(result.isSuccess, isTrue);
    verify(() => tts.setLanguage('ru')).called(1);
    verify(() => tts.setPitch(1.5)).called(1);
    verify(() => tts.setSpeechRate(0.62)).called(1);
    verify(() => tts.speak('мяу', focus: any(named: 'focus'))).called(1);
  });

  test('a platform exception becomes a Result.failure, not a thrown error', () async {
    when(() => tts.speak(any(), focus: any(named: 'focus'))).thenThrow(
      PlatformException(code: 'error'),
    );

    final result = await synthesizer.speak(
      const SpeechRequest(text: 'x', languageTag: 'ru', voice: CharacterVoice.neutral),
    );

    expect(result.isFailure, isTrue);
  });

  test('isAvailableFor() returns success(false) when the engine has no voice', () async {
    when(() => tts.isLanguageInstalled(any())).thenAnswer((_) async => false);
    when(() => tts.isLanguageAvailable(any())).thenAnswer((_) async => false);

    final result = await synthesizer.isAvailableFor('ru');

    expect(result, const Result.success(false));
  });

  test('initialize() is idempotent — a second speak() does not re-initialize', () async {
    await synthesizer.isAvailableFor('ru');
    await synthesizer.speak(
      const SpeechRequest(text: 'x', languageTag: 'ru', voice: CharacterVoice.neutral),
    );

    verify(() => tts.awaitSpeakCompletion(true)).called(1);
  });

  test(
    'isAvailableFor() asks isLanguageInstalled on Android — excludes network-only voices (FR-015)',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);

      await synthesizer.isAvailableFor('ru');

      verify(() => tts.isLanguageInstalled('ru')).called(1);
      verifyNever(() => tts.isLanguageAvailable(any()));
    },
  );

  test('isAvailableFor() asks isLanguageAvailable on non-Android platforms', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);

    await synthesizer.isAvailableFor('ru');

    verify(() => tts.isLanguageAvailable('ru')).called(1);
    verifyNever(() => tts.isLanguageInstalled(any()));
  });
}
