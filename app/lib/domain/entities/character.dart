import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:roundtablezoo/domain/value_objects/character_voice.dart';
import 'package:roundtablezoo/domain/value_objects/face_shape.dart';

part 'character.freezed.dart';

/// Static configuration for one animal at the table — not a database row.
/// Loaded from `assets/characters/characters.json` by `CharacterCatalog`
/// (`specs/004-table-screen/contracts/character-config.md`).
@freezed
abstract class Character with _$Character {
  const factory Character({
    required String id,
    required String name,

    /// Shown inside the static avatar instead of the name's first letter
    /// when present — a zero-asset stand-in until real character art
    /// exists (`contracts/character-config.md` §5). Optional: absent falls
    /// back to the letter, so an incomplete roster still renders.
    String? emoji,

    /// Which vector face this character is drawn with. `null` — the
    /// character has no drawn face yet and keeps the [emoji] avatar
    /// (`contracts/character-config.md` §5).
    FaceShape? face,

    /// ARGB, parsed from the asset's `#RRGGBB` string.
    required int colorHex,
    required String fallbackReply,
    required int maxReplyLength,

    /// Speech timbre (FR-003). Optional in the JSON asset, defaults to
    /// `CharacterVoice.neutral` — required here because every character
    /// has *some* voice, even an unconfigured one.
    required CharacterVoice voice,
    String? idleAnimation,
    String? talkAnimation,
  }) = _Character;
}
