import 'package:freezed_annotation/freezed_annotation.dart';

part 'onboarding_state.freezed.dart';

/// First-launch gate phase (data-model.md). No fields — the gate only
/// needs the phase itself, not the settings snapshot (`AppSettingsCubit`
/// already owns that; duplicating it here would violate DRY).
@freezed
sealed class OnboardingState with _$OnboardingState {
  /// Repository not available yet / flag not read yet. The `/onboarding`
  /// redirect does not fire in this state.
  const factory OnboardingState.unknown() = OnboardingUnknown;

  /// Flag read as `false` — onboarding must be shown.
  const factory OnboardingState.required() = OnboardingRequired;

  /// `markOnboardingSeen()` write in flight.
  const factory OnboardingState.submitting() = OnboardingSubmitting;

  /// Onboarding passed for this session (write succeeded, failed, or timed
  /// out — the outcome doesn't matter, FR-006). Terminal (FR-006a, FR-007).
  const factory OnboardingState.completed() = OnboardingCompleted;
}
