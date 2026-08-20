import 'package:freezed_annotation/freezed_annotation.dart';

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

    /// ARGB, parsed from the asset's `#RRGGBB` string.
    required int colorHex,
    required String fallbackReply,
    required int maxReplyLength,
    String? idleAnimation,
    String? talkAnimation,
  }) = _Character;
}
