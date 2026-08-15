import 'package:drift/drift.dart';
import 'package:roundtablezoo/data/datasources/drift/app_database.dart';
import 'package:roundtablezoo/domain/entities/character_reaction.dart';
import 'package:roundtablezoo/domain/value_objects/reaction_tone.dart';

extension CharacterReactionRowMapper on CharacterReactionRow {
  CharacterReaction toEntity() => CharacterReaction(
    id: id,
    dayEntryId: dayEntryId,
    characterId: characterId,
    // Unknown/legacy tone values fall back to neutral rather than failing
    // the read (FR-010b).
    tone: ReactionTone.fromStorage(tone),
    reply: reply,
    intensity: intensity,
    isFallback: isFallback,
    // See day_entry_mapper.dart — sqlite3/drift drops the UTC flag on read.
    createdAt: createdAt.toUtc(),
  );
}

extension CharacterReactionCompanionMapper on CharacterReaction {
  CharacterReactionsCompanion toInsertCompanion() => CharacterReactionsCompanion.insert(
    dayEntryId: dayEntryId,
    characterId: characterId,
    tone: Value(tone.name),
    reply: reply,
    intensity: intensity,
    isFallback: Value(isFallback),
    createdAt: createdAt,
  );
}
