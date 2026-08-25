import 'package:freezed_annotation/freezed_annotation.dart';

part 'character_voice.freezed.dart';

/// One character's speech timbre — pitch and rate for `FlutterTts`
/// (`data-model.md` §1). Values are platform-neutral: they go into
/// `setPitch`/`setSpeechRate` as-is.
@freezed
abstract class CharacterVoice with _$CharacterVoice {
  const factory CharacterVoice({
    /// 0.5 … 2.0; 1.0 is the normal pitch.
    required double pitch,

    /// 0.0 … 1.0; 0.5 is the normal rate on both platforms.
    required double rate,
  }) = _CharacterVoice;

  /// Used when a character's JSON entry has no `voice` (or a broken one) —
  /// the config degrades to neutral speech rather than failing the whole
  /// catalog (`contracts/character-voice-config.md` §1).
  static const neutral = CharacterVoice(pitch: 1, rate: 0.5);
}
