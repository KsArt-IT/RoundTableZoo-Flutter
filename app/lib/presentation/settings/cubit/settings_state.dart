import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:roundtablezoo/core/errors/app_failure.dart';
import 'package:roundtablezoo/core/notifications/notification_permission_status.dart';
import 'package:roundtablezoo/domain/entities/user_settings.dart';

part 'settings_state.freezed.dart';

/// Why the voicing sound toggle is enabled/disabled (`data-model.md` §6).
/// `screenReaderActive` outranks `noVoiceForLanguage` — it names the
/// cause the user actually understands.
enum VoiceAvailability {
  available,
  noVoiceForLanguage,
  screenReaderActive,
}

@freezed
sealed class SettingsState with _$SettingsState {
  /// Before the first `SettingsRepository.watch()` emission — the screen
  /// renders every section in its final layout with controls disabled
  /// (FR-004), not a spinner.
  const factory SettingsState.loading() = SettingsLoading;

  const factory SettingsState.loaded({
    required UserSettings settings,
    required NotificationPermissionStatus permission,
    @Default(VoiceAvailability.available) VoiceAvailability voiceAvailability,
  }) = SettingsLoaded;

  /// `watch()` failed. The screen stays usable; the error goes out as a
  /// toast (`RootBlocListener`), not a blank screen.
  const factory SettingsState.error({required AppFailure failure}) = SettingsError;
}
