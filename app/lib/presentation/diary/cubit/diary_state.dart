import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:roundtablezoo/core/errors/app_failure.dart';
import 'package:roundtablezoo/domain/entities/character.dart';
import 'package:roundtablezoo/domain/entities/character_reaction.dart';
import 'package:roundtablezoo/domain/entities/day_entry.dart';
import 'package:roundtablezoo/domain/entities/day_key.dart';
import 'package:roundtablezoo/domain/entities/diary_day_entry.dart';
import 'package:roundtablezoo/domain/entities/mood_chart_point.dart';

part 'diary_state.freezed.dart';

/// `/diary` screen state (data-model.md §4).
@freezed
sealed class DiaryState with _$DiaryState {
  const factory DiaryState.initial() = DiaryInitial;

  const factory DiaryState.loading() = DiaryLoading; // FR-008

  const factory DiaryState.loaded(DiaryData data) = DiaryLoaded;

  /// `StorageMode.readOnly` — distinct from an empty history (FR-029,
  /// research.md R13).
  const factory DiaryState.unavailable() = DiaryUnavailable;

  /// First-load failure other than `storageReadOnly` (FR-008a).
  const factory DiaryState.error(AppFailure failure) = DiaryError;
}

@freezed
abstract class DiaryData with _$DiaryData {
  const factory DiaryData({
    required List<DiaryDay> days, // newest first (FR-001)
    required List<MoodChartPoint> chart, // full history (FR-010)
    required Map<String, Character> characters, // reaction captions (FR-016, R8)
    required bool hasMore, // FR-004c
    @Default(false) bool loadingMore, // FR-004a
    @Default(false) bool exporting, // blocks a repeat tap
    AppFailure? pageFailure, // loadMore() failure (research.md R19, CHK006)
  }) = _DiaryData;

  const DiaryData._();

  bool get isEmpty => days.isEmpty; // FR-007

  bool get canExport => days.isNotEmpty && !exporting; // FR-024
}

/// One list card: a day's entry plus everything needed to render it.
@freezed
abstract class DiaryDay with _$DiaryDay {
  const factory DiaryDay({
    required DiaryDayEntry record, // day + entry, as the repository returned it
    @Default(false) bool expanded, // FR-014: one disclosure per card (R7)
    @Default(false) bool reactionsLoading,
    List<CharacterReaction>? reactions, // null = never fetched (R7)
  }) = _DiaryDay;

  const DiaryDay._();

  DayKey get day => record.day;

  DayEntry get entry => record.entry;

  /// Force-unwrap is safe: a [DiaryDay] is only ever built from rows that
  /// already came out of the database, and `DayEntry.id` is `null` only
  /// before the first save (constitution §VI requires this justification
  /// in code, not just in review).
  int get entryId => record.entry.id!;
}
