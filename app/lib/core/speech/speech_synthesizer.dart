import 'package:roundtablezoo/core/errors/result.dart';
import 'package:roundtablezoo/domain/value_objects/character_voice.dart';

/// Abstraction over the on-device speech engine. Implementation is
/// `FlutterTtsSpeechSynthesizer`; tests substitute a mocktail mock — the
/// platform channel doesn't respond under `flutter test`
/// (`contracts/speech-synthesizer.md` §1).
abstract interface class SpeechSynthesizer {
  /// Initializes the engine. Idempotent — safe to call more than once.
  /// Sets `awaitSpeakCompletion(true)` and, on iOS, the `ambient` audio
  /// category (research.md R4, R6).
  Future<Result<void>> initialize();

  /// Whether the device has a local voice for [languageTag] (`"ru"`,
  /// `"ru-RU"`). Android — `isLanguageInstalled` (excludes network voices,
  /// research.md R3); iOS/others — `isLanguageAvailable`. An unavailable
  /// engine returns `success(false)`, not a failure.
  Future<Result<bool>> isAvailableFor(String languageTag);

  /// Speaks [request] in full. The future completes when speech finishes
  /// (`awaitSpeakCompletion`), not when the command is merely sent. A
  /// `stop()`-interrupted utterance completes just as successfully — the
  /// caller tells the difference from its own state, not from the
  /// [Result].
  Future<Result<void>> speak(SpeechRequest request);

  /// Immediately stops the current utterance. Safe to call when nothing is
  /// speaking.
  Future<Result<void>> stop();
}

/// One synthesis command — everything needed to apply before `speak`.
class SpeechRequest {
  const SpeechRequest({required this.text, required this.languageTag, required this.voice});

  final String text;
  final String languageTag;
  final CharacterVoice voice;
}
