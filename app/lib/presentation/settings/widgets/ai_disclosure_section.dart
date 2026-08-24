import 'package:flutter/material.dart';
import 'package:roundtablezoo/gen/app_localizations.dart';

/// Permanently-accessible AI disclosure (FR-021,
/// `specs/007-ai-proxy/data-model.md` §4.2) — the same wording already
/// shown once during onboarding (`onboardingAiDisclosure`,
/// `onboarding_points.dart`), reachable here too for anyone who completed
/// onboarding before AI existed. Static text, no toggle: nothing here is a
/// setting to change, only a disclosure to read.
class AiDisclosureSection extends StatelessWidget {
  const AiDisclosureSection({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.settingsAiDisclosureTitle, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(l10n.onboardingAiDisclosure, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}
