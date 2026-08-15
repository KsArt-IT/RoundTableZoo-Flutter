import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:roundtablezoo/domain/entities/day_key.dart';

part 'current_day_state.freezed.dart';

@freezed
sealed class CurrentDayState with _$CurrentDayState {
  /// Before the first resolution — never observed outside cubit
  /// construction, superseded synchronously by `.day(...)`.
  const factory CurrentDayState.initial() = CurrentDayInitial;

  const factory CurrentDayState.day({required DayKey key}) = CurrentDayDay;
}
