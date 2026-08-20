import 'package:flutter/material.dart';
import 'package:roundtablezoo/core/errors/app_failure.dart';
import 'package:roundtablezoo/gen/app_localizations.dart';

/// First-load error banner: `failure.localizedMessage` plus a retry button
/// (FR-008a). Distinct from [DiaryUnavailableView] — this one always shows
/// a specific failure message and a way to try again.
class DiaryErrorView extends StatelessWidget {
  const DiaryErrorView({required this.failure, required this.onRetry, super.key});

  final AppFailure failure;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(failure.localizedMessage(l10n), textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: Text(l10n.diaryRetryAction)),
          ],
        ),
      ),
    );
  }
}

/// Read-only storage mode banner (FR-029, research.md R13) — deliberately
/// says "unavailable", never "no entries" (that would misrepresent an
/// unreadable store as an empty history).
class DiaryUnavailableView extends StatelessWidget {
  const DiaryUnavailableView({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(l10n.diaryUnavailableMessage, textAlign: TextAlign.center),
      ),
    );
  }
}
