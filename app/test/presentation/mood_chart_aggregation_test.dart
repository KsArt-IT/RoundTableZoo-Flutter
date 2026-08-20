import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roundtablezoo/domain/entities/day_key.dart';
import 'package:roundtablezoo/domain/entities/mood_chart_point.dart';
import 'package:roundtablezoo/domain/value_objects/mood_score.dart';
import 'package:roundtablezoo/presentation/diary/widgets/mood_chart.dart';

MoodScore _mood(int value) =>
    MoodScore.create(value).valueOrGet(() => throw StateError('bad fixture'));

MoodChartPoint _point(int day, int mood) => MoodChartPoint(
  day: DayKey(year: 2026, month: 1, day: day),
  moodScore: _mood(mood),
);

void main() {
  group('granularityForVisibleDays', () {
    test('daily up to AppConstants.diaryChartDailyMaxDays', () {
      expect(granularityForVisibleDays(1), ChartGranularity.daily);
      expect(granularityForVisibleDays(90), ChartGranularity.daily);
    });

    test('weekly beyond the daily threshold, up to the weekly threshold', () {
      expect(granularityForVisibleDays(91), ChartGranularity.weekly);
      expect(granularityForVisibleDays(731), ChartGranularity.weekly);
    });

    test('monthly beyond the weekly threshold', () {
      expect(granularityForVisibleDays(732), ChartGranularity.monthly);
    });
  });

  group('aggregateMoodSeries', () {
    test('an empty series yields no spots', () {
      expect(aggregateMoodSeries(const [], ChartGranularity.daily), isEmpty);
    });

    test('a single-point series is a single, non-null spot', () {
      final spots = aggregateMoodSeries([_point(1, 4)], ChartGranularity.daily);
      expect(spots, hasLength(1));
      expect(spots.single.isNotNull(), isTrue);
      expect(spots.single.y, 4);
    });

    test('daily granularity: each spot equals the stored moodScore for that day (SC-002)', () {
      final points = [
        _point(1, 1),
        _point(2, 3),
        _point(3, 5),
        _point(4, 2),
        _point(5, 4),
        _point(6, 1),
        _point(7, 5),
        _point(8, 3),
        _point(9, 2),
        _point(10, 4),
      ];
      final spots = aggregateMoodSeries(points, ChartGranularity.daily);
      expect(spots, hasLength(10));
      expect(spots.map((s) => s.y), [1, 3, 5, 2, 4, 1, 5, 3, 2, 4]);
    });

    test('a day with no entry inside the range is a gap, not an interpolated value', () {
      final points = [_point(1, 5), _point(3, 1)]; // day 2 missing
      final spots = aggregateMoodSeries(points, ChartGranularity.daily);
      expect(spots, hasLength(3));
      expect(spots[0].isNotNull(), isTrue);
      expect(spots[1], FlSpot.nullSpot);
      expect(spots[2].isNotNull(), isTrue);
    });

    test('weekly granularity averages only the days that have an entry', () {
      // 2026-01-05 is a Monday; the week is 2026-01-05..2026-01-11.
      final points = [
        MoodChartPoint(day: const DayKey(year: 2026, month: 1, day: 5), moodScore: _mood(2)),
        MoodChartPoint(day: const DayKey(year: 2026, month: 1, day: 7), moodScore: _mood(4)),
      ];
      final spots = aggregateMoodSeries(points, ChartGranularity.weekly);
      expect(spots, hasLength(1));
      expect(spots.single.y, 3); // mean of 2 and 4, not divided by 7
    });

    test('a fully empty period inside the range is a gap', () {
      final points = [
        MoodChartPoint(day: const DayKey(year: 2026, month: 1, day: 1), moodScore: _mood(5)),
        // Whole February is empty.
        MoodChartPoint(day: const DayKey(year: 2026, month: 3, day: 1), moodScore: _mood(1)),
      ];
      final spots = aggregateMoodSeries(points, ChartGranularity.monthly);
      expect(spots, hasLength(3));
      expect(spots[0].isNotNull(), isTrue);
      expect(spots[1], FlSpot.nullSpot);
      expect(spots[2].isNotNull(), isTrue);
    });
  });
}
