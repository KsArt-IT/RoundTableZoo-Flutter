import 'package:flutter/material.dart';
import 'package:roundtablezoo/gen/app_localizations.dart';

/// The three onboarding points (a)/(b)/(c), in order — FR-004. Point (c) is
/// the AI disclosure (FR-004c/FR-004d, constitution V) and must always be
/// present, independent of `aiEnabled` (FR-004e — enforced by having no
/// conditional logic here at all).
class OnboardingPoints extends StatelessWidget {
  const OnboardingPoints({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textStyle = Theme.of(context).textTheme.bodyLarge;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.onboardingHowTo, style: textStyle),
        const SizedBox(height: 16),
        Text(l10n.onboardingDisclaimer, style: textStyle),
        const SizedBox(height: 16),
        Text(l10n.onboardingAiDisclosure, style: textStyle),
      ],
    );
  }
}
