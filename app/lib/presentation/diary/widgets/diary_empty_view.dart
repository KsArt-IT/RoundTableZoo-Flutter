import 'package:flutter/material.dart';
import 'package:roundtablezoo/gen/app_localizations.dart';

/// Explicit empty-history state — never a bare blank screen (FR-007).
class DiaryEmptyView extends StatelessWidget {
  const DiaryEmptyView({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.diaryEmptyTitle,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(l10n.diaryEmptyHint, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
