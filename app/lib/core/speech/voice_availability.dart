import 'package:roundtablezoo/core/speech/speech_synthesizer.dart';

/// "Voicing is available" = the engine answered and there is a local voice
/// for [languageTag]. Single source of truth for both `TablePage`
/// (`onVoiceAvailabilityChanged`) and `SettingsCubit`
/// (`VoiceAvailability`) — keeps the two from drifting apart
/// (`tasks.md` T021).
Future<bool> resolveVoiceAvailability(SpeechSynthesizer synthesizer, String languageTag) async {
  final result = await synthesizer.isAvailableFor(languageTag);
  return result.valueOrGet(() => false);
}
