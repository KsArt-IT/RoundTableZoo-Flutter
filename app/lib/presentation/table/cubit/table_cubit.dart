import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:roundtablezoo/core/app_clock/app_clock.dart';
import 'package:roundtablezoo/core/bootstrap/storage_mode.dart';
import 'package:roundtablezoo/core/constants/app_constants.dart';
import 'package:roundtablezoo/core/errors/app_failure.dart';
import 'package:roundtablezoo/data/datasources/character_catalog.dart';
import 'package:roundtablezoo/domain/entities/character.dart';
import 'package:roundtablezoo/domain/entities/character_reaction.dart';
import 'package:roundtablezoo/domain/entities/day_key.dart';
import 'package:roundtablezoo/domain/entities/user_settings.dart';
import 'package:roundtablezoo/domain/repositories/ai_reaction_repository.dart';
import 'package:roundtablezoo/domain/repositories/diary_repository.dart';
import 'package:roundtablezoo/domain/repositories/settings_repository.dart';
import 'package:roundtablezoo/domain/value_objects/mood_score.dart';
import 'package:roundtablezoo/domain/value_objects/reaction_tone.dart';
import 'package:roundtablezoo/presentation/table/cubit/table_state.dart';

/// `/table` screen cubit (`specs/004-table-screen/contracts/table-cubit.md`).
/// Screen-scoped — a fresh instance per visit (research.md R5), same
/// reasoning as `SettingsCubit`; no other cubit among its dependencies
/// (principle I) — `TablePage` reads `CurrentDayCubit` itself and passes
/// the resolved [DayKey] in, rather than this cubit re-deriving "today".
///
/// This is the US1+US2 slice of the full contract: mood, day text and
/// reactions on the basic (non-racing) path. The generation counter for
/// overlapping/repeated taps on the same character joins in US3
/// (tasks.md T053).
class TableCubit extends Cubit<TableState> {
  TableCubit({
    required DiaryRepository diaryRepository,
    required SettingsRepository settingsRepository,
    required AiReactionRepository aiReactionRepository,
    required CharacterCatalog characterCatalog,
    required AppClock clock,
    required StorageMode storageMode,
  }) : _diaryRepository = diaryRepository,
       _settingsRepository = settingsRepository,
       _aiReactionRepository = aiReactionRepository,
       _characterCatalog = characterCatalog,
       _clock = clock,
       _readOnly = storageMode == StorageMode.readOnly,
       super(const TableState.initial()) {
    _settingsSubscription = _settingsRepository.watch().listen(_onSettingsChanged);
  }

  final DiaryRepository _diaryRepository;
  final SettingsRepository _settingsRepository;
  final AiReactionRepository _aiReactionRepository;
  final CharacterCatalog _characterCatalog;
  final AppClock _clock;
  final bool _readOnly;

  late final StreamSubscription<UserSettings> _settingsSubscription;
  List<Character> _catalog = const [];
  List<String> _enabledCharacterIds = const [];
  Timer? _debounceTimer;

  final StreamController<AppFailure> _failures = StreamController<AppFailure>.broadcast();

  /// One-off signals: a failed `setMood`/text save, a blocked
  /// `requestReaction` precondition, or a `network`/`rateLimited`/
  /// `aiDisabled` reaction failure. `TablePage` shows these inline, next to
  /// the mood scale or the relevant character — never a global toast
  /// (FR-029).
  Stream<AppFailure> get failures => _failures.stream;

  /// Loads the entry for [dayKey] — the current day, as resolved by
  /// `CurrentDayCubit` (principle IV: not re-derived here) — the character
  /// catalog and the currently-enabled roster. Reactions aren't restored
  /// yet in this slice (US3, tasks.md T054): every slot starts `idle`.
  Future<void> load(DayKey dayKey) async {
    emit(const TableState.loading());

    final entryResult = await _diaryRepository.entryForDay(dayKey);
    if (isClosed) return;
    if (entryResult.isFailure) {
      emit(TableState.error(entryResult.errorOrNull!));
      return;
    }
    final entry = entryResult.valueOrNull;

    // A broken/missing character asset degrades to an empty table, not a
    // screen-wide error — the mood scale must keep working
    // (contracts/character-config.md §3, FR-010d).
    final catalogResult = await _characterCatalog.load();
    if (isClosed) return;
    _catalog = catalogResult.valueOrGet(() => const []);

    final settingsResult = await _settingsRepository.load();
    if (isClosed) return;
    _enabledCharacterIds = settingsResult.valueOrNull?.enabledCharacterIds ?? const [];

    final characters = _filteredCharacters();
    emit(
      TableState.loaded(
        TableData(
          dayKey: dayKey,
          dayText: entry?.dayText ?? '',
          isDayTextDirty: false,
          readOnly: _readOnly,
          entryId: entry?.id,
          moodScore: entry?.moodScore,
          characters: characters,
          slots: {for (final c in characters) c.id: const CharacterSlot.idle()},
        ),
      ),
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
        _debounceTimer?.cancel();
        emit(
          TableState.loaded(
            latest.data.copyWith(
              entryId: entry.id,
              moodScore: entry.moodScore,
              dayText: entry.dayText ?? '',
              isDayTextDirty: false,
            ),
          ),
        );
      },
      failure: _publishFailure,
    );
  }

  /// Updates the draft text, debouncing autosave (FR-008a). Any already
  /// received reply is marked as referring to the text-before-this-edit
  /// (FR-023) — cleared by that character's next reply (FR-023a).
  void onDayTextChanged(String text) {
    final current = state;
    if (current is! TableLoaded || current.data.readOnly) return;

    emit(
      TableState.loaded(
        current.data.copyWith(
          dayText: text,
          isDayTextDirty: true,
          slots: current.data.slots.map((id, slot) => MapEntry(id, slot.markStale())),
        ),
      ),
    );

    _debounceTimer?.cancel();
    _debounceTimer = Timer(AppConstants.dayTextAutosaveDebounce, () => unawaited(flushDayText()));
  }

  /// Forces the debounced text save to run now — called from [close], on
  /// `AppLifecycleState.paused` (`TablePage`) and before every
  /// `requestReaction` (research.md R10). A no-op unless there's an actual
  /// unsaved edit; deferred entirely until a mood exists to attach it to
  /// (FR-008c — `saveTodayEntry` always writes both together).
  Future<void> flushDayText() async {
    _debounceTimer?.cancel();
    _debounceTimer = null;

    final current = state;
    if (current is! TableLoaded) return;
    if (!current.data.isDayTextDirty || current.data.readOnly) return;
    if (current.data.moodScore == null) return;

    final text = current.data.dayText;
    final result = await _diaryRepository.saveTodayEntry(
      moodScore: current.data.moodScore!,
      dayText: text.isEmpty ? null : text,
    );
    if (isClosed) return;

    result.match(
      success: (entry) {
        final latest = state;
        if (latest is! TableLoaded) return;
        emit(
          TableState.loaded(
            latest.data.copyWith(entryId: entry.id, dayText: entry.dayText ?? '', isDayTextDirty: false),
          ),
        );
      },
      failure: _publishFailure,
    );
  }

  /// Requests [characterId]'s reaction to the current day text
  /// (`contracts/table-cubit.md` §3, basic path — no generation counter
  /// yet). Preconditions (FR-014) block the request and publish a signal
  /// instead of silently doing nothing.
  Future<void> requestReaction(String characterId) async {
    await flushDayText();
    if (isClosed) return;

    final loaded = state;
    if (loaded is! TableLoaded) return;
    final data = loaded.data;

    if (data.readOnly) {
      _publishFailure(const DatabaseFailure(null, code: DatabaseFailure.storageReadOnly));
      return;
    }
    final moodScore = data.moodScore;
    final entryId = data.entryId;
    if (moodScore == null || entryId == null) {
      _publishFailure(const ValidationFailure(null, code: ValidationFailure.moodNotSelected));
      return;
    }
    final dayText = data.dayText;
    if (dayText.trim().isEmpty) {
      _publishFailure(const ValidationFailure(null, code: ValidationFailure.dayTextEmpty));
      return;
    }

    final previousSlot = data.slots[characterId] ?? const CharacterSlot.idle();
    emit(TableState.loaded(data.copyWith(slots: {...data.slots, characterId: const CharacterSlot.loading()})));

    final result = await _aiReactionRepository.requestReaction(
      characterId: characterId,
      dayText: dayText,
      dayEntryId: entryId,
    );
    if (isClosed) return;

    await result.match(
      success: (reaction) => _persistReaction(characterId, reaction),
      failure: (failure) => _handleReactionFailure(characterId, failure, previousSlot, entryId: entryId),
    );
  }

  Future<void> _handleReactionFailure(
    String characterId,
    AppFailure failure,
    CharacterSlot previousSlot, {
    required int entryId,
  }) async {
    final isFallbackCase =
        failure is AiProxyFailure &&
        (failure.code == AiProxyFailure.invalidResponse || failure.code == AiProxyFailure.timeout);
    if (!isFallbackCase) {
      _revertSlot(characterId, previousSlot, failure);
      return;
    }

    final character = _catalog.firstWhereOrNull((c) => c.id == characterId);
    if (character == null) {
      _revertSlot(characterId, previousSlot, failure);
      return;
    }

    await _persistReaction(
      characterId,
      CharacterReaction(
        dayEntryId: entryId,
        characterId: characterId,
        tone: ReactionTone.neutral,
        reply: character.fallbackReply,
        intensity: 0.5,
        isFallback: true,
        createdAt: _clock.nowUtc(),
      ),
    );
  }

  Future<void> _persistReaction(String characterId, CharacterReaction reaction) async {
    final result = await _diaryRepository.addReaction(reaction);
    if (isClosed) return;
    final current = state;
    if (current is! TableLoaded) return;

    result.match(
      success: (saved) => emit(
        TableState.loaded(
          current.data.copyWith(slots: {...current.data.slots, characterId: CharacterSlot.spoken(saved)}),
        ),
      ),
      failure: (failure) {
        emit(
          TableState.loaded(
            current.data.copyWith(
              slots: {
                ...current.data.slots,
                characterId: CharacterSlot.spoken(reaction, persistFailed: true),
              },
            ),
          ),
        );
        _publishFailure(failure);
      },
    );
  }

  void _revertSlot(String characterId, CharacterSlot previous, AppFailure failure) {
    final current = state;
    if (current is! TableLoaded) return;
    emit(TableState.loaded(current.data.copyWith(slots: {...current.data.slots, characterId: previous})));
    _publishFailure(failure);
  }

  void _publishFailure(AppFailure failure) {
    if (!_failures.isClosed) _failures.add(failure);
  }

  /// The table's roster changed (settings edited elsewhere, e.g.
  /// `/settings`) — recomputed without leaving `/table` (FR-010, FR-010c).
  /// A disabled character's bubble disappears; its reactions stay in
  /// storage untouched.
  void _onSettingsChanged(UserSettings settings) {
    _enabledCharacterIds = settings.enabledCharacterIds;
    final current = state;
    if (current is! TableLoaded) return;

    final characters = _filteredCharacters();
    if (const ListEquality<Character>().equals(characters, current.data.characters)) return;

    final slots = {for (final c in characters) c.id: current.data.slots[c.id] ?? const CharacterSlot.idle()};
    emit(TableState.loaded(current.data.copyWith(characters: characters, slots: slots)));
  }

  List<Character> _filteredCharacters() =>
      _catalog.where((c) => _enabledCharacterIds.contains(c.id)).toList(growable: false);

  @override
  Future<void> close() async {
    await flushDayText();
    _debounceTimer?.cancel();
    await _settingsSubscription.cancel();
    await _failures.close();
    return super.close();
  }
}
