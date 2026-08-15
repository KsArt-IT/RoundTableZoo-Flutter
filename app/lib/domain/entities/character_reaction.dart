import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:roundtablezoo/domain/value_objects/reaction_tone.dart';

part 'character_reaction.freezed.dart';

/// A character's reply to a diary entry.
@freezed
abstract class CharacterReaction with _$CharacterReaction {
  const factory CharacterReaction({
    required int dayEntryId,
    required String characterId,
    required ReactionTone tone,
    required String reply,
    /// Animation amplitude, 0.0..1.0.
    required double intensity,
    required bool isFallback,
    required DateTime createdAt,
    /// `null` until the reaction is persisted.
    int? id,
  }) = _CharacterReaction;
}
