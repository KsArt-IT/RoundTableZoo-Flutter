import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:roundtablezoo/core/constants/mood_scale.dart';
import 'package:roundtablezoo/core/di/injection.dart';
import 'package:roundtablezoo/core/errors/app_failure.dart';
import 'package:roundtablezoo/domain/entities/day_key.dart';
import 'package:roundtablezoo/domain/value_objects/mood_score.dart';
import 'package:roundtablezoo/gen/app_localizations.dart';
import 'package:roundtablezoo/presentation/app_settings/cubit/current_day_cubit.dart';
import 'package:roundtablezoo/presentation/app_settings/cubit/current_day_state.dart';
import 'package:roundtablezoo/presentation/table/cubit/table_cubit.dart';
import 'package:roundtablezoo/presentation/table/cubit/table_state.dart';
import 'package:roundtablezoo/presentation/table/widgets/mood_scale_row.dart';

/// The `/table` screen — this is its US1 slice (mood tracking only; the
/// round table, text field and reactions join in later user stories).
///
/// Owns a fresh, screen-scoped `TableCubit` (research.md R5), same pattern
/// as `SettingsPage`. Failures surface inline, next to the mood scale, not
/// as a toast — the Table screen is explicitly not a "global notification"
/// surface (FR-029, data-model.md §3).
class TablePage extends StatefulWidget {
  const TablePage({super.key});

  @override
  State<TablePage> createState() => _TablePageState();
}

class _TablePageState extends State<TablePage> {
  late final TableCubit _cubit = getIt<TableCubit>();
  StreamSubscription<AppFailure>? _failureSubscription;
  AppFailure? _inlineFailure;

  @override
  void initState() {
    super.initState();
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
  void dispose() {
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
            appBar: AppBar(title: Text(l10n.sectionTable)),
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
  const _TableContent({required this.data, required this.inlineFailure, required this.onMoodSelected});

  final TableData data;
  final AppFailure? inlineFailure;
  final ValueChanged<MoodScale> onMoodSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final selected = data.moodScore == null ? null : MoodScale.fromValue(data.moodScore!.value);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          MoodScaleRow(selected: selected, onSelected: data.readOnly ? null : onMoodSelected),
          if (data.readOnly) ...[
            const SizedBox(height: 8),
            Text(
              l10n.storageReadOnly,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.error),
            ),
          ],
          if (inlineFailure != null) ...[
            const SizedBox(height: 8),
            Text(
              inlineFailure!.localizedMessage(l10n),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
    );
  }
}
