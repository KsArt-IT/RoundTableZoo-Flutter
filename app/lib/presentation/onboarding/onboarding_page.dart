import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:roundtablezoo/core/constants/app_constants.dart';
import 'package:roundtablezoo/gen/app_localizations.dart';
import 'package:roundtablezoo/presentation/onboarding/cubit/onboarding_cubit.dart';
import 'package:roundtablezoo/presentation/onboarding/cubit/onboarding_state.dart';
import 'package:roundtablezoo/presentation/onboarding/widgets/onboarding_points.dart';

/// First-launch welcome screen — one screen, one action (FR-003). Outside
/// the shell (no `bottomNavigationBar`), no back navigation exposed
/// (`AppBar` isn't used at all, so there's no implied leading/back button
/// either) and no links to other screens (FR-003a).
///
/// Tapping the continue action calls `OnboardingCubit.complete()`; the
/// router's redirect (rule 4, contracts §2) — not this widget — takes the
/// user to `/table` once the cubit reaches `completed`.
class OnboardingPage extends StatelessWidget {
  const OnboardingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Accessibility focus lands here on open (FR-010a).
              Focus(
                autofocus: true,
                child: Semantics(
                  header: true,
                  child: Text(
                    l10n.onboardingTitle,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const OnboardingPoints(),
              const SizedBox(height: 32),
              BlocBuilder<OnboardingCubit, OnboardingState>(
                builder: (context, state) {
                  final isSubmitting = state is OnboardingSubmitting;
                  return ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: AppConstants.minTapTargetDp),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: isSubmitting
                            ? null
                            : () => context.read<OnboardingCubit>().complete(),
                        child: Text(l10n.onboardingStart),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
