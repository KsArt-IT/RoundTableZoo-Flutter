import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:injectable/injectable.dart';
import 'package:roundtablezoo/core/errors/result.dart';
import 'package:roundtablezoo/core/errors/safe_call_mixin.dart';
import 'package:roundtablezoo/core/speech/speech_synthesizer.dart';

/// Only file in the app that imports `flutter_tts` (principle I). Wraps
/// the plugin behind [SpeechSynthesizer]. One instance per process
/// (`@LazySingleton`) — `initialize()` is lazy, called from inside
/// [isAvailableFor]/[speak] on first use, never from `main.dart`
/// (`contracts/speech-synthesizer.md` §1, "Регистрация").
@LazySingleton(as: SpeechSynthesizer)
class FlutterTtsSpeechSynthesizer with SafeCallMixin implements SpeechSynthesizer {
  FlutterTtsSpeechSynthesizer() : _tts = FlutterTts();

  /// Not picked up by `injectable` (unnamed-constructor-only resolution) —
  /// lets `speech_synthesizer_test.dart` substitute a mocktail `FlutterTts`
  /// double without ever registering the plugin type in `getIt`.
  @visibleForTesting
  FlutterTtsSpeechSynthesizer.test(FlutterTts tts) : _tts = tts;

  final FlutterTts _tts;
  bool _initialized = false;

  @override
  Future<Result<void>> initialize() => safeCall(() async {
    if (_initialized) return;

    // Android's `awaitSpeakCompletion` only works with the default
    // `QUEUE_FLUSH` mode — `setQueueMode` is deliberately never called
    // (research.md R4, S1).
    await _tts.awaitSpeakCompletion(true);

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      // `ambient` + `mixWithOthers` + `duckOthers`: ducks other audio
      // during speech (FR-011a) and respects the mute switch (FR-011b,
      // research.md R6/R7).
      await _tts.setIosAudioCategory(IosTextToSpeechAudioCategory.ambient, [
        IosTextToSpeechAudioCategoryOptions.mixWithOthers,
        IosTextToSpeechAudioCategoryOptions.duckOthers,
      ]);
    }

    _initialized = true;
  });

  @override
  Future<Result<bool>> isAvailableFor(String languageTag) => safeCall(() async {
    if (!_initialized) await initialize();

    // Android: `isLanguageInstalled` excludes voices requiring a network
    // connection — the only check that satisfies FR-015/principle V
    // (research.md R3). iOS synthesizes on-device regardless, so
    // `isLanguageAvailable` is enough there.
    final available = defaultTargetPlatform == TargetPlatform.android
        ? await _tts.isLanguageInstalled(languageTag)
        : await _tts.isLanguageAvailable(languageTag);
    return available == true;
  });

  @override
  Future<Result<void>> speak(SpeechRequest request) => safeCall(() async {
    if (!_initialized) await initialize();

    // Order matters: language/pitch/rate apply to the *next* speak call,
    // and each reply may belong to a different character (S3).
    await _tts.setLanguage(request.languageTag);
    await _tts.setPitch(request.voice.pitch);
    await _tts.setSpeechRate(request.voice.rate);

    final focus = defaultTargetPlatform == TargetPlatform.android;
    await _tts.speak(request.text, focus: focus);
  });

  @override
  Future<Result<void>> stop() => safeCall(() async {
    await _tts.stop();
  });
}
