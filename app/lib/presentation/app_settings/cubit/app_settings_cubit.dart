import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:roundtablezoo/core/errors/app_failure.dart';
import 'package:roundtablezoo/domain/entities/user_settings.dart';
import 'package:roundtablezoo/domain/repositories/settings_repository.dart';
import 'package:roundtablezoo/presentation/app_settings/cubit/app_settings_state.dart';

/// Global settings state — the single source `AppMaterialRouter` reads for
/// `themeMode`/`locale` (FR-027, SC-006). Subscribes to
/// `SettingsRepository.watch()`, which re-emits after every successful
/// `update*` call, so theme/language changes apply instantly with no
/// restart.
class AppSettingsCubit extends Cubit<AppSettingsState> {
  AppSettingsCubit({required SettingsRepository settingsRepository})
    : super(const AppSettingsState.initial()) {
    _subscription = settingsRepository.watch().listen(_onSettings, onError: _onError);
  }

  late final StreamSubscription<UserSettings> _subscription;

  void _onSettings(UserSettings settings) {
    if (isClosed) return;
    emit(AppSettingsState.loaded(settings: settings));
  }

  void _onError(Object error) {
    if (isClosed) return;
    emit(AppSettingsState.error(failure: AppFailure.fromError(error)));
  }

  @override
  Future<void> close() async {
    await _subscription.cancel();
    return super.close();
  }
}
