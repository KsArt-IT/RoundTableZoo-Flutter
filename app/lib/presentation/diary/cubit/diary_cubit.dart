import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:roundtablezoo/core/app_clock/app_clock.dart';
import 'package:roundtablezoo/core/constants/app_constants.dart';
import 'package:roundtablezoo/core/errors/app_failure.dart';
import 'package:roundtablezoo/core/sharing/share_service.dart';
import 'package:roundtablezoo/data/datasources/character_catalog.dart';
import 'package:roundtablezoo/domain/entities/character.dart';
import 'package:roundtablezoo/domain/repositories/diary_repository.dart';
import 'package:roundtablezoo/domain/usecases/export_diary_to_csv.dart';
import 'package:roundtablezoo/presentation/diary/cubit/diary_state.dart';

/// `/diary` screen cubit (contracts/diary-cubit.md). Screen-scoped
/// `@injectable` factory — a fresh instance per visit (research.md R14).
class DiaryCubit extends Cubit<DiaryState> {
  DiaryCubit({
    required DiaryRepository diaryRepository,
    required CharacterCatalog characterCatalog,
    required ExportDiaryToCsv exportDiaryToCsv,
    required ShareService shareService,
    required AppClock clock,
  }) : _diaryRepository = diaryRepository,
       _characterCatalog = characterCatalog,
       _exportDiaryToCsv = exportDiaryToCsv,
       _shareService = shareService,
       _clock = clock,
       super(const DiaryState.initial()) {
    _entriesSubscription = _diaryRepository.watchEntriesChanged().listen(_onEntriesChanged);
  }

  final DiaryRepository _diaryRepository;
  final CharacterCatalog _characterCatalog;
  final ExportDiaryToCsv _exportDiaryToCsv;
  final ShareService _shareService;
  final AppClock _clock;

  StreamSubscription<void>? _entriesSubscription;
  Timer? _refreshDebounce;

  /// `DiaryPage.nextCursor` from the most recently fetched page (US1
  /// implementation detail — never exposed in `DiaryData`, R2). Only
  /// `loadMore()`/`load()` advance it; `_refreshHead` (R12) must never
  /// touch it, or a background head refresh would rewind pagination
  /// progress and re-fetch already-loaded pages.
  DateTime? _nextCursor;

  final StreamController<AppFailure> _failures = StreamController<AppFailure>.broadcast();

  /// One-off signals that don't replace the whole screen: a failed
  /// reaction fetch, a failed export (contracts/diary-cubit.md §3).
  Stream<AppFailure> get failures => _failures.stream;

  /// `loading` → first page + `moodHistory()` + character catalog →
  /// `loaded`/`unavailable`/`error` (FR-001, FR-007, FR-008, FR-008a,
  /// FR-010, FR-029).
  Future<void> load() async {
    emit(const DiaryState.loading());

    final pageResult = await _diaryRepository.entriesPage(limit: AppConstants.diaryPageSize);
    if (isClosed) return;

    if (pageResult.isFailure) {
      final failure = pageResult.errorOrNull!;
      if (failure.code == DatabaseFailure.storageReadOnly) {
        emit(const DiaryState.unavailable());
      } else {
        emit(DiaryState.error(failure));
      }
      return;
    }
    final page = pageResult.valueOrNull!;
    _nextCursor = page.nextCursor;

    final chartResult = await _diaryRepository.moodHistory();
    if (isClosed) return;

    // A broken/missing character asset degrades to an empty map, not a
    // screen-wide error — the history stays readable, reactions just show
    // by `characterId` instead of a name (research.md R8, FR-019).
    final catalogResult = await _characterCatalog.load();
    if (isClosed) return;
    final characters = {
      for (final character in catalogResult.valueOrGet(() => const <Character>[]))
        character.id: character,
    };

    emit(
      DiaryState.loaded(
        DiaryData(
          days: [for (final record in page.days) DiaryDay(record: record)],
          chart: chartResult.valueOrGet(() => const []),
          characters: characters,
          hasMore: page.hasMore,
        ),
      ),
    );
  }

  /// Same as [load]; the retry button on the error banner (FR-008a).
  Future<void> retry() => load();

  /// Next page by [_nextCursor]; no-op while already loading or once
  /// `hasMore` is `false` (FR-004, FR-004a, FR-004b, FR-004c). A failure is
  /// recorded as `pageFailure`, not a screen-wide `error` — the days
  /// already shown must stay on screen (research.md R19).
  Future<void> loadMore() async {
    final current = state;
    if (current is! DiaryLoaded) return;
    final data = current.data;
    if (data.loadingMore || !data.hasMore) return;

    emit(DiaryState.loaded(data.copyWith(loadingMore: true)));

    final result = await _diaryRepository.entriesPage(
      beforeOccurredAt: _nextCursor,
      limit: AppConstants.diaryPageSize,
    );
    if (isClosed) return;

    final latest = state;
    if (latest is! DiaryLoaded) return;

    result.match(
      success: (page) {
        _nextCursor = page.nextCursor;
        final existingDays = {for (final d in latest.data.days) d.day};
        final merged = [
          ...latest.data.days,
          for (final record in page.days)
            if (!existingDays.contains(record.day)) DiaryDay(record: record),
        ];
        emit(
          DiaryState.loaded(
            latest.data.copyWith(
              days: merged,
              hasMore: page.hasMore,
              loadingMore: false,
              pageFailure: null,
            ),
          ),
        );
      },
      failure: (failure) {
        emit(DiaryState.loaded(latest.data.copyWith(loadingMore: false, pageFailure: failure)));
      },
    );
  }

  /// Inverts `expanded` for one day. On first expansion, lazily loads and
  /// caches its reactions (FR-014, FR-015, FR-018, research.md R7) — a
  /// fetch failure goes to [failures], not the screen state, so the list
  /// stays usable.
  Future<void> toggleDay(int entryId) async {
    final current = state;
    if (current is! DiaryLoaded) return;

    final index = current.data.days.indexWhere((d) => d.entryId == entryId);
    if (index == -1) return;
    final day = current.data.days[index];
    final expanded = !day.expanded;

    _replaceDay(index, day.copyWith(expanded: expanded));

    if (!expanded || day.reactions != null) return;

    final latest = state;
    if (latest is! DiaryLoaded) return;
    final loadingIndex = latest.data.days.indexWhere((d) => d.entryId == entryId);
    if (loadingIndex == -1) return;
    _replaceDay(loadingIndex, latest.data.days[loadingIndex].copyWith(reactionsLoading: true));

    final result = await _diaryRepository.reactionsFor(entryId);
    if (isClosed) return;

    final afterLoad = state;
    if (afterLoad is! DiaryLoaded) return;
    final loadedIndex = afterLoad.data.days.indexWhere((d) => d.entryId == entryId);
    if (loadedIndex == -1) return;

    result.match(
      success: (reactions) => _replaceDay(
        loadedIndex,
        afterLoad.data.days[loadedIndex].copyWith(reactionsLoading: false, reactions: reactions),
      ),
      failure: (failure) {
        _replaceDay(
          loadedIndex,
          afterLoad.data.days[loadedIndex].copyWith(reactionsLoading: false),
        );
        _publishFailure(failure);
      },
    );
  }

  /// Builds the CSV and hands it to `ShareService.shareCsv` (FR-020,
  /// FR-023, FR-024, FR-025). Cancelling the system share sheet isn't an
  /// error — `shareCsv` resolves normally either way, so `exporting` is
  /// simply cleared (research.md R19).
  Future<void> export() async {
    final current = state;
    if (current is! DiaryLoaded) return;
    if (!current.data.canExport) return;

    emit(DiaryState.loaded(current.data.copyWith(exporting: true)));

    final result = await _exportDiaryToCsv();
    if (isClosed) return;

    await result.match(
      success: (csv) async {
        final now = _clock.nowUtc();
        final stamp =
            '${now.year.toString().padLeft(4, '0')}-'
            '${now.month.toString().padLeft(2, '0')}-'
            '${now.day.toString().padLeft(2, '0')}';
        await _shareService.shareCsv(csv, fileName: 'roundtablezoo-$stamp.csv');
        if (isClosed) return;
        _setExporting(false);
      },
      failure: (failure) async {
        _setExporting(false);
        _publishFailure(failure);
      },
    );
  }

  void _setExporting(bool exporting) {
    final current = state;
    if (current is! DiaryLoaded) return;
    emit(DiaryState.loaded(current.data.copyWith(exporting: exporting)));
  }

  void _replaceDay(int index, DiaryDay day) {
    final current = state;
    if (current is! DiaryLoaded) return;
    final days = [...current.data.days];
    days[index] = day;
    emit(DiaryState.loaded(current.data.copyWith(days: days)));
  }

  void _publishFailure(AppFailure failure) {
    if (!_failures.isClosed) _failures.add(failure);
  }

  /// `watchEntriesChanged()` fired — debounced (`AppConstants
  /// .diaryRefreshDebounce`) because it's a raw Drift `watch()` and the
  /// Table screen's autosave can emit a burst of writes (research.md R12).
  void _onEntriesChanged(void _) {
    _refreshDebounce?.cancel();
    _refreshDebounce = Timer(AppConstants.diaryRefreshDebounce, () {
      unawaited(_refreshHead());
    });
  }

  /// Re-reads only the first page — old pages, expanded days and cached
  /// reactions are preserved by day key (research.md R12). Never touches
  /// [_nextCursor]: doing so would rewind `loadMore()` progress.
  Future<void> _refreshHead() async {
    final current = state;
    if (current is! DiaryLoaded) return;

    final pageResult = await _diaryRepository.entriesPage(limit: AppConstants.diaryPageSize);
    if (isClosed) return;
    final chartResult = await _diaryRepository.moodHistory();
    if (isClosed) return;

    final latest = state;
    if (latest is! DiaryLoaded) return;

    // A background refresh failure shouldn't clobber an already-working
    // screen (research.md R12 doesn't specify a UI for this case).
    if (pageResult.isFailure) return;
    final page = pageResult.valueOrNull!;

    final byDay = {for (final d in latest.data.days) d.day: d};
    final headDays = [
      for (final record in page.days)
        (byDay[record.day] ?? DiaryDay(record: record)).copyWith(record: record),
    ];
    final headKeys = headDays.map((d) => d.day).toSet();
    final tailDays = latest.data.days.where((d) => !headKeys.contains(d.day));
    emit(
      DiaryState.loaded(
        latest.data.copyWith(
          days: [...headDays, ...tailDays],
          chart: chartResult.valueOrGet(() => latest.data.chart),
        ),
      ),
    );
  }

  @override
  Future<void> close() async {
    _refreshDebounce?.cancel();
    await _entriesSubscription?.cancel();
    await _failures.close();
    return super.close();
  }
}
