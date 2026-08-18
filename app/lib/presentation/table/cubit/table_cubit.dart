import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:roundtablezoo/core/bootstrap/storage_mode.dart';
import 'package:roundtablezoo/core/errors/app_failure.dart';
import 'package:roundtablezoo/domain/entities/day_key.dart';
import 'package:roundtablezoo/domain/repositories/diary_repository.dart';
import 'package:roundtablezoo/domain/value_objects/mood_score.dart';
import 'package:roundtablezoo/presentation/table/cubit/table_state.dart';

/// `/table` screen cubit (`specs/004-table-screen/contracts/table-cubit.md`).
/// Screen-scoped — a fresh instance per visit (research.md R5), same
/// reasoning as `SettingsCubit`; no other cubit among its dependencies
/// (principle I) — `TablePage` reads `CurrentDayCubit` itself and passes
/// the resolved [DayKey] in, rather than this cubit re-deriving "today".
///
/// This is the US1 slice of the full contract: mood tracking only.
/// `SettingsRepository`, `AiReactionRepository`, `CharacterCatalog` and
/// `AppClock` join the constructor in US2 (tasks.md T041a/T043), once text
/// autosave and character reactions exist — nothing here needs them yet.
class TableCubit extends Cubit<TableState> {
  TableCubit({required DiaryRepository diaryRepository, required StorageMode storageMode})
    : _diaryRepository = diaryRepository,
      _readOnly = storageMode == StorageMode.readOnly,
      super(const TableState.initial());

  final DiaryRepository _diaryRepository;
  final bool _readOnly;

  final StreamController<AppFailure> _failures = StreamController<AppFailure>.broadcast();

  /// One-off signals: a failed `setMood` write. `TablePage` shows these
  /// inline, next to the mood scale — never a global toast (FR-029).
  Stream<AppFailure> get failures => _failures.stream;

  /// Loads the entry for [dayKey] — the current day, as resolved by
  /// `CurrentDayCubit` (principle IV: not re-derived here).
  Future<void> load(DayKey dayKey) async {
    emit(const TableState.loading());

    final result = await _diaryRepository.entryForDay(dayKey);
    if (isClosed) return;

    result.match(
      success: (entry) => emit(
        TableState.loaded(
          TableData(
            dayKey: dayKey,
            dayText: entry?.dayText ?? '',
            isDayTextDirty: false,
            readOnly: _readOnly,
            entryId: entry?.id,
            moodScore: entry?.moodScore,
          ),
        ),
      ),
      failure: (failure) => emit(TableState.error(failure)),
    );
  }

  /// Saves [score] as today's mood, alongside whatever day text is
  /// currently held (unsaved or not — FR-008c carries it along). No-op in
  /// read-only mode: nothing here pretends to persist (FR-032).
  Future<void> setMood(MoodScore score) async {
    final current = state;
    if (current is! TableLoaded || current.data.readOnly) return;

    final draftText = current.data.dayText;
    final result = await _diaryRepository.saveTodayEntry(
      moodScore: score,
      dayText: draftText.isEmpty ? null : draftText,
    );
    if (isClosed) return;

    result.match(
      success: (entry) {
        final latest = state;
        if (latest is! TableLoaded) return;
        emit(
          TableState.loaded(
            latest.data.copyWith(entryId: entry.id, moodScore: entry.moodScore, dayText: entry.dayText ?? ''),
          ),
        );
      },
      failure: (failure) {
        if (!_failures.isClosed) _failures.add(failure);
      },
    );
  }

  @override
  Future<void> close() async {
    await _failures.close();
    return super.close();
  }
}
