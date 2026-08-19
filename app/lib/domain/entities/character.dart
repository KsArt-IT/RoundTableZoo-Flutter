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

    /// ARGB, parsed from the asset's `#RRGGBB` string.
    required int colorHex,
    required String fallbackReply,
    required int maxReplyLength,
    String? idleAnimation,
    String? talkAnimation,
  }) = _Character;
}
