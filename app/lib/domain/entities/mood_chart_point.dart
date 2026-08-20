import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:roundtablezoo/domain/entities/day_key.dart';
import 'package:roundtablezoo/domain/value_objects/mood_score.dart';

part 'mood_chart_point.freezed.dart';

/// One point of the Diary mood chart. Not a duplicate of `DayEntry`: it has
/// no `dayText`, `id` or timestamps — just what the chart needs
/// (research.md R4).
@freezed
abstract class MoodChartPoint with _$MoodChartPoint {
  const factory MoodChartPoint({required DayKey day, required MoodScore moodScore}) =
      _MoodChartPoint;
}
