import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:roundtablezoo/core/constants/app_constants.dart';
import 'package:roundtablezoo/core/di/injection.dart';
import 'package:roundtablezoo/gen/app_localizations.dart';
import 'package:roundtablezoo/presentation/diary/cubit/diary_cubit.dart';
import 'package:roundtablezoo/presentation/diary/cubit/diary_state.dart';
import 'package:roundtablezoo/presentation/diary/widgets/diary_day_card.dart';
import 'package:roundtablezoo/presentation/diary/widgets/diary_empty_view.dart';
import 'package:roundtablezoo/presentation/diary/widgets/diary_error_view.dart';
import 'package:roundtablezoo/presentation/diary/widgets/mood_chart.dart';

/// The `/diary` screen: paginated history list, mood chart, per-day
/// character reactions and CSV export.
///
/// Owns a fresh, screen-scoped `DiaryCubit` (research.md R14), same
/// pattern as `TablePage`/`SettingsPage`.
class DiaryPage extends StatelessWidget {
  const DiaryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<DiaryCubit>()..load(),
      child: const _DiaryView(),
    );
  }
}

class _DiaryView extends StatelessWidget {
  const _DiaryView();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return BlocBuilder<DiaryCubit, DiaryState>(
      builder: (context, state) => Scaffold(
        appBar: state is DiaryLoaded
            ? AppBar(
                title: Text(l10n.sectionDiary),
                actions: [
                  // FR-024, FR-030, research.md R19: visible and disabled
                  // (never hidden) so the action is still discoverable when
                  // the history is empty. `tooltip` (not a wrapping
                  // `Semantics`) is what actually reaches the tappable
                  // node's label — `IconButton` builds its own semantics
                  // merge boundary, so a `Semantics` above it never
                  // attaches (lessons-learned.md).
                  IconButton(
                    tooltip: state.data.canExport
                        ? l10n.diaryExportAction
                        : '${l10n.diaryExportAction}. ${l10n.diaryExportUnavailableHint}',
                    constraints: const BoxConstraints(
                      minWidth: AppConstants.minTapTargetDp,
                      minHeight: AppConstants.minTapTargetDp,
                    ),
                    icon: state.data.exporting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.ios_share),
                    onPressed: state.data.canExport
                        ? () => unawaited(context.read<DiaryCubit>().export())
                        : null,
                  ),
                ],
              )
            : null,
        body: SafeArea(
          child: switch (state) {
            DiaryInitial() || DiaryLoading() => const Center(child: CircularProgressIndicator()),
            DiaryUnavailable() => const DiaryUnavailableView(),
            DiaryError(:final failure) => DiaryErrorView(
              failure: failure,
              onRetry: () => unawaited(context.read<DiaryCubit>().retry()),
            ),
            DiaryLoaded(:final data) => Column(
              children: [
                if (data.chart.isNotEmpty) MoodChart(points: data.chart),
                Expanded(child: _DiaryList(data: data)),
              ],
            ),
          },
        ),
      ),
    );
  }
}

/// The scrollable history list — its own widget so a first-load indicator
/// (built by [_DiaryView] for `initial`/`loading`) never mixes with a
/// footer indicator for `loadMore()` (research.md R19, CHK005).
class _DiaryList extends StatelessWidget {
  const _DiaryList({required this.data});

  final DiaryData data;

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const DiaryEmptyView();

    final cubit = context.read<DiaryCubit>();
    return ListView.builder(
      itemCount: data.days.length + 1,
      itemBuilder: (context, index) {
        if (index == data.days.length) {
          return _DiaryListFooter(data: data, onRetry: () => unawaited(cubit.loadMore()));
        }

        // Fewer than half a page of shown days remain — start prefetching
        // the next page (FR-004a, research.md R19, CHK002/CHK003). Deferred
        // to after this frame: `loadMore()` may `emit` synchronously, and
        // this callback runs mid-build of the list itself.
        if (index >= data.days.length - AppConstants.diaryPrefetchThreshold) {
          WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(cubit.loadMore()));
        }

        final day = data.days[index];
        return DiaryDayCard(
          day: day,
          characters: data.characters,
          onToggle: () => unawaited(cubit.toggleDay(day.entryId)),
        );
      },
    );
  }
}

class _DiaryListFooter extends StatelessWidget {
  const _DiaryListFooter({required this.data, required this.onRetry});

  final DiaryData data;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    if (data.loadingMore) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final pageFailure = data.pageFailure;
    if (pageFailure != null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(l10n.diaryPageLoadError, textAlign: TextAlign.center),
            const SizedBox(height: 4),
            TextButton(onPressed: onRetry, child: Text(l10n.diaryRetryAction)),
          ],
        ),
      );
    }

    if (!data.hasMore) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: Text(
            l10n.diaryNoMoreDays,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.outline),
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }
}
