import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class QuestionChartBlock extends StatefulWidget {
  final Map<String, dynamic> chartSpec;

  const QuestionChartBlock({
    super.key,
    required this.chartSpec,
  });

  @override
  State<QuestionChartBlock> createState() => _QuestionChartBlockState();
}

class _QuestionChartBlockState extends State<QuestionChartBlock> {
  int? _touchedPieIndex;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final spec = _ChartSpec.fromRaw(widget.chartSpec);
    if (!spec.isValid) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.25)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.surfaceContainerHighest.withValues(alpha: 0.24),
            colorScheme.surfaceContainer.withValues(alpha: 0.12),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (spec.title.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                spec.title,
                textAlign: TextAlign.center,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          SizedBox(
            height: spec.type == 'pie' ? 236 : 250,
            child: _buildChart(context, spec),
          ),
          const SizedBox(height: 8),
          _LegendWrap(spec: spec),
        ],
      ),
    );
  }

  Widget _buildChart(BuildContext context, _ChartSpec spec) {
    switch (spec.type) {
      case 'line':
        return _buildLineChart(context, spec);
      case 'pie':
        return _buildPieChart(context, spec);
      case 'candlestick':
        return _buildCandlestickChart(context, spec);
      case 'histogram':
        return _buildBarChart(context, spec, histogramMode: true);
      case 'bar':
      default:
        return _buildBarChart(context, spec);
    }
  }

  Widget _buildBarChart(BuildContext context, _ChartSpec spec,
      {bool histogramMode = false}) {
    final colorScheme = Theme.of(context).colorScheme;
    final labels = spec.labels;
    final series = spec.series;
    final rawMaxY = _maxOrOne(spec.allValues);
    final maxY = rawMaxY * 1.12;
    final yInterval = _niceInterval(maxY - 0);

    final groups = List.generate(labels.length, (x) {
      final rods = List.generate(series.length, (s) {
        final value = series[s].values[x];
        return BarChartRodData(
          toY: value,
          width: histogramMode ? 16 : (series.length > 1 ? 10 : 16),
          color: _chartPalette[s % _chartPalette.length],
          borderRadius: BorderRadius.circular(4),
        );
      });
      return BarChartGroupData(
        x: x,
        barRods: rods,
        barsSpace: series.length > 1 ? 4 : 0,
      );
    });

    return BarChart(
      BarChartData(
        minY: 0,
        maxY: maxY,
        barGroups: groups,
        groupsSpace: histogramMode ? 2 : 12,
        alignment: BarChartAlignment.spaceEvenly,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: yInterval,
          getDrawingHorizontalLine: (_) => FlLine(
            color: colorScheme.outline.withValues(alpha: 0.2),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border(
            left:
                BorderSide(color: colorScheme.outline.withValues(alpha: 0.35)),
            bottom:
                BorderSide(color: colorScheme.outline.withValues(alpha: 0.35)),
            top: BorderSide.none,
            right: BorderSide.none,
          ),
        ),
        titlesData: _buildAxisTitles(context, labels, maxY,
            minY: 0,
            yLabel: spec.yLabel,
            xLabel: spec.xLabel,
            format: spec.format),
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => colorScheme.surface,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final label = labels[group.x.toInt()];
              final seriesName = series[rodIndex].name;
              final value = rod.toY;
              return BarTooltipItem(
                '$label\n$seriesName: ${_formatValue(value, spec.format)}',
                TextStyle(color: colorScheme.onSurface, fontSize: 12),
              );
            },
          ),
        ),
      ),
      duration: const Duration(milliseconds: 220),
    );
  }

  Widget _buildLineChart(BuildContext context, _ChartSpec spec) {
    final colorScheme = Theme.of(context).colorScheme;
    final labels = spec.labels;
    final minData =
        spec.allValues.isEmpty ? 0 : spec.allValues.reduce(math.min);
    final maxData = _maxOrOne(spec.allValues);
    final spread = math.max(1.0, maxData - minData);
    final minY = minData <= 0 ? 0.0 : math.max(0.0, minData - spread * 0.15);
    final maxY = maxData + spread * 0.18;
    final yInterval = _niceInterval(maxY - minY);

    final bars = List.generate(spec.series.length, (s) {
      final line = spec.series[s];
      return LineChartBarData(
        spots: List.generate(
            line.values.length, (i) => FlSpot(i.toDouble(), line.values[i])),
        isCurved: false,
        barWidth: 2.6,
        color: _chartPalette[s % _chartPalette.length],
        dotData: FlDotData(show: true),
        belowBarData: BarAreaData(show: false),
      );
    });

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: (labels.length - 1).toDouble(),
        minY: minY,
        maxY: maxY,
        lineBarsData: bars,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: yInterval,
          getDrawingHorizontalLine: (_) => FlLine(
            color: colorScheme.outline.withValues(alpha: 0.2),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border(
            left:
                BorderSide(color: colorScheme.outline.withValues(alpha: 0.35)),
            bottom:
                BorderSide(color: colorScheme.outline.withValues(alpha: 0.35)),
            top: BorderSide.none,
            right: BorderSide.none,
          ),
        ),
        titlesData: _buildAxisTitles(context, labels, maxY,
            minY: minY,
            yLabel: spec.yLabel,
            xLabel: spec.xLabel,
            format: spec.format),
        lineTouchData: LineTouchData(
          enabled: true,
          handleBuiltInTouches: true,
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => colorScheme.surface,
            getTooltipItems: (spots) {
              return spots.map((spot) {
                final label = labels[spot.x.toInt()];
                final seriesName = spec.series[spot.barIndex].name;
                return LineTooltipItem(
                  '$label\n$seriesName: ${_formatValue(spot.y, spec.format)}',
                  TextStyle(color: colorScheme.onSurface, fontSize: 12),
                );
              }).toList();
            },
          ),
        ),
      ),
      duration: const Duration(milliseconds: 220),
    );
  }

  Widget _buildPieChart(BuildContext context, _ChartSpec spec) {
    final colorScheme = Theme.of(context).colorScheme;
    final values = spec.series.first.values;
    final total = values.fold<double>(0, (a, b) => a + b);

    final sections = List.generate(values.length, (i) {
      final isTouched = _touchedPieIndex == i;
      final radius = isTouched ? 92.0 : 82.0;
      final value = values[i];
      final pct = total > 0 ? (value / total) * 100 : 0;
      return PieChartSectionData(
        value: value,
        radius: radius,
        color: _chartPalette[i % _chartPalette.length],
        showTitle: true,
        title: '${pct.toStringAsFixed(0)}%',
        titleStyle: TextStyle(
          color: colorScheme.onSurface,
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      );
    });

    return PieChart(
      PieChartData(
        sections: sections,
        centerSpaceRadius: 34,
        sectionsSpace: 2,
        pieTouchData: PieTouchData(
          enabled: true,
          touchCallback: (event, response) {
            if (!event.isInterestedForInteractions ||
                response?.touchedSection == null) {
              setState(() => _touchedPieIndex = null);
              return;
            }
            setState(() {
              _touchedPieIndex = response!.touchedSection!.touchedSectionIndex;
            });
          },
        ),
      ),
      duration: const Duration(milliseconds: 220),
    );
  }

  Widget _buildCandlestickChart(BuildContext context, _ChartSpec spec) {
    final colorScheme = Theme.of(context).colorScheme;
    final candles = spec.candles;
    if (candles.isEmpty) {
      return const SizedBox.shrink();
    }

    final dataMax = candles.map((c) => c.high).reduce(math.max);
    final dataMin = candles.map((c) => c.low).reduce(math.min);
    final spread = math.max(1.0, dataMax - dataMin);
    final maxY = dataMax + spread * 0.12;
    final minY = math.max<double>(0, dataMin - spread * 0.12);
    final yInterval = _niceInterval(maxY - minY);
    final labels = candles.map((c) => c.label).toList();

    final highSpots = List.generate(
      candles.length,
      (i) => FlSpot(i.toDouble(), candles[i].high),
    );
    final lowSpots = List.generate(
      candles.length,
      (i) => FlSpot(i.toDouble(), candles[i].low),
    );
    final closeSpots = List.generate(
      candles.length,
      (i) => FlSpot(i.toDouble(), candles[i].close),
    );

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: (candles.length - 1).toDouble(),
        minY: minY,
        maxY: maxY,
        lineBarsData: [
          LineChartBarData(
            spots: highSpots,
            isCurved: false,
            barWidth: 1.9,
            color: const Color(0xFF22C55E),
            dotData: FlDotData(show: false),
            belowBarData: BarAreaData(show: false),
          ),
          LineChartBarData(
            spots: lowSpots,
            isCurved: false,
            barWidth: 1.9,
            color: const Color(0xFFEF4444),
            dotData: FlDotData(show: false),
            belowBarData: BarAreaData(show: false),
          ),
          LineChartBarData(
            spots: closeSpots,
            isCurved: false,
            barWidth: 2.4,
            color: const Color(0xFF60A5FA),
            dotData: FlDotData(show: true),
            belowBarData: BarAreaData(show: false),
          ),
        ],
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: yInterval,
          getDrawingHorizontalLine: (_) => FlLine(
            color: colorScheme.outline.withValues(alpha: 0.2),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border(
            left:
                BorderSide(color: colorScheme.outline.withValues(alpha: 0.35)),
            bottom:
                BorderSide(color: colorScheme.outline.withValues(alpha: 0.35)),
            top: BorderSide.none,
            right: BorderSide.none,
          ),
        ),
        titlesData: _buildAxisTitles(context, labels, maxY,
            minY: minY,
            yLabel: spec.yLabel,
            xLabel: spec.xLabel.isNotEmpty ? spec.xLabel : 'Time',
            format: spec.format,
            xIntervalOverride: 1,
            truncateXLabels: false),
        lineTouchData: LineTouchData(
          enabled: true,
          handleBuiltInTouches: true,
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => colorScheme.surface,
            getTooltipItems: (spots) {
              if (spots.isEmpty) return <LineTooltipItem>[];
              final index =
                  spots.first.x.round().clamp(0, candles.length - 1);
              final c = candles[index];
              return [
                LineTooltipItem(
                  '${labels[index]}\nO: ${_formatValue(c.open, spec.format)}  H: ${_formatValue(c.high, spec.format)}\nL: ${_formatValue(c.low, spec.format)}  C: ${_formatValue(c.close, spec.format)}',
                  TextStyle(color: colorScheme.onSurface, fontSize: 12),
                ),
              ];
            },
          ),
        ),
      ),
      duration: const Duration(milliseconds: 220),
    );
  }

  FlTitlesData _buildAxisTitles(
    BuildContext context,
    List<String> labels,
    double maxY, {
    required double minY,
    required String xLabel,
    required String yLabel,
    required String format,
    double? xIntervalOverride,
    bool truncateXLabels = true,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final yRange = math.max(1.0, maxY - minY);
    final yInterval = _niceInterval(yRange);
    final xInterval = xIntervalOverride ?? _xInterval(labels.length);

    return FlTitlesData(
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      leftTitles: AxisTitles(
        axisNameWidget: yLabel.isEmpty
            ? null
            : Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Text(
                  yLabel,
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 56,
          interval: yInterval,
          getTitlesWidget: (value, meta) {
            return SideTitleWidget(
              meta: meta,
              child: Text(
                _formatAxisValue(value, format),
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 10,
                ),
              ),
            );
          },
        ),
      ),
      bottomTitles: AxisTitles(
        axisNameWidget: xLabel.isEmpty
            ? null
            : Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  xLabel,
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 28,
          interval: xInterval,
          getTitlesWidget: (value, meta) {
            if (!_isAlignedTick(value, xInterval)) {
              return const SizedBox.shrink();
            }
            final i = value.round();
            if (i < 0 || i >= labels.length) {
              return const SizedBox.shrink();
            }
            final label = labels[i];
            final short = truncateXLabels && label.length > 7
                ? '${label.substring(0, 7)}…'
                : label;
            return SideTitleWidget(
              meta: meta,
              child: Text(
                short,
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _LegendWrap extends StatelessWidget {
  final _ChartSpec spec;

  const _LegendWrap({required this.spec});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final items = spec.legendItems;
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: List.generate(items.length, (index) {
        final item = items[index];
        final color = _chartPalette[index % _chartPalette.length];
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            item,
            style: theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
      }),
    );
  }
}

class _ChartSpec {
  final String type;
  final String title;
  final String xLabel;
  final String yLabel;
  final String format;
  final List<_SeriesData> series;
  final List<_CandleData> candles;

  _ChartSpec({
    required this.type,
    required this.title,
    required this.xLabel,
    required this.yLabel,
    required this.format,
    required this.series,
    required this.candles,
  });

  bool get isValid {
    if (type == 'candlestick') return candles.isNotEmpty;
    if (type == 'pie' ||
        type == 'bar' ||
        type == 'line' ||
        type == 'histogram') {
      return series.isNotEmpty && labels.isNotEmpty;
    }
    return false;
  }

  List<String> get labels {
    if (type == 'candlestick') {
      return candles.map((c) => c.label).toList();
    }
    return series.isNotEmpty ? series.first.labels : const [];
  }

  List<double> get allValues {
    if (type == 'candlestick') {
      return candles.expand((c) => [c.low, c.high]).toList();
    }
    return series.expand((s) => s.values).toList();
  }

  List<String> get legendItems {
    if (type == 'candlestick') {
      return candles
          .map((c) =>
              '${c.label}: O${_n(c.open)} H${_n(c.high)} L${_n(c.low)} C${_n(c.close)}')
          .toList();
    }
    if (type == 'pie') {
      final values = series.first.values;
      final labels = series.first.labels;
      return List.generate(
          labels.length, (i) => '${labels[i]}: ${_n(values[i])}');
    }
    return series.map((s) => s.name).toList();
  }

  static _ChartSpec fromRaw(Map<String, dynamic> raw) {
    var type = (raw['type']?.toString().toLowerCase().trim() ?? 'bar');
    const allowed = {'bar', 'line', 'pie', 'histogram', 'candlestick'};
    if (!allowed.contains(type)) type = 'bar';

    final title = raw['title']?.toString().trim() ?? '';
    final xLabel = raw['xLabel']?.toString().trim() ?? '';
    final yLabel = raw['yLabel']?.toString().trim() ?? '';
    final format = raw['format']?.toString().trim().toLowerCase() ?? 'number';

    final candles = _parseCandles(raw['candles']);

    final series = _parseSeries(raw);
    return _ChartSpec(
      type: type,
      title: title,
      xLabel: xLabel,
      yLabel: yLabel,
      format: format,
      series: series,
      candles: candles,
    );
  }

  static List<_SeriesData> _parseSeries(Map<String, dynamic> raw) {
    final output = <_SeriesData>[];

    final seriesRaw = raw['series'];
    if (seriesRaw is List) {
      for (final entry in seriesRaw) {
        if (entry is! Map) continue;
        final map = Map<String, dynamic>.from(entry);
        final labels = ((map['labels'] as List?) ?? const <dynamic>[])
            .map((e) => e.toString())
            .toList();
        final values = ((map['values'] as List?) ?? const <dynamic>[])
            .map((e) => (e as num).toDouble())
            .toList();
        if (labels.isNotEmpty && labels.length == values.length) {
          output.add(
            _SeriesData(
              name: map['name']?.toString().trim().isNotEmpty == true
                  ? map['name'].toString()
                  : 'Series ${output.length + 1}',
              labels: labels,
              values: values,
            ),
          );
        }
      }
    }

    if (output.isEmpty) {
      final labels = ((raw['labels'] as List?) ?? const <dynamic>[])
          .map((e) => e.toString())
          .toList();
      final values = ((raw['values'] as List?) ?? const <dynamic>[])
          .map((e) => (e as num).toDouble())
          .toList();
      if (labels.isNotEmpty && labels.length == values.length) {
        output
            .add(_SeriesData(name: 'Series 1', labels: labels, values: values));
      }
    }

    return output;
  }

  static List<_CandleData> _parseCandles(dynamic rawCandles) {
    if (rawCandles is! List) return const [];

    double? readNum(Map<String, dynamic> source, List<String> keys) {
      for (final key in keys) {
        final value = source[key];
        if (value is num) return value.toDouble();
        if (value != null) {
          final parsed = double.tryParse(value.toString());
          if (parsed != null) return parsed;
        }
      }
      return null;
    }

    final out = <_CandleData>[];
    for (final item in rawCandles) {
      if (item is! Map) continue;
      final map = Map<String, dynamic>.from(item);
      final label = map['label']?.toString() ??
          map['day']?.toString() ??
          map['date']?.toString() ??
          map['x']?.toString() ??
          'P${out.length + 1}';
      final open = readNum(map, const ['open', 'o', 'Open', 'O']);
      final high = readNum(map, const ['high', 'h', 'High', 'H']);
      final low = readNum(map, const ['low', 'l', 'Low', 'L']);
      final close = readNum(map, const ['close', 'c', 'Close', 'C']);
      if (open == null || high == null || low == null || close == null) {
        continue;
      }
      out.add(
        _CandleData(
          label: label,
          open: open,
          high: high,
          low: low,
          close: close,
        ),
      );
    }
    return out;
  }
}

class _SeriesData {
  final String name;
  final List<String> labels;
  final List<double> values;

  _SeriesData({
    required this.name,
    required this.labels,
    required this.values,
  });
}

class _CandleData {
  final String label;
  final double open;
  final double high;
  final double low;
  final double close;

  _CandleData({
    required this.label,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
  });
}

const _chartPalette = <Color>[
  Color(0xFF4FC3F7),
  Color(0xFF81C784),
  Color(0xFFFFB74D),
  Color(0xFFBA68C8),
  Color(0xFFE57373),
  Color(0xFFFFF176),
];

double _maxOrOne(List<double> values) {
  if (values.isEmpty) return 1;
  return math.max(1, values.reduce(math.max));
}

double _niceInterval(double maxY) {
  if (maxY <= 0) return 1;
  final rawStep = maxY / 5;
  final magnitude = math.pow(10, (math.log(rawStep) / math.ln10).floor());
  final normalized = rawStep / magnitude;

  double niceNormalized;
  if (normalized <= 1) {
    niceNormalized = 1;
  } else if (normalized <= 2) {
    niceNormalized = 2;
  } else if (normalized <= 2.5) {
    niceNormalized = 2.5;
  } else if (normalized <= 5) {
    niceNormalized = 5;
  } else {
    niceNormalized = 10;
  }

  return niceNormalized * magnitude;
}

String _formatValue(double value, String format) {
  switch (format) {
    case 'percent':
      return '${value.toStringAsFixed(0)}%';
    case 'currency':
      return '\$${value.toStringAsFixed(value >= 100 ? 0 : 2)}';
    case 'number':
    default:
      return _n(value);
  }
}

String _n(double value) {
  if (value == value.roundToDouble()) return value.toInt().toString();
  return value.toStringAsFixed(1);
}

double _xInterval(int count) {
  if (count <= 4) return 1;
  if (count <= 8) return 2;
  if (count <= 12) return 3;
  return 4;
}

bool _isAlignedTick(double value, double interval) {
  if (interval <= 0) return false;
  final ratio = value / interval;
  return (ratio - ratio.round()).abs() < 0.0015;
}

String _formatAxisValue(double value, String format) {
  if (format == 'currency') {
    final absValue = value.abs();
    if (absValue >= 1000000) {
      return '\$${(value / 1000000).toStringAsFixed(1)}M';
    }
    if (absValue >= 1000) {
      return '\$${(value / 1000).toStringAsFixed(1)}k';
    }
  }
  if (value.abs() >= 1000000) {
    return '${(value / 1000000).toStringAsFixed(1)}M';
  }
  if (value.abs() >= 1000) {
    return '${(value / 1000).toStringAsFixed(1)}k';
  }
  return _formatValue(value, format);
}
