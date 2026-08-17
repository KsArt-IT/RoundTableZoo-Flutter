import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:roundtablezoo/core/utils/app_logger.dart';
import 'package:roundtablezoo/domain/repositories/settings_repository.dart';
import 'package:roundtablezoo/presentation/onboarding/cubit/onboarding_state.dart';

/// Drives the first-launch gate (`/onboarding` redirect, contracts §1/§2).
/// Never touches DI or navigation directly — the router redirect reacts to
/// [state], and `RootBlocListener` calls [resolve] once the storage-backed
/// `SettingsRepository` becomes available.
class OnboardingCubit extends Cubit<OnboardingState> {
  OnboardingCubit({
    required SettingsRepository Function() settingsRepositoryLocator,
    required OnboardingState initialState,
    this.writeTimeout = defaultWriteTimeout,
  }) : _settingsRepositoryLocator = settingsRepositoryLocator,
       super(initialState);

  final SettingsRepository Function() _settingsRepositoryLocator;

  /// Upper bound on how long `complete()` waits for the write (FR-005b,
  /// SC-003). A constructor parameter, not a constant — a test would
  /// otherwise really wait 3 seconds on every `flutter test` run.
  final Duration writeTimeout;

  static const Duration defaultWriteTimeout = Duration(seconds: 3);

  /// Resolves [OnboardingState.unknown] by reading `hasSeenOnboarding`.
  /// No-op in any other state (data-model.md, R3 in research.md).
  ///
  /// Distinguishes two failure modes (FR-001a):
  /// - the locator throws (repository not registered yet) — stay
  ///   `unknown`, there's nothing to show yet;
  /// - the repository answers `Result.failure` — treat the unreadable flag
  ///   as `false` and move to `required`.
  Future<void> resolve() async {
    if (state is! OnboardingUnknown) return;

    final SettingsRepository repository;
    try {
      repository = _settingsRepositoryLocator();
    } on Object {
      return;
    }

    final result = await repository.load();
    if (isClosed) return;

    result.fold(
      success: (settings) => emit(
        settings.hasSeenOnboarding
            ? const OnboardingState.completed()
            : const OnboardingState.required(),
      ),
      failure: (_) => emit(const OnboardingState.required()),
    );
  }

  /// Confirms onboarding: waits for `markOnboardingSeen()` no longer than
  /// [writeTimeout] and moves to `completed` regardless of the outcome
  /// (FR-005, FR-005b, FR-006). No-op in `submitting`/`completed`
  /// (FR-005a).
  Future<void> complete() async {
    if (state is! OnboardingRequired) return;

    emit(const OnboardingState.submitting());

    final repository = _settingsRepositoryLocator();
    try {
      final result = await repository.markOnboardingSeen().timeout(writeTimeout);
      if (result.isFailure) {
        logger.w('markOnboardingSeen() failed: ${result.errorOrNull}');
      }
    } on Object catch (e, st) {
      logger.w('markOnboardingSeen() timed out', error: e, stackTrace: st);
    }
    if (isClosed) return;

    emit(const OnboardingState.completed());
  }
}
