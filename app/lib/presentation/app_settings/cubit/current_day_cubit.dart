import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:roundtablezoo/core/app_clock/app_clock.dart';
import 'package:roundtablezoo/domain/entities/user_settings.dart';
import 'package:roundtablezoo/domain/repositories/settings_repository.dart';
import 'package:roundtablezoo/domain/services/day_resolver.dart';
import 'package:roundtablezoo/domain/value_objects/day_start_hour.dart';
import 'package:roundtablezoo/presentation/app_settings/cubit/current_day_state.dart';

/// Tracks "today" as a `DayKey`, recomputed from `AppClock.minuteTicks`, a
/// `dayStartHour` change, or an explicit [refresh] (app resume — FR-026a).
/// Emits only when the resolved key actually changes (contracts/app-clock.md).
class CurrentDayCubit extends Cubit<CurrentDayState> {
  CurrentDayCubit({
    required this._clock,
    required this._dayResolver,
    required SettingsRepository settingsRepository,
  }) : _dayStartHour = DayStartHour.defaultValue,
       super(const CurrentDayState.initial()) {
    _settingsSubscription = settingsRepository.watch().listen(_onSettingsChanged);
    _tickSubscription = _clock.minuteTicks.listen(_recompute);
    _recompute(_clock.nowUtc());
  }

  final AppClock _clock;
  final DayResolver _dayResolver;
  DayStartHour _dayStartHour;
  late final StreamSubscription<UserSettings> _settingsSubscription;
  late final StreamSubscription<DateTime> _tickSubscription;

  /// Forces a recompute without waiting for the next tick — called after
  /// `AppLifecycleState.resumed` once `AppClock.updateLocation` has run
  /// (FR-026a).
  void refresh() => _recompute(_clock.nowUtc());

  void _onSettingsChanged(UserSettings settings) {
    _dayStartHour = settings.dayStartHour;
    _recompute(_clock.nowUtc());
  }

  void _recompute(DateTime instantUtc) {
    if (isClosed) return;
    final key = _dayResolver.resolve(
      instantUtc,
      zone: _clock.location,
      dayStartHour: _dayStartHour.value,
    );
    final current = state;
    if (current is CurrentDayDay && current.key == key) return;
    emit(CurrentDayState.day(key: key));
  }

  @override
  Future<void> close() async {
    await _settingsSubscription.cancel();
    await _tickSubscription.cancel();
    return super.close();
  }
}
