import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:roundtablezoo/core/errors/app_failure.dart';
import 'package:roundtablezoo/domain/entities/day_key.dart';
import 'package:roundtablezoo/domain/value_objects/mood_score.dart';

part 'table_state.freezed.dart';

/// `TableCubit`'s state (`specs/004-table-screen/data-model.md` §3). This is
/// the US1 slice — `characters`/`slots` join [TableData] in US2, once
/// character reactions exist.
@freezed
sealed class TableState with _$TableState {
  const factory TableState.initial() = TableInitial;

  const factory TableState.loading() = TableLoading;

  const factory TableState.loaded(TableData data) = TableLoaded;

  /// Day/catalog failed to load — the whole screen shows an error, unlike
  /// [TableData.readOnly] where the mood scale stays usable.
  const factory TableState.error(AppFailure failure) = TableError;
}

@freezed
abstract class TableData with _$TableData {
  const factory TableData({
    required DayKey dayKey,
    required String dayText,
    required bool isDayTextDirty,
    required bool readOnly,
    /// `null` until the entry for [dayKey] is created (no mood picked yet).
    int? entryId,
    MoodScore? moodScore,
  }) = _TableData;
}
