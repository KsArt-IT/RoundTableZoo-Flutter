import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:roundtablezoo/core/constants/mood_scale.dart';
import 'package:roundtablezoo/core/di/injection.dart';
import 'package:roundtablezoo/core/errors/app_failure.dart';
import 'package:roundtablezoo/domain/entities/character.dart';
import 'package:roundtablezoo/domain/entities/day_key.dart';
import 'package:roundtablezoo/domain/value_objects/mood_score.dart';
import 'package:roundtablezoo/gen/app_localizations.dart';
import 'package:roundtablezoo/presentation/app_settings/cubit/current_day_cubit.dart';
import 'package:roundtablezoo/presentation/app_settings/cubit/current_day_state.dart';
import 'package:roundtablezoo/presentation/table/cubit/table_cubit.dart';
import 'package:roundtablezoo/presentation/table/cubit/table_state.dart';
import 'package:roundtablezoo/presentation/table/widgets/character_avatar.dart';
import 'package:roundtablezoo/presentation/table/widgets/day_text_field.dart';
import 'package:roundtablezoo/presentation/table/widgets/mood_scale_row.dart';
import 'package:roundtablezoo/presentation/table/widgets/round_table_layout.dart';
import 'package:roundtablezoo/presentation/table/widgets/speaking_bubble.dart';

/// The `/table` screen: round table on top, mood scale and day text at the
/// bottom (US1+US2 — restoring past reactions, generation-counted retaps
/// and AI-failure fallbacks join in later user stories).
///
/// No app bar — the table itself is the screen, and every bit of vertical
/// space goes to it and to the reply bubbles.
///
/// Owns a fresh, screen-scoped `TableCubit` (research.md R5), same pattern
/// as `SettingsPage`. Failures surface inline, next to the relevant part
/// of the screen, not as a toast — the Table screen is explicitly not a
/// "global notification" surface (FR-029, data-model.md §3).
class TablePage extends StatefulWidget {
  const TablePage({super.key});

  @override
  State<TablePage> createState() => _TablePageState();
}

class _TablePageState extends State<TablePage> with WidgetsBindingObserver {
  late final TableCubit _cubit = getIt<TableCubit>();
  StreamSubscription<AppFailure>? _failureSubscription;
  AppFailure? _inlineFailure;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _failureSubscription = _cubit.failures.listen((failure) {
      if (!mounted) return;
      setState(() => _inlineFailure = failure);
    });
    unawaited(_cubit.load(_currentDayKey));
  }

  /// `CurrentDayCubit` resolves synchronously on construction (its own
  /// doc comment: `.initial()` is "never observed outside cubit
  /// construction") — by the time this widget builds, it's always already
  /// `.day(...)`.
  DayKey get _currentDayKey => switch (context.read<CurrentDayCubit>().state) {
    CurrentDayDay(:final key) => key,
    CurrentDayInitial() => throw StateError('CurrentDayCubit has not resolved a day yet'),
  };

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // research.md R10 — a backgrounded app must not lose an unsaved edit.
    if (state == AppLifecycleState.paused) unawaited(_cubit.flushDayText());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_failureSubscription?.cancel());
    unawaited(_cubit.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return BlocProvider.value(
      value: _cubit,
      child: BlocConsumer<TableCubit, TableState>(
        // A fresh `loaded` state means the last write succeeded — clears a
        // stale failure banner without a separate success signal.
        listener: (context, state) {
          if (state is TableLoaded && _inlineFailure != null) {
            setState(() => _inlineFailure = null);
          }
        },
        builder: (context, state) {
          return Scaffold(
            body: SafeArea(
              child: switch (state) {
                TableInitial() || TableLoading() => const Center(child: CircularProgressIndicator()),
                TableError(:final failure) => Center(child: Text(failure.localizedMessage(l10n))),
                TableLoaded(:final data) => _TableContent(
                  data: data,
                  inlineFailure: _inlineFailure,
                  onMoodSelected: (option) => unawaited(
                    _cubit.setMood(
                      MoodScore.create(
                        option.value,
                      ).valueOrGet(() => throw StateError('MoodScale.value is always 1..5')),
                    ),
                  ),
                  onDayTextChanged: _cubit.onDayTextChanged,
                  onCharacterTap: (characterId) => unawaited(_cubit.requestReaction(characterId)),
                ),
              },
            ),
          );
        },
      ),
    );
  }
}

class _TableContent extends StatelessWidget {
  const _TableContent({
    required this.data,
    required this.inlineFailure,
    required this.onMoodSelected,
    required this.onDayTextChanged,
    required this.onCharacterTap,
  });

  final TableData data;
  final AppFailure? inlineFailure;
  final ValueChanged<MoodScale> onMoodSelected;
  final ValueChanged<String> onDayTextChanged;
  final ValueChanged<String> onCharacterTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final selected = data.moodScore == null ? null : MoodScale.fromValue(data.moodScore!.value);
    final errorStyle = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.error);

    return Column(
      children: [
        // Full width, no side padding — a reply bubble spans the whole
        // screen, not just the seat it belongs to.
        Expanded(
          child: data.characters.isEmpty
              ? const SizedBox.shrink()
              : _RoundTable(
                  characters: data.characters,
                  slots: data.slots,
                  canTap: data.canRequestReaction,
                  onCharacterTap: onCharacterTap,
                ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              MoodScaleRow(selected: selected, onSelected: data.readOnly ? null : onMoodSelected),
              // FR-014a: the missing-precondition hint sits next to
              // whichever element is actually missing, never as a popup.
              if (data.moodScore == null) ...[
                const SizedBox(height: 4),
                Text(l10n.tableNeedMoodHint, style: errorStyle, textAlign: TextAlign.center),
              ],
              if (data.readOnly) ...[
                const SizedBox(height: 8),
                Text(l10n.storageReadOnly, style: errorStyle),
              ],
              const SizedBox(height: 12),
              DayTextField(text: data.dayText, onChanged: onDayTextChanged, enabled: !data.readOnly),
              if (data.moodScore != null && data.dayText.trim().isEmpty) ...[
                const SizedBox(height: 4),
                Text(l10n.tableNeedTextHint, style: errorStyle, textAlign: TextAlign.center),
              ],
              if (inlineFailure != null) ...[
                const SizedBox(height: 8),
                Text(inlineFailure!.localizedMessage(l10n), style: errorStyle),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// The circle of characters and their bubbles. A single `State` (rather
/// than one per seat) tracks which characters are still mid-reveal, since
/// `RoundTableLayout` now renders each bubble as its own full-width layer
/// rather than nesting it under its avatar (`RoundTableSeat`) — nothing
/// keeps an avatar and its bubble in the same subtree for a shared
/// per-seat `State` to live in anymore.
class _RoundTable extends StatefulWidget {
  const _RoundTable({
    required this.characters,
    required this.slots,
    required this.canTap,
    required this.onCharacterTap,
  });

  final List<Character> characters;
  final Map<String, CharacterSlot> slots;
  final bool canTap;
  final ValueChanged<String> onCharacterTap;

  @override
  State<_RoundTable> createState() => _RoundTableState();
}

class _RoundTableState extends State<_RoundTable> {
  final Map<String, bool> _revealing = {};

  /// The character most recently tapped — its bubble paints on top of the
  /// others (RoundTableLayout.activeCharacterId), so it's never hidden
  /// under a neighboring seat's still-visible reply.
  String? _activeCharacterId;

  @override
  void didUpdateWidget(covariant _RoundTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    for (final character in widget.characters) {
      final slot = widget.slots[character.id];
      final oldSlot = oldWidget.slots[character.id];
      if (slot is CharacterSlotSpoken && !slot.restored && oldSlot is! CharacterSlotSpoken) {
        _revealing[character.id] = true;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return RoundTableLayout(
      activeCharacterId: _activeCharacterId,
      seats: [for (final character in widget.characters) _seatFor(character)],
    );
  }

  RoundTableSeat _seatFor(Character character) {
    final slot = widget.slots[character.id] ?? const CharacterSlot.idle();
    final isRevealing = _revealing[character.id] ?? (slot is CharacterSlotSpoken && !slot.restored);
    final visualState = switch (slot) {
      CharacterSlotIdle() => CharacterVisualState.idle,
      CharacterSlotLoading() => CharacterVisualState.waiting,
      CharacterSlotSpoken() => isRevealing ? CharacterVisualState.speaking : CharacterVisualState.answered,
    };

    return RoundTableSeat(
      characterId: character.id,
      avatar: CharacterAvatar(
        key: ValueKey('avatar-${character.id}'),
        character: character,
        state: visualState,
        onTap: widget.canTap
            ? () {
                setState(() => _activeCharacterId = character.id);
                widget.onCharacterTap(character.id);
              }
            : null,
      ),
      bubble: switch (slot) {
        CharacterSlotSpoken(:final reaction, :final stale, :final restored) => SpeakingBubble(
          key: ValueKey('bubble-${character.id}-${reaction.id ?? reaction.createdAt}'),
          reaction: reaction,
          stale: stale,
          restored: restored,
          onRevealed: () {
            if (mounted) setState(() => _revealing[character.id] = false);
          },
        ),
        CharacterSlotIdle() || CharacterSlotLoading() => null,
      },
    );
  }
}
