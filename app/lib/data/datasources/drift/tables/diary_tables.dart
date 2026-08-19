import 'package:drift/drift.dart';

/// One diary entry per row. The calendar "day" it belongs to is *not*
/// stored — it's derived from [DayEntries.occurredAt] via `DayResolver`
/// (FR-009), so there is deliberately no unique index on a day column here.
@DataClassName('DayEntryRow')
@TableIndex(name: 'idx_day_entries_occurred_at', columns: {#occurredAt})
class DayEntries extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// UTC instant the entry refers to.
  DateTimeColumn get occurredAt => dateTime()();

  /// Explicit emoji-scale score, 1..5 — never derived from reaction tone.
  IntColumn get moodScore =>
      integer().check(moodScore.isBiggerOrEqualValue(1) & moodScore.isSmallerOrEqualValue(5))();

  TextColumn get dayText => text().withLength(max: 2000).nullable()();

  DateTimeColumn get createdAt => dateTime()();

  DateTimeColumn get updatedAt => dateTime()();
}

@DataClassName('CharacterReactionRow')
@TableIndex(name: 'idx_character_reactions_day_entry', columns: {#dayEntryId})
class CharacterReactions extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get dayEntryId => integer().references(DayEntries, #id, onDelete: KeyAction.cascade)();

  /// Static character config id (`'cat' | 'dog' | 'crocodile' | 'hippo' | …`) — not a table FK.
  TextColumn get characterId => text()();

  /// `ReactionTone.name`; unknown values are mapped to `neutral` by the
  /// mapper before they ever reach this column (FR-010b).
  TextColumn get tone => text().withDefault(const Constant('neutral'))();

  TextColumn get reply => text()();

  /// Animation amplitude, 0.0..1.0.
  RealColumn get intensity =>
      real().check(intensity.isBiggerOrEqualValue(0.0) & intensity.isSmallerOrEqualValue(1.0))();

  BoolColumn get isFallback => boolean().withDefault(const Constant(false))();

  DateTimeColumn get createdAt => dateTime()();
}
