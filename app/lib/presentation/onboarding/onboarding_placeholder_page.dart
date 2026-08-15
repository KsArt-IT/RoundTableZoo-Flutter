import 'package:flutter/material.dart';
import 'package:roundtablezoo/gen/app_localizations.dart';

/// Registered as a route but reached with no redirect guard (FR-006) — the
/// app never forces the user here.
class OnboardingPlaceholderPage extends StatelessWidget {
  const OnboardingPlaceholderPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(child: Text(AppLocalizations.of(context).sectionOnboarding)),
    );
  }
}
