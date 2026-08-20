import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:roundtablezoo/core/constants/app_constants.dart';
import 'package:roundtablezoo/domain/entities/day_key.dart';
import 'package:roundtablezoo/domain/entities/mood_chart_point.dart';

/// Point-per-period granularity of the rendered series (FR-010a,
/// research.md R5). Chosen from how many days are currently visible —
/// never from the total history length.
enum ChartGranularity { daily, weekly, monthly }

ChartGranularity granularityForVisibleDays(int visibleDays) {
  if (visibleDays <= AppConstants.diaryChartDailyMaxDays) return ChartGranularity.daily;
  if (visibleDays <= AppConstants.diaryChartWeeklyMaxDays) return ChartGranularity.weekly;
  return ChartGranularity.monthly;
}

final DateTime _epoch = DateTime.utc(1970);

double dayIndex(DayKey key) =>
    DateTime.utc(key.year, key.month, key.day).difference(_epoch).inDays.toDouble();

DayKey _mondayOf(DayKey day) {
  final weekday = DateTime.utc(day.year, day.month, day.day).weekday; // 1=Mon..7=Sun
  return DayKey.fromDateTime(DateTime.utc(day.year, day.month, day.day - (weekday - 1)));
}

DayKey _firstOfMonth(DayKey day) => DayKey(year: day.year, month: day.month, day: 1);

DayKey _nextBucket(DayKey bucket, ChartGranularity granularity) => switch (granularity) {
  ChartGranularity.daily => bucket.next,
  ChartGranularity.weekly => DayKey.fromDateTime(
    DateTime.utc(bucket.year, bucket.month, bucket.day + 7),
  ),
  ChartGranularity.monthly =>
    bucket.month == 12
        ? DayKey(year: bucket.year + 1, month: 1, day: 1)
        : DayKey(year: bucket.year, month: bucket.month + 1, day: 1),
};

/// Buckets the full daily [points] series (any order, at most one point per
/// day — R15) into one [FlSpot] per period at [granularity], covering every
/// period from the earliest to the latest point. A period with no entry is
/// `FlSpot.nullSpot` — a gap, never an interpolated value (FR-012,
/// research.md R5). The value of a period is the mean of the days that do
/// have an entry (SC-002, SC-007) — `MoodChartPoint` never reads
/// `CharacterReaction.tone`/`intensity` in the first place, so the chart
/// can't drift from `moodScore` no matter the granularity.
List<FlSpot> aggregateMoodSeries(List<MoodChartPoint> points, ChartGranularity granularity) {
  if (points.isEmpty) return const [];

  final sorted = [...points]..sort((a, b) => a.day.compareTo(b.day));
  final bucketOf = switch (granularity) {
    ChartGranularity.daily => (DayKey d) => d,
    ChartGranularity.weekly => _mondayOf,
    ChartGranularity.monthly => _firstOfMonth,
  };

  final sums = <DayKey, double>{};
  final counts = <DayKey, int>{};
  for (final point in sorted) {
    final bucket = bucketOf(point.day);
    sums[bucket] = (sums[bucket] ?? 0) + point.moodScore.value;
    counts[bucket] = (counts[bucket] ?? 0) + 1;
  }

  final firstBucket = bucketOf(sorted.first.day);
  final lastBucket = bucketOf(sorted.last.day);
  final spots = <FlSpot>[];
  var cursor = firstBucket;
  while (cursor <= lastBucket) {
    final count = counts[cursor];
    spots.add(count == null ? FlSpot.nullSpot : FlSpot(dayIndex(cursor), sums[cursor]! / count));
    cursor = _nextBucket(cursor, granularity);
  }
  return spots;
}

/// The Diary mood chart (FR-010..FR-013a). Built entirely from `moodScore`
/// — never from reaction tone/intensity (FR-011, SC-007). Decorative for
/// screen readers (FR-013a): its initial visible window mirrors the first
/// page of the list (research.md R18), so the same data is available as
/// text.
class MoodChart extends StatefulWidget {
  const MoodChart({required this.points, super.key});

  final List<MoodChartPoint> points;

  @override
  State<MoodChart> createState() => _MoodChartState();
}

class _MoodChartState extends State<MoodChart> {
  final TransformationController _controller = TransformationController();
  late ChartGranularity _granularity;

  @override
  void initState() {
    super.initState();
    _granularity = granularityForVisibleDays(_initialVisibleDays());
    _controller.addListener(_onTransformChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _pinInitialWindow();
    });
  }

  @override
  void didUpdateWidget(covariant MoodChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.points != widget.points) {
      setState(() => _granularity = granularityForVisibleDays(_currentVisibleDays()));
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onTransformChanged);
    _controller.dispose();
    super.dispose();
  }

  int _initialVisibleDays() {
    final total = _totalDomainDays();
    return total < AppConstants.diaryChartInitialDays ? total : AppConstants.diaryChartInitialDays;
  }

  int _totalDomainDays() {
    if (widget.points.isEmpty) return 1;
    final sorted = [...widget.points]..sort((a, b) => a.day.compareTo(b.day));
    final span = dayIndex(sorted.last.day) - dayIndex(sorted.first.day) + 1;
    return span < 1 ? 1 : span.round();
  }

  int _currentVisibleDays() {
    final total = _totalDomainDays();
    final scale = _controller.value.getMaxScaleOnAxis();
    if (scale <= 1) return total;
    final visible = (total / scale).round();
    return visible < 1 ? 1 : visible;
  }

  /// Starts zoomed in on the last `diaryChartInitialDays` days, right edge
  /// pinned to the most recent day (research.md R18) — `minScale: 1` is
  /// the fully-zoomed-out view of the whole history, so the initial window
  /// is expressed as a pre-applied zoom-in instead.
  void _pinInitialWindow() {
    final total = _totalDomainDays();
    final initialDays = _initialVisibleDays();
    if (initialDays <= 0 || total <= initialDays) return;

    final scale = (total / initialDays).clamp(1.0, AppConstants.diaryChartMaxScale);
    final renderBox = context.findRenderObject();
    final width = renderBox is RenderBox && renderBox.hasSize ? renderBox.size.width : 0.0;
    if (width <= 0) return;

    // Right-anchor the zoomed-in window on the most recent day: scale
    // around the right edge, so translation shifts the visible window to
    // the end of the domain rather than its start.
    final dx = -(width * scale - width);
    _controller.value = Matrix4.identity()
      ..translateByDouble(dx, 0.0, 0.0, 1.0)
      ..scaleByDouble(scale, 1.0, 1.0, 1.0);
  }

  void _onTransformChanged() {
    final visibleDays = _currentVisibleDays();
    final next = granularityForVisibleDays(visibleDays);
    if (next != _granularity) setState(() => _granularity = next);
  }

  @override
  Widget build(BuildContext context) {
    final spots = aggregateMoodSeries(widget.points, _granularity);
    final scheme = Theme.of(context).colorScheme;

    // FR-013a: the data behind the chart is already text in the list —
    // the chart itself carries nothing a screen reader needs to announce.
    return ExcludeSemantics(
      child: SizedBox(
        height: 220,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: LineChart(
            LineChartData(
              minY: AppConstants.diaryChartMinValue,
              maxY: AppConstants.diaryChartMaxValue,
              titlesData: const FlTitlesData(show: false),
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              lineTouchData: const LineTouchData(enabled: false),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: false,
                  color: scheme.primary,
                  barWidth: 2,
                  dotData: FlDotData(show: spots.length <= 1),
                ),
              ],
            ),
            transformationConfig: FlTransformationConfig(
              scaleAxis: FlScaleAxis.horizontal,
              maxScale: AppConstants.diaryChartMaxScale,
              transformationController: _controller,
            ),
          ),
        ),
      ),
    );
  }
}
