import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:roundtablezoo/core/errors/app_failure.dart';
import 'package:roundtablezoo/domain/entities/character.dart';
import 'package:roundtablezoo/domain/entities/character_reaction.dart';
import 'package:roundtablezoo/domain/entities/day_key.dart';
import 'package:roundtablezoo/domain/value_objects/mood_score.dart';

part 'table_state.freezed.dart';

/// `TableCubit`'s state (`specs/004-table-screen/data-model.md` §3).
@freezed
sealed class TableState with _$TableState {
  const factory TableState.initial() = TableInitial;

  const factory TableState.loading() = TableLoading;

  const factory TableState.loaded(TableData data) = TableLoaded;

  /// Day/catalog **database** failed to load — the whole screen shows an
  /// error, unlike [TableData.readOnly] where the mood scale stays usable.
  /// A broken/missing character asset is a different case: it degrades
  /// [TableData.characters] to an empty list instead
  /// (`contracts/character-config.md` §3, FR-010d) — the mood scale keeps
  /// working, so it never reaches this state.
  const factory TableState.error(AppFailure failure) = TableError;
}

@freezed
abstract class TableData with _$TableData {
  const factory TableData({
    required DayKey dayKey,
    required String dayText,
    required bool isDayTextDirty,
    required bool readOnly,
    required List<Character> characters,
    required Map<String, CharacterSlot> slots,
    /// `null` until the entry for [dayKey] is created (no mood picked yet).
    int? entryId,
    MoodScore? moodScore,
  }) = _TableData;

  const TableData._();

  /// FR-014: a character can only be asked for a reaction once today's
  /// mood is picked and the day text isn't blank.
  bool get canRequestReaction => moodScore != null && dayText.trim().isNotEmpty && !readOnly;
}

/// One character's state at the table (data-model.md §3).
@freezed
sealed class CharacterSlot with _$CharacterSlot {
  const factory CharacterSlot.idle() = CharacterSlotIdle;

  /// A request is in flight (FR-016).
  const factory CharacterSlot.loading() = CharacterSlotLoading;

  const factory CharacterSlot.spoken(
    CharacterReaction reaction, {
    /// The reply predates the day text's current draft (FR-023); cleared
    /// by the next reply for this character (FR-023a). Always `false` for
    /// a reply restored from storage (FR-023b).
    @Default(false) bool stale,
    /// Loaded from storage on `load()`, not just received — shown fully
    /// formed, no reveal effect (FR-003b).
    @Default(false) bool restored,
    /// The reply was received but `addReaction` failed to save it
    /// (FR-021c); gone on the next `load()`.
    @Default(false) bool persistFailed,
  }) = CharacterSlotSpoken;
}

extension CharacterSlotX on CharacterSlot {
  /// Marks a `spoken` slot as referring to a previous version of the day
  /// text (FR-023); no-op for `idle`/`loading`.
  CharacterSlot markStale() => switch (this) {
    CharacterSlotSpoken(:final reaction, :final restored, :final persistFailed) => CharacterSlot.spoken(
      reaction,
      stale: true,
      restored: restored,
      persistFailed: persistFailed,
    ),
    CharacterSlotIdle() || CharacterSlotLoading() => this,
  };
}
