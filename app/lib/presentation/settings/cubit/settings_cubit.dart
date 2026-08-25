import 'dart:async';
import 'dart:ui';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:roundtablezoo/core/errors/app_failure.dart';
import 'package:roundtablezoo/core/errors/result.dart';
import 'package:roundtablezoo/core/notifications/notification_permission_status.dart';
import 'package:roundtablezoo/core/notifications/notification_scheduler.dart';
import 'package:roundtablezoo/core/speech/speech_synthesizer.dart';
import 'package:roundtablezoo/core/speech/voice_availability.dart';
import 'package:roundtablezoo/core/utils/locale_resolution.dart';
import 'package:roundtablezoo/domain/entities/user_settings.dart';
import 'package:roundtablezoo/domain/repositories/settings_repository.dart';
import 'package:roundtablezoo/domain/value_objects/locale_preference.dart';
import 'package:roundtablezoo/domain/value_objects/reminder_time.dart';
import 'package:roundtablezoo/domain/value_objects/theme_preference.dart';
import 'package:roundtablezoo/gen/app_localizations.dart';
import 'package:roundtablezoo/presentation/settings/cubit/settings_state.dart';

/// Screen-scoped — a fresh instance per `/settings` visit, registered as an
/// `@injectable` factory (research.md, R9). Not provided at `AppRoot`, so
/// it never reproduces the global-Cubit widget-test failures in
/// `project/process/lessons-learned.md`.
class SettingsCubit extends Cubit<SettingsState> {
  SettingsCubit({
    required SettingsRepository settingsRepository,
    required NotificationScheduler notificationScheduler,
    required SpeechSynthesizer speechSynthesizer,
  }) : _settingsRepository = settingsRepository,
       _notificationScheduler = notificationScheduler,
       _speechSynthesizer = speechSynthesizer,
       super(const SettingsState.loading()) {
    _subscription = _settingsRepository.watch().listen(_onSettings, onError: _onError);
  }

  final SettingsRepository _settingsRepository;
  final NotificationScheduler _notificationScheduler;
  final SpeechSynthesizer _speechSynthesizer;
  late final StreamSubscription<UserSettings> _subscription;

  /// FR-014: pushed from `SettingsPage` (`MediaQuery.accessibleNavigationOf`)
  /// — the Cubit itself stays Flutter-binding-free (research.md R8).
  bool _screenReaderActive = false;

  /// Result of the last `resolveVoiceAvailability` check — `true` until
  /// the first check resolves, so the toggle doesn't flash disabled on
  /// every screen open.
  bool _engineHasVoice = true;

  /// Language the last availability check ran for — lets `_onSettings`
  /// skip re-probing the (async, platform-channel) engine on every
  /// unrelated settings write (theme, reminder time, sound toggle itself),
  /// same reasoning as `TablePage`'s own language-tag cache.
  String? _lastCheckedLanguageTag;

  /// One-off setter-failure signal (FR-003): the settings row didn't
  /// change on failure, so `watch()` stays silent and `state` keeps its
  /// old `loaded` value on its own — a control bound to `state.settings`
  /// reverts automatically. This carries only the toast side-effect;
  /// `SettingsPage` listens to it directly rather than through
  /// `RootBlocListener`, which only reaches app-scoped Cubits.
  final StreamController<AppFailure> _failures = StreamController<AppFailure>.broadcast();

  Stream<AppFailure> get failures => _failures.stream;

  /// Guards `_onSettings` against out-of-order emissions: `watch()` can, in
  /// principle, fire again before a prior `permissionStatus()` await
  /// resolves, and Stream listeners don't serialize an async callback
  /// against itself — without this, a slower earlier call could overwrite
  /// a newer `settings` snapshot.
  int _settingsRevision = 0;

  Future<void> _onSettings(UserSettings settings) async {
    if (isClosed) return;
    final revision = ++_settingsRevision;
    final permission = await _notificationScheduler.permissionStatus();
    if (isClosed || revision != _settingsRevision) return;
    emit(
      SettingsState.loaded(
        settings: settings,
        permission: permission,
        voiceAvailability: _voiceAvailability,
      ),
    );
    final languageTag = _languageTagFor(settings.locale);
    if (languageTag != _lastCheckedLanguageTag) {
      _lastCheckedLanguageTag = languageTag;
      unawaited(_refreshEngineVoiceAvailability(languageTag, revision));
    }
  }

  /// T021's shared availability function, fed the language the settings
  /// screen currently resolves to — the same source of truth `TablePage`
  /// uses, just without a `BuildContext` (`resolveDeviceLocale`, same
  /// pattern as `reminder_texts.dart`).
  Future<void> _refreshEngineVoiceAvailability(String languageTag, int revision) async {
    final available = await resolveVoiceAvailability(_speechSynthesizer, languageTag);
    if (isClosed || revision != _settingsRevision) return;
    _engineHasVoice = available;
    _emitVoiceAvailability();
  }

  /// FR-013a: never touches `settings.soundEnabled` — only the emitted
  /// `voiceAvailability` reason changes.
  void onScreenReaderChanged({required bool active}) {
    if (_screenReaderActive == active) return;
    _screenReaderActive = active;
    _emitVoiceAvailability();
  }

  VoiceAvailability get _voiceAvailability {
    if (_screenReaderActive) return VoiceAvailability.screenReaderActive;
    return _engineHasVoice ? VoiceAvailability.available : VoiceAvailability.noVoiceForLanguage;
  }

  void _emitVoiceAvailability() {
    if (isClosed) return;
    final current = state;
    if (current is SettingsLoaded) {
      emit(current.copyWith(voiceAvailability: _voiceAvailability));
    }
  }

  String _languageTagFor(LocalePreference locale) {
    final resolved = locale == LocalePreference.system
        ? resolveDeviceLocale(PlatformDispatcher.instance.locale, AppLocalizations.supportedLocales)
        : Locale(locale.name);
    return resolved.toLanguageTag();
  }

  void _onError(Object error) {
    if (isClosed) return;
    emit(SettingsState.error(failure: AppFailure.fromError(error)));
  }

  Future<void> setThemeMode(ThemePreference value) =>
      _guarded(_settingsRepository.updateThemeMode(value));

  Future<void> setLocale(LocalePreference value) =>
      _guarded(_settingsRepository.updateLocale(value));

  Future<void> setSoundEnabled({required bool value}) =>
      _guarded(_settingsRepository.updateSoundEnabled(value: value));

  Future<void> setReminderTime(ReminderTime value) =>
      _guarded(_settingsRepository.updateReminderTime(value));

  /// Turning the reminder on doubles as the moment intent is expressed
  /// (FR-020a) — the system prompt fires right from here, with no
  /// dialog of our own first. If the last known status is already
  /// `denied`, the prompt isn't repeated (FR-022a). The setting is saved
  /// either way — namesake FR-022: it starts firing the moment permission
  /// shows up, without the user re-flipping the toggle.
  Future<void> setReminderEnabled({required bool value}) async {
    if (value) {
      final known = switch (state) {
        SettingsLoaded(:final permission) => permission,
        SettingsLoading() || SettingsError() => NotificationPermissionStatus.unknown,
      };
      final NotificationPermissionStatus permission;
      if (known == NotificationPermissionStatus.denied) {
        permission = known;
      } else {
        permission = await _notificationScheduler.requestPermission();
        if (isClosed) return;
      }
      _reflectPermission(permission);
    }
    await _guarded(_settingsRepository.updateReminderEnabled(value: value));
  }

  Future<void> openNotificationSettings() async {
    await _notificationScheduler.openSystemSettings();
  }

  /// Re-reads permission status — called on `AppLifecycleState.resumed`
  /// while `/settings` is open, so a grant made in system settings clears
  /// the warning without the user re-flipping the toggle (FR-022).
  Future<void> refreshPermissionStatus() async {
    final permission = await _notificationScheduler.permissionStatus();
    if (isClosed) return;
    _reflectPermission(permission);
  }

  void _reflectPermission(NotificationPermissionStatus permission) {
    if (isClosed) return;
    final current = state;
    if (current is SettingsLoaded) emit(current.copyWith(permission: permission));
  }

  Future<void> _guarded(Future<Result<UserSettings>> operation) async {
    final result = await operation;
    if (isClosed) return;
    result.onFailure((failure) {
      if (!_failures.isClosed) _failures.add(failure);
    });
  }

  @override
  Future<void> close() async {
    await _subscription.cancel();
    await _failures.close();
    return super.close();
  }
}
