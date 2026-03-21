import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:neurobits/core/providers.dart';
import 'package:neurobits/core/learning_path_providers.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

const double _kScreenPadH = 16;
const double _kCardPad = 16;
const double _kCardRadius = 16;

class _ReportData {
  final String period;
  final String scope;
  final DateTime startDate;
  final DateTime endDate;
  final int quizzes;
  final double avgAccuracy;
  final num timeSeconds;
  final int activeDays;
  final int newTopicsCount;
  final int periodDays;
  final num accuracyDelta;
  final num quizzesDelta;
  final List<String> topicsTried;
  final List<String> newTopics;
  final List<Map<dynamic, dynamic>> consistentTopics;
  final List<Map<dynamic, dynamic>> needsWork;
  final Map<String, dynamic>? mostImproved;
  final int currentStreak;
  final int bestStreak;
  final List<Map<dynamic, dynamic>> daily;
  final Map<String, dynamic>? path;
  final int healthScore;
  final double consistencyScore;
  final double avgQuizzesPerActiveDay;
  final double avgQuizTime;
  final String coachSummary;
  final List<String> actionItems;
  final List<String> strongTopics;
  final List<String> weakTopics;

  const _ReportData({
    required this.period,
    required this.scope,
    required this.startDate,
    required this.endDate,
    required this.quizzes,
    required this.avgAccuracy,
    required this.timeSeconds,
    required this.activeDays,
    required this.newTopicsCount,
    required this.periodDays,
    required this.accuracyDelta,
    required this.quizzesDelta,
    required this.topicsTried,
    required this.newTopics,
    required this.consistentTopics,
    required this.needsWork,
    required this.mostImproved,
    required this.currentStreak,
    required this.bestStreak,
    required this.daily,
    required this.path,
    required this.healthScore,
    required this.consistencyScore,
    required this.avgQuizzesPerActiveDay,
    required this.avgQuizTime,
    required this.coachSummary,
    required this.actionItems,
    required this.strongTopics,
    required this.weakTopics,
  });
}

class ReportScreen extends ConsumerStatefulWidget {
  final String initialPeriod;
  const ReportScreen({super.key, required this.initialPeriod});

  @override
  ConsumerState<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends ConsumerState<ReportScreen> {
  late String _period;
  final GlobalKey _reportKey = GlobalKey();
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _period = widget.initialPeriod;
  }

  Future<Uint8List?> _captureReportImage() async {
    final boundary =
        _reportKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return null;
    final image = await boundary.toImage(pixelRatio: 3);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData?.buffer.asUint8List();
  }

  Future<void> _exportPng() async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      final pngBytes = await _captureReportImage();
      if (!mounted) return;
      if (pngBytes == null) {
        _showSnack(context, 'Could not capture report image.');
        return;
      }
      final tempDir = await Directory.systemTemp.createTemp();
      final file = await File('${tempDir.path}/report_$_period.png')
          .writeAsBytes(pngBytes);
      if (!mounted) return;
      final box = context.findRenderObject() as RenderBox?;
      final origin =
          box != null ? box.localToGlobal(Offset.zero) & box.size : null;
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: 'My Neurobits ${_periodLabel(_period)} Report',
          sharePositionOrigin: origin,
        ),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _exportPdf() async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      final pngBytes = await _captureReportImage();
      if (!mounted) return;
      if (pngBytes == null) {
        _showSnack(context, 'Could not capture report image.');
        return;
      }
      final doc = pw.Document();
      final image = pw.MemoryImage(pngBytes);
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (_) =>
              pw.Center(child: pw.Image(image, fit: pw.BoxFit.contain)),
        ),
      );
      final pdfBytes = await doc.save();
      final tempDir = await Directory.systemTemp.createTemp();
      final file = await File('${tempDir.path}/report_$_period.pdf')
          .writeAsBytes(pdfBytes);
      if (!mounted) return;
      final box = context.findRenderObject() as RenderBox?;
      final origin =
          box != null ? box.localToGlobal(Offset.zero) & box.size : null;
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: 'My Neurobits ${_periodLabel(_period)} Report',
          sharePositionOrigin: origin,
        ),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  void _showSnack(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  String _periodLabel(String period) {
    switch (period) {
      case 'daily':
        return 'Daily';
      case 'monthly':
        return 'Monthly';
      default:
        return 'Weekly';
    }
  }

  _ReportData _parseData(
      Map<String, dynamic> summary, Map<String, dynamic> detail) {
    final period = summary['period']?.toString() ?? 'weekly';
    final scope = summary['scope']?.toString() ?? 'all';
    final now = DateTime.now();
    final isDaily = period == 'daily';
    final isMonthly = period == 'monthly';
    final periodDays = isMonthly
        ? 30
        : isDaily
            ? 1
            : 7;

    final periodStart =
        (detail['periodStart'] as num?)?.toInt() ?? now.millisecondsSinceEpoch;
    final periodEnd =
        (detail['periodEnd'] as num?)?.toInt() ?? now.millisecondsSinceEpoch;
    final startDate = DateTime.fromMillisecondsSinceEpoch(periodStart);
    final endDate = DateTime.fromMillisecondsSinceEpoch(periodEnd);

    final current = summary['current'] as Map<String, dynamic>? ?? {};
    final deltas = summary['deltas'] as Map<String, dynamic>? ?? {};

    final newTopics = (detail['newTopics'] as List?)?.cast<String>() ?? [];
    final consistent =
        (detail['consistentTopics'] as List?)?.cast<Map<dynamic, dynamic>>() ??
            [];
    final needsWork =
        (detail['needsWork'] as List?)?.cast<Map<dynamic, dynamic>>() ?? [];
    final topicsTried = (detail['topicsTried'] as List?)?.cast<String>() ?? [];
    final path = detail['path'] as Map<String, dynamic>?;
    final daily =
        (detail['daily'] as List?)?.cast<Map<dynamic, dynamic>>() ?? [];
    final streak = detail['streak'] as Map<String, dynamic>? ?? {};
    final mostImproved = detail['mostImproved'] as Map<String, dynamic>?;
    final currentStreak = (streak['current'] as num?)?.toInt() ?? 0;
    final bestStreak = (streak['longest'] as num?)?.toInt() ?? 0;

    final accuracyDelta = (deltas['avgAccuracy'] as num?) ?? 0;
    final quizzesDelta = (deltas['quizzesCompleted'] as num?) ?? 0;
    final activeDays = (current['activeDays'] as num?)?.toInt() ?? 0;
    final quizzes = (current['quizzesCompleted'] as num?)?.toInt() ?? 0;
    final avgAccuracy = (current['avgAccuracy'] as num?)?.toDouble() ?? 0.0;
    final timeSeconds = (current['totalTimeSeconds'] as num?) ?? 0;
    final newTopicsCount = (current['newTopicsCount'] as num?)?.toInt() ?? 0;
    final consistencyScore = periodDays > 0 ? activeDays / periodDays : 0.0;
    final avgQuizTime = quizzes > 0 ? timeSeconds.toDouble() / quizzes : 0.0;
    final avgQuizzesPerActiveDay =
        activeDays > 0 ? quizzes.toDouble() / activeDays : 0.0;

    final strongTopics = consistent
        .map((e) => e['topic']?.toString() ?? '')
        .where((t) => t.isNotEmpty)
        .take(3)
        .toList();
    final weakTopics = needsWork
        .map((e) => e['topic']?.toString() ?? '')
        .where((t) => t.isNotEmpty)
        .take(3)
        .toList();

    final coachSummary = _buildCoachSummary(
      isDaily: isDaily,
      isMonthly: isMonthly,
      quizzes: quizzes,
      avgAccuracy: avgAccuracy,
      accuracyDelta: accuracyDelta,
      activeDays: activeDays,
      periodDays: periodDays,
    );

    final healthScore = ((avgAccuracy * 100) * 0.5 +
            (consistencyScore * 100) * 0.3 +
            ((avgQuizzesPerActiveDay.clamp(0, 3) / 3) * 100) * 0.2)
        .round();

    final actionItems = _buildActionItems(
      isDaily: isDaily,
      weakTopics: weakTopics,
      strongTopics: strongTopics,
      avgAccuracy: avgAccuracy,
      activeDays: activeDays,
      periodDays: periodDays,
      newTopicsCount: newTopicsCount,
    );

    return _ReportData(
      period: period,
      scope: scope,
      startDate: startDate,
      endDate: endDate,
      quizzes: quizzes,
      avgAccuracy: avgAccuracy,
      timeSeconds: timeSeconds,
      activeDays: activeDays,
      newTopicsCount: newTopicsCount,
      periodDays: periodDays,
      accuracyDelta: accuracyDelta,
      quizzesDelta: quizzesDelta,
      topicsTried: topicsTried,
      newTopics: newTopics,
      consistentTopics: consistent,
      needsWork: needsWork,
      mostImproved: mostImproved,
      currentStreak: currentStreak,
      bestStreak: bestStreak,
      daily: daily,
      path: path,
      healthScore: healthScore,
      consistencyScore: consistencyScore,
      avgQuizzesPerActiveDay: avgQuizzesPerActiveDay,
      avgQuizTime: avgQuizTime,
      coachSummary: coachSummary,
      actionItems: actionItems,
      strongTopics: strongTopics,
      weakTopics: weakTopics,
    );
  }

  String _buildCoachSummary({
    required bool isDaily,
    required bool isMonthly,
    required int quizzes,
    required double avgAccuracy,
    required num accuracyDelta,
    required int activeDays,
    required int periodDays,
  }) {
    final accuracyPct = (avgAccuracy * 100).toStringAsFixed(0);
    final deltaPct = (accuracyDelta * 100).toStringAsFixed(0);

    if (isDaily) {
      if (quizzes == 0) {
        return 'No completed quizzes yet today. Start one focused session to establish momentum and set a strong baseline.';
      }
      if (avgAccuracy >= 0.75) {
        return 'Strong daily execution: $quizzes quizzes at $accuracyPct% accuracy. Keep this pace and consolidate with one targeted revision set.';
      }
      return 'You completed $quizzes quizzes at $accuracyPct% accuracy. Prioritize one weak area now to close today with a stronger performance profile.';
    }

    if (isMonthly) {
      return 'Monthly outlook: active on $activeDays of $periodDays days. Accuracy moved by ${deltaPct.startsWith('-') ? '' : '+'}$deltaPct%, indicating ${accuracyDelta >= 0 ? 'steady growth' : 'a temporary dip'} and clear areas for deliberate practice.';
    }

    return 'Weekly review: $quizzes quizzes at $accuracyPct% accuracy, with ${deltaPct.startsWith('-') ? '' : '+'}$deltaPct% change versus last week. Maintain consistency and focus next sessions on lower-accuracy topics.';
  }

  List<String> _buildActionItems({
    required bool isDaily,
    required List<String> weakTopics,
    required List<String> strongTopics,
    required double avgAccuracy,
    required int activeDays,
    required int periodDays,
    required int newTopicsCount,
  }) {
    final items = <String>[];
    if (weakTopics.isNotEmpty) {
      items.add(
          'Run two focused quizzes on ${weakTopics.first} to raise accuracy.');
    }
    if (avgAccuracy < 0.7) {
      items
          .add('Do one revision-first session before your next timed attempt.');
    }
    if (!isDaily && activeDays < (periodDays / 2).ceil()) {
      items.add(
          'Increase cadence: target at least ${(periodDays / 2).ceil()} active days next period.');
    }
    if (!isDaily && newTopicsCount > 0) {
      items.add('Reinforce newly explored topics with one recap quiz each.');
    }
    if (items.isEmpty && strongTopics.isNotEmpty) {
      items.add(
          'Maintain momentum and stretch difficulty on ${strongTopics.first}.');
    }
    if (items.isEmpty) {
      items
          .add('Keep the current rhythm and add one intentional review block.');
    }
    return items.take(3).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final userPath = ref.watch(userPathProvider);
    final scope = userPath != null ? 'path' : 'all';
    final summaryAsync = ref.watch(reportSummaryProvider('$_period:$scope'));
    final detailAsync = ref.watch(reportDetailProvider('$_period:$scope'));

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Reports',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        iconTheme: IconThemeData(color: colorScheme.onSurfaceVariant),
        actions: [
          IconButton(
            tooltip: 'Export PNG',
            icon: const Icon(Icons.image_outlined, size: 20),
            onPressed: _exporting ? null : _exportPng,
          ),
          IconButton(
            tooltip: 'Export PDF',
            icon: const Icon(Icons.picture_as_pdf_outlined, size: 20),
            onPressed: _exporting ? null : _exportPdf,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: _kScreenPadH),
              child: _PeriodToggle(
                value: _period,
                onChanged: (v) => setState(() => _period = v),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: summaryAsync.when(
                data: (summary) {
                  return detailAsync.when(
                    data: (detail) {
                      final data = _parseData(summary, detail);
                      return RepaintBoundary(
                        key: _reportKey,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeInCubic,
                          transitionBuilder: (child, animation) {
                            final slide = Tween<Offset>(
                              begin: const Offset(0, 0.05),
                              end: Offset.zero,
                            ).animate(animation);
                            return FadeTransition(
                              opacity: animation,
                              child: SlideTransition(
                                position: slide,
                                child: child,
                              ),
                            );
                          },
                          child: _buildPeriodView(data),
                        ),
                      );
                    },
                    loading: () => const _ReportLoading(),
                    error: (e, _) => _ReportError(message: e.toString()),
                  );
                },
                loading: () => const _ReportLoading(),
                error: (e, _) => _ReportError(message: e.toString()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodView(_ReportData data) {
    switch (data.period) {
      case 'daily':
        return _DailyReport(key: const ValueKey('daily'), data: data);
      case 'monthly':
        return _MonthlyReport(key: const ValueKey('monthly'), data: data);
      default:
        return _WeeklyReport(key: const ValueKey('weekly'), data: data);
    }
  }
}

class _PeriodToggle extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  const _PeriodToggle({required this.value, required this.onChanged});

  static const _periods = ['daily', 'weekly', 'monthly'];
  static const _labels = ['Daily', 'Weekly', 'Monthly'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: List.generate(_periods.length, (i) {
          final isActive = value == _periods[i];
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(_periods[i]),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                margin: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: isActive
                      ? colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.8)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: isActive
                      ? Border.all(
                          color: colorScheme.outline.withValues(alpha: 0.45),
                        )
                      : null,
                ),
                alignment: Alignment.center,
                child: Text(
                  _labels[i],
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                    color: isActive
                        ? colorScheme.onSurface
                        : colorScheme.onSurfaceVariant,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _DeltaBadge extends StatelessWidget {
  final num value;
  final String suffix;
  final bool isPercent;

  const _DeltaBadge({
    required this.value,
    this.suffix = '',
    this.isPercent = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isPositive = value > 0;
    final isNeutral = value == 0;
    final color = isNeutral
        ? colorScheme.outline
        : (isPositive ? Colors.green.shade400 : Colors.red.shade400);
    final bgColor = color.withValues(alpha: 0.1);
    final sign = isPositive ? '+' : '';
    final displayValue = '$sign${value.toStringAsFixed(0)}$suffix';
    final icon = isNeutral
        ? Icons.remove
        : (isPositive
            ? Icons.arrow_upward_rounded
            : Icons.arrow_downward_rounded);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 3),
          Text(
            displayValue,
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

enum _TopicPillStyle { standard, accent, warning }

class _TopicPill extends StatelessWidget {
  final String label;
  final _TopicPillStyle style;

  const _TopicPill({
    required this.label,
    this.style = _TopicPillStyle.standard,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    Color bg;
    Color textColor;
    Color borderColor;
    switch (style) {
      case _TopicPillStyle.accent:
        bg = colorScheme.primary.withValues(alpha: 0.12);
        textColor = colorScheme.primary;
        borderColor = colorScheme.primary.withValues(alpha: 0.2);
        break;
      case _TopicPillStyle.warning:
        bg = Colors.amber.withValues(alpha: 0.10);
        textColor = Colors.amber;
        borderColor = Colors.amber.withValues(alpha: 0.2);
        break;
      case _TopicPillStyle.standard:
        bg = colorScheme.surfaceContainerHighest.withValues(alpha: 0.4);
        textColor = colorScheme.onSurfaceVariant;
        borderColor = colorScheme.outline.withValues(alpha: 0.3);
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: borderColor),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        text,
        style: theme.textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w600,
          color: colorScheme.onSurfaceVariant,
          letterSpacing: 0.4,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;

  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(_kCardPad),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.surfaceContainerHighest.withValues(alpha: 0.34),
            colorScheme.surfaceContainer.withValues(alpha: 0.18),
          ],
        ),
        borderRadius: BorderRadius.circular(_kCardRadius),
        border: Border.all(
          color: colorScheme.outline.withValues(alpha: 0.24),
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.14),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _ThinDivider extends StatelessWidget {
  const _ThinDivider();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      height: 1,
      color: colorScheme.outline.withValues(alpha: 0.3),
    );
  }
}

String _formatMinutes(num seconds) {
  final mins = (seconds / 60).round();
  if (mins <= 0) return '0m';
  if (mins >= 60) {
    final h = mins ~/ 60;
    final m = mins % 60;
    return m > 0 ? '${h}h ${m}m' : '${h}h';
  }
  return '${mins}m';
}

double _niceAxisInterval(double range) {
  if (range <= 0) return 1;
  final rough = range / 5;
  final magnitude = math.pow(10, (math.log(rough) / math.ln10).floor());
  final normalized = rough / magnitude;

  double nice;
  if (normalized <= 1) {
    nice = 1;
  } else if (normalized <= 2) {
    nice = 2;
  } else if (normalized <= 2.5) {
    nice = 2.5;
  } else if (normalized <= 5) {
    nice = 5;
  } else {
    nice = 10;
  }

  return nice * magnitude;
}

class _DailyReport extends StatelessWidget {
  final _ReportData data;
  const _DailyReport({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DailyHero(data: data),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: _kScreenPadH),
            child: _DailyMetricGrid(data: data),
          ),
          const SizedBox(height: 20),
          _StreakRibbon(
            currentStreak: data.currentStreak,
            bestStreak: data.bestStreak,
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: _kScreenPadH),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SectionLabel('Topics Practiced'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: data.topicsTried.isEmpty
                      ? [
                          const _TopicPill(
                            label: 'None yet',
                            style: _TopicPillStyle.standard,
                          ),
                        ]
                      : data.topicsTried.map((t) {
                          final isNew = data.newTopics.contains(t);
                          return _TopicPill(
                            label: t,
                            style: isNew
                                ? _TopicPillStyle.accent
                                : _TopicPillStyle.standard,
                          );
                        }).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (data.path != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: _kScreenPadH),
              child: _PathProgressCard(path: data.path!, isExpanded: false),
            ),
        ],
      ),
    );
  }
}

class _DailyHero extends StatelessWidget {
  final _ReportData data;
  const _DailyHero({required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final dateStr = DateFormat('EEEE, MMMM d').format(data.endDate);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: _kScreenPadH),
      child: _Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionLabel("Today's Report"),
            Text(
              dateStr,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: colorScheme.onSurface,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              data.coachSummary,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DailyMetricGrid extends StatelessWidget {
  final _ReportData data;
  const _DailyMetricGrid({required this.data});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 12.0;
        final tileWidth = (constraints.maxWidth - gap) / 2;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            SizedBox(
              width: tileWidth,
              child: _MetricTile(
                label: 'Quizzes',
                value: '${data.quizzes}',
                delta: data.quizzesDelta,
                deltaSuffix: '',
                deltaContext: 'vs yesterday',
              ),
            ),
            SizedBox(
              width: tileWidth,
              child: _MetricTile(
                label: 'Accuracy',
                value: '${(data.avgAccuracy * 100).toStringAsFixed(0)}%',
                delta: data.accuracyDelta * 100,
                deltaSuffix: '%',
                deltaContext: 'vs yesterday',
                accentColor: data.avgAccuracy >= 0.7
                    ? Colors.green.shade400
                    : (data.avgAccuracy >= 0.5
                        ? Colors.amber
                        : Colors.red.shade400),
              ),
            ),
            SizedBox(
              width: tileWidth,
              child: _MetricTile(
                label: 'Time Trained',
                value: _formatMinutes(data.timeSeconds),
              ),
            ),
            SizedBox(
              width: tileWidth,
              child: _MetricTile(
                label: 'Topics Practiced',
                value: '${data.topicsTried.length}',
              ),
            ),
          ],
        );
      },
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final num? delta;
  final String? deltaSuffix;
  final Color? accentColor;
  final String? deltaContext;

  const _MetricTile({
    required this.label,
    required this.value,
    this.delta,
    this.deltaSuffix,
    this.accentColor,
    this.deltaContext,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final hasAccent = accentColor != null;

    final content = Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w500,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface,
              height: 1.1,
            ),
          ),
          if (delta != null) ...[
            const SizedBox(height: 8),
            _DeltaBadge(
              value: delta!,
              suffix: deltaSuffix ?? '',
              isPercent: deltaSuffix == '%',
            ),
            if (deltaContext != null) ...[
              const SizedBox(height: 4),
              Text(
                deltaContext!,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 10,
                ),
              ),
            ],
          ],
        ],
      ),
    );

    if (hasAccent) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(_kCardRadius),
        child: Container(
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(_kCardRadius),
            border: Border.all(
              color: colorScheme.outline.withValues(alpha: 0.3),
            ),
          ),
          child: IntrinsicHeight(
            child: Row(
              children: [
                Container(
                  width: 3,
                  decoration: BoxDecoration(
                    color: accentColor,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(_kCardRadius),
                      bottomLeft: Radius.circular(_kCardRadius),
                    ),
                  ),
                ),
                Expanded(child: content),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(_kCardRadius),
        border: Border.all(
          color: colorScheme.outline.withValues(alpha: 0.3),
        ),
      ),
      child: content,
    );
  }
}

class _StreakRibbon extends StatelessWidget {
  final int currentStreak;
  final int bestStreak;
  const _StreakRibbon({required this.currentStreak, required this.bestStreak});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Column(
      children: [
        const _ThinDivider(),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: _kScreenPadH,
            vertical: 16,
          ),
          child: Row(
            children: [
              const Icon(Icons.local_fire_department_rounded,
                  color: Colors.amber, size: 22),
              const SizedBox(width: 8),
              Text(
                '$currentStreak',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'day streak',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              Text(
                'Best: $bestStreak days',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        const _ThinDivider(),
      ],
    );
  }
}

class _ActionBlock extends StatelessWidget {
  final String header;
  final List<String> items;

  const _ActionBlock({required this.header, required this.items});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: _kScreenPadH),
      child: _Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionLabel(header),
            ...items.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${index + 1}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        item,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _PathProgressCard extends StatelessWidget {
  final Map<String, dynamic> path;
  final bool isExpanded;

  const _PathProgressCard({required this.path, this.isExpanded = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final pathName = path['pathName']?.toString() ?? 'Learning Path';
    final completionPct = (path['completionPercent'] as num?)?.toDouble() ?? 0;
    final completed = (path['completedChallenges'] as num?)?.toInt() ?? 0;
    final total = (path['totalChallenges'] as num?)?.toInt() ?? 0;
    final thisP = (path['completedThisPeriod'] as num?)?.toInt() ?? 0;
    final backlog = (path['backlog'] as num?)?.toInt() ?? 0;

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'LEARNING PATH',
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurfaceVariant,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            pathName,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${(completionPct * 100).toStringAsFixed(0)}% complete',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(100),
            child: SizedBox(
              height: 8,
              child: LinearProgressIndicator(
                value: completionPct.clamp(0, 1),
                backgroundColor: colorScheme.outline.withValues(alpha: 0.15),
                valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _MiniStat(label: 'Completed', value: '$completed/$total'),
              const SizedBox(width: 20),
              _MiniStat(label: 'This Period', value: '$thisP'),
              if (isExpanded) ...[
                const SizedBox(width: 20),
                _MiniStat(label: 'Backlog', value: '$backlog'),
              ],
            ],
          ),
          if (!isExpanded && backlog > 0) ...[
            const SizedBox(height: 8),
            Text(
              '$backlog challenges remaining',
              style: theme.textTheme.labelMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  const _MiniStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}

class _WeeklyReport extends StatelessWidget {
  final _ReportData data;
  const _WeeklyReport({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final dateRange =
        '${DateFormat('MMM d').format(data.startDate)} – ${DateFormat('MMM d').format(data.endDate)}';

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _WeeklyHeader(data: data, dateRange: dateRange),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: _kScreenPadH),
            child: _WeeklyTrendChart(data: data),
          ),
          const SizedBox(height: 20),
          _WeeklyMetricStrip(data: data),
          const SizedBox(height: 20),
          if (data.mostImproved != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: _kScreenPadH),
              child: _MostImprovedCard(mostImproved: data.mostImproved!),
            ),
          if (data.mostImproved != null) const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: _kScreenPadH),
            child: _WeeklyTopTopicsSection(data: data),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: _kScreenPadH),
            child: _WeeklyStreakAndTopics(data: data),
          ),
          if (data.path != null) const SizedBox(height: 20),
          if (data.path != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: _kScreenPadH),
              child: _PathProgressCard(path: data.path!, isExpanded: false),
            ),
          if (data.path != null) const SizedBox(height: 20),
          const SizedBox(height: 20),
          _ActionBlock(
            header: 'FOCUS THIS WEEK',
            items: data.actionItems,
          ),
        ],
      ),
    );
  }
}

class _WeeklyHeader extends StatelessWidget {
  final _ReportData data;
  final String dateRange;
  const _WeeklyHeader({required this.data, required this.dateRange});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(_kScreenPadH, 12, _kScreenPadH, 0),
      child: _Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionLabel('This Week'),
            Text(
              dateRange,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: colorScheme.onSurface,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              data.coachSummary,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: data.activeDays >= 5
                    ? const Color(0xFF34C759).withValues(alpha: 0.12)
                    : const Color(0xFFF59E0B).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(100),
                border: Border.all(
                  color: data.activeDays >= 5
                      ? const Color(0xFF34C759).withValues(alpha: 0.2)
                      : const Color(0xFFF59E0B).withValues(alpha: 0.2),
                ),
              ),
              child: Text(
                'Active ${data.activeDays} of 7 days',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: data.activeDays >= 5
                      ? const Color(0xFF34C759)
                      : const Color(0xFFF59E0B),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeeklyTrendChart extends StatelessWidget {
  final _ReportData data;
  const _WeeklyTrendChart({required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final sorted = [...data.daily]..sort((a, b) =>
        ((a['date'] as num?) ?? 0).compareTo((b['date'] as num?) ?? 0));

    if (sorted.isEmpty) {
      return _Card(
        child: SizedBox(
          height: 200,
          child: Center(
            child: Text(
              'No trend data yet',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      );
    }

    final quizValues = sorted
        .map((e) => ((e['quizzesCompleted'] as num?) ?? 0).toDouble())
        .toList();
    final maxQuizzes = quizValues.fold<double>(1, math.max);
    final yMax = math.max(4.0, (maxQuizzes * 1.15).ceilToDouble());
    final yInterval = _niceAxisInterval(yMax);
    final bestIndex = quizValues.indexOf(quizValues.reduce(math.max));
    final bestDate = DateTime.fromMillisecondsSinceEpoch(
      ((sorted[bestIndex]['date'] as num?) ?? 0).toInt(),
    );

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionLabel('Weekly Activity'),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                minY: 0,
                maxY: yMax,
                alignment: BarChartAlignment.spaceEvenly,
                barGroups: List.generate(sorted.length, (i) {
                  final q =
                      ((sorted[i]['quizzesCompleted'] as num?) ?? 0).toDouble();
                  final a = ((sorted[i]['avgAccuracy'] as num?) ?? 0)
                      .toDouble()
                      .clamp(0.0, 1.0);
                  final barColor = Color.lerp(
                    colorScheme.primary.withValues(alpha: 0.46),
                    colorScheme.primary,
                    a,
                  )!;
                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: q,
                        width: 16,
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(6)),
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            barColor.withValues(alpha: 0.86),
                            barColor,
                          ],
                        ),
                      ),
                    ],
                  );
                }),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: yInterval,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: colorScheme.outline.withValues(alpha: 0.16),
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border(
                    left: BorderSide(
                        color: colorScheme.outline.withValues(alpha: 0.35)),
                    bottom: BorderSide(
                        color: colorScheme.outline.withValues(alpha: 0.35)),
                    top: BorderSide.none,
                    right: BorderSide.none,
                  ),
                ),
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => colorScheme.surface,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final day = sorted[group.x];
                      final dayLabel = DateFormat('EEE').format(
                        DateTime.fromMillisecondsSinceEpoch(
                          ((day['date'] as num?) ?? 0).toInt(),
                        ),
                      );
                      final acc =
                          (((day['avgAccuracy'] as num?) ?? 0).toDouble() * 100)
                              .toStringAsFixed(0);
                      return BarTooltipItem(
                        '$dayLabel\n${rod.toY.toStringAsFixed(0)} quizzes\n$acc% accuracy',
                        TextStyle(
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      interval: yInterval,
                      getTitlesWidget: (value, meta) => SideTitleWidget(
                        meta: meta,
                        child: Text(
                          value.toStringAsFixed(0),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ),
                    axisNameWidget: Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Text(
                        'Quizzes',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 1,
                      reservedSize: 28,
                      getTitlesWidget: (value, meta) {
                        final i = value.round();
                        if (i < 0 || i >= sorted.length) {
                          return const SizedBox.shrink();
                        }
                        final date = DateTime.fromMillisecondsSinceEpoch(
                          ((sorted[i]['date'] as num?) ?? 0).toInt(),
                        );
                        return SideTitleWidget(
                          meta: meta,
                          child: Text(
                            DateFormat('E').format(date).substring(0, 2),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                              fontSize: 10,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
              duration: const Duration(milliseconds: 220),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _TrendChip(
                label: 'Peak Day',
                value:
                    '${DateFormat('EEE').format(bestDate)} • ${quizValues[bestIndex].toStringAsFixed(0)} quizzes',
              ),
              _TrendChip(
                label: 'Active Days',
                value: '${data.activeDays}/7',
              ),
              _TrendChip(
                label: 'Weekly Accuracy',
                value: '${(data.avgAccuracy * 100).toStringAsFixed(0)}%',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WeeklyMetricStrip extends StatelessWidget {
  final _ReportData data;
  const _WeeklyMetricStrip({required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final metrics = [
      _StripMetric('Quizzes', '${data.quizzes}', Icons.quiz_outlined),
      _StripMetric('Accuracy',
          '${(data.avgAccuracy * 100).toStringAsFixed(0)}%', Icons.gps_fixed),
      _StripMetric('Time Trained', _formatMinutes(data.timeSeconds),
          Icons.timer_outlined),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: _kScreenPadH),
      child: LayoutBuilder(
        builder: (context, constraints) {
          const gap = 10.0;
          final isCompact = constraints.maxWidth < 380;
          final columns = isCompact ? 2 : 3;
          final tileWidth =
              (constraints.maxWidth - gap * (columns - 1)) / columns;

          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: metrics.map((m) {
              return SizedBox(
                width: tileWidth,
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(_kCardRadius),
                    border: Border.all(
                        color: colorScheme.outline.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(m.icon,
                          size: 16, color: colorScheme.onSurfaceVariant),
                      const SizedBox(height: 8),
                      Text(
                        m.value,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: colorScheme.onSurface,
                          fontSize: 19,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        m.label,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}

class _StripMetric {
  final String label;
  final String value;
  final IconData icon;
  const _StripMetric(this.label, this.value, this.icon);
}

class _WeeklyTopTopicsSection extends StatelessWidget {
  final _ReportData data;
  const _WeeklyTopTopicsSection({required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final rows = <Map<String, dynamic>>[];
    final byTopic = <String, Map<String, dynamic>>{};

    for (final item in data.consistentTopics) {
      final topic = item['topic']?.toString() ?? '';
      if (topic.isEmpty) continue;
      byTopic[topic] = {
        'topic': topic,
        'attempts': (item['attempts'] as num?)?.toInt() ?? 0,
        'accuracy': (item['accuracy'] as num?)?.toDouble(),
      };
    }
    for (final item in data.needsWork) {
      final topic = item['topic']?.toString() ?? '';
      if (topic.isEmpty) continue;
      final existing = byTopic[topic] ?? <String, dynamic>{'topic': topic};
      existing['attempts'] = (item['attempts'] as num?)?.toInt() ??
          (existing['attempts'] as int? ?? 0);
      existing['accuracy'] = (item['accuracy'] as num?)?.toDouble();
      byTopic[topic] = existing;
    }

    rows.addAll(byTopic.values);
    rows.sort((a, b) =>
        ((b['attempts'] as int?) ?? 0).compareTo((a['attempts'] as int?) ?? 0));
    final topRows = rows.take(3).toList();

    final avgQuizSeconds =
        data.quizzes > 0 ? data.timeSeconds.toDouble() / data.quizzes : 0.0;

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionLabel('Top Topics Practiced'),
          if (topRows.isEmpty)
            Text(
              'No topic-level activity this week yet.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            )
          else ...[
            Row(
              children: [
                Expanded(
                  flex: 5,
                  child: Text(
                    'Topic',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Attempts',
                    textAlign: TextAlign.right,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Accuracy',
                    textAlign: TextAlign.right,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Est. Time',
                    textAlign: TextAlign.right,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ...topRows.asMap().entries.map((entry) {
              final index = entry.key;
              final row = entry.value;
              final topic = row['topic']?.toString() ?? '';
              final attempts = (row['attempts'] as int?) ?? 0;
              final accuracy =
                  (row['accuracy'] as double?) ?? data.avgAccuracy.toDouble();
              final estimatedTimeSeconds = attempts * avgQuizSeconds;

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  children: [
                    if (index > 0)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Container(
                          height: 1,
                          color: colorScheme.outline.withValues(alpha: 0.14),
                        ),
                      ),
                    Row(
                      children: [
                        Expanded(
                          flex: 5,
                          child: Text(
                            topic,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurface,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            '$attempts',
                            textAlign: TextAlign.right,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurface,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            '${(accuracy * 100).toStringAsFixed(0)}%',
                            textAlign: TextAlign.right,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurface,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            _formatMinutes(estimatedTimeSeconds),
                            textAlign: TextAlign.right,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
          ],
          if (topRows.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Estimated from your average quiz duration this week.',
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontSize: 10,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MostImprovedCard extends StatelessWidget {
  final Map<String, dynamic> mostImproved;
  const _MostImprovedCard({required this.mostImproved});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final topic = mostImproved['topic']?.toString() ?? '';
    final delta =
        ((mostImproved['accuracyDelta'] as num?) ?? 0).toDouble() * 100;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(_kCardPad),
      decoration: BoxDecoration(
        color: Colors.green.shade400.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(_kCardRadius),
        border:
            Border.all(color: Colors.green.shade400.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.green.shade400.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.trending_up_rounded,
                color: Colors.green.shade400, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Most Improved',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: Colors.green.shade400,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  topic,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
          _DeltaBadge(value: delta, suffix: '%', isPercent: true),
        ],
      ),
    );
  }
}

class _WeeklyStreakAndTopics extends StatelessWidget {
  final _ReportData data;
  const _WeeklyStreakAndTopics({required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return _Card(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(Icons.local_fire_department_rounded,
              color: Colors.amber, size: 20),
          const SizedBox(width: 10),
          Text(
            'Streak',
            style: theme.textTheme.labelMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          Text(
            '${data.currentStreak}d',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'Best ${data.bestStreak}d',
            style: theme.textTheme.labelMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthlyReport extends StatelessWidget {
  final _ReportData data;
  const _MonthlyReport({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _MonthlyHero(data: data),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: _kScreenPadH),
            child: _MonthlySnapshot(data: data),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: _kScreenPadH),
            child: _MonthlyActivityHeatmap(data: data),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: _kScreenPadH),
            child: _MonthlyMomentum(data: data),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: _kScreenPadH),
            child: _MonthlyTopicMatrix(data: data),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: _kScreenPadH),
            child: _FocusNextMonth(data: data),
          ),
          const SizedBox(height: 20),
          if (data.path != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: _kScreenPadH),
              child: _PathProgressCard(path: data.path!, isExpanded: true),
            ),
          if (data.path != null) const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: _kScreenPadH),
            child: const _ExportButton(),
          ),
        ],
      ),
    );
  }
}

class _MonthlyHero extends StatelessWidget {
  final _ReportData data;
  const _MonthlyHero({required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final monthLabel = DateFormat('MMMM yyyy').format(data.endDate);
    final dateRange =
        '${DateFormat('MMM d').format(data.startDate)} – ${DateFormat('MMM d').format(data.endDate)}';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: _kScreenPadH),
      child: _Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionLabel('Monthly Report'),
            Text(
              monthLabel,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: colorScheme.onSurface,
                height: 1.15,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              dateRange,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              data.coachSummary,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MonthlySnapshot extends StatelessWidget {
  final _ReportData data;
  const _MonthlySnapshot({required this.data});

  @override
  Widget build(BuildContext context) {
    final stats = [
      _SnapshotStat(
        label: 'Quizzes Completed',
        value: '${data.quizzes}',
        delta: data.quizzesDelta,
        icon: Icons.task_alt_rounded,
      ),
      _SnapshotStat(
        label: 'Accuracy',
        value: '${(data.avgAccuracy * 100).toStringAsFixed(0)}%',
        delta: data.accuracyDelta * 100,
        isPercent: true,
        icon: Icons.gps_fixed_rounded,
      ),
      _SnapshotStat(
        label: 'Active Days',
        value: '${data.activeDays}/${data.periodDays}',
        icon: Icons.calendar_today_rounded,
      ),
      _SnapshotStat(
        label: 'Time Trained',
        value: _formatMinutes(data.timeSeconds),
        icon: Icons.timer_outlined,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 10.0;
        final columns = constraints.maxWidth < 420 ? 2 : 4;
        final itemWidth =
            (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: stats
              .map((item) => SizedBox(
                    width: itemWidth,
                    child: _SnapshotStatTile(item: item),
                  ))
              .toList(),
        );
      },
    );
  }
}

class _SnapshotStat {
  final String label;
  final String value;
  final num? delta;
  final bool isPercent;
  final IconData icon;

  const _SnapshotStat({
    required this.label,
    required this.value,
    required this.icon,
    this.delta,
    this.isPercent = false,
  });
}

class _SnapshotStatTile extends StatelessWidget {
  final _SnapshotStat item;
  const _SnapshotStatTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.26),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(item.icon, size: 14, color: colorScheme.onSurfaceVariant),
          const SizedBox(height: 8),
          Text(
            item.value,
            style: theme.textTheme.titleMedium?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            item.label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          if (item.delta != null) ...[
            const SizedBox(height: 8),
            _DeltaBadge(
              value: item.delta!,
              suffix: item.isPercent ? '%' : '',
              isPercent: item.isPercent,
            ),
          ],
        ],
      ),
    );
  }
}

class _MonthlyMomentum extends StatelessWidget {
  final _ReportData data;
  const _MonthlyMomentum({required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionLabel('Momentum'),
          Text(
            'Streak performance this month',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 360;
              final currentTile = _MomentumTile(
                icon: Icons.local_fire_department_rounded,
                label: 'Current Streak',
                value: '${data.currentStreak} days',
              );
              final bestTile = _MomentumTile(
                icon: Icons.emoji_events_outlined,
                label: 'Best This Month',
                value: '${data.bestStreak} days',
              );

              if (compact) {
                return Column(
                  children: [
                    currentTile,
                    const SizedBox(height: 10),
                    bestTile,
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: currentTile),
                  const SizedBox(width: 10),
                  Expanded(child: bestTile),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _MomentumTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _MomentumTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.24),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TrendChip extends StatelessWidget {
  final String label;
  final String value;

  const _TrendChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.24),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.18)),
      ),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: '$label: ',
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            TextSpan(
              text: value,
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MonthlyActivityHeatmap extends StatelessWidget {
  final _ReportData data;
  const _MonthlyActivityHeatmap({required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final sorted = [...data.daily]..sort((a, b) =>
        ((a['date'] as num?) ?? 0).compareTo((b['date'] as num?) ?? 0));

    if (sorted.isEmpty) {
      return _Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionLabel('Activity Heatmap'),
            Text(
              'No activity data yet',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    final dayMap = <String, double>{};
    for (final item in sorted) {
      final date = DateTime.fromMillisecondsSinceEpoch(
        ((item['date'] as num?) ?? 0).toInt(),
      );
      final key = DateFormat('yyyy-MM-dd').format(date);
      final q = ((item['quizzesCompleted'] as num?) ?? 0).toDouble();
      dayMap[key] = (dayMap[key] ?? 0) + q;
    }

    final start =
        DateTime(data.startDate.year, data.startDate.month, data.startDate.day);
    final end =
        DateTime(data.endDate.year, data.endDate.month, data.endDate.day);

    final maxQuiz =
        dayMap.values.isEmpty ? 1.0 : dayMap.values.reduce(math.max);
    const cellGap = 4.0;
    final leading = start.weekday - 1;
    final cellCount = leading + end.difference(start).inDays + 1;

    return _Card(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final cellSize =
              ((constraints.maxWidth - cellGap * 6) / 7).clamp(14.0, 22.0);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionLabel('Activity Heatmap'),
              Text(
                'Quizzes completed across ${DateFormat('MMMM').format(data.endDate)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 10),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: cellCount,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  mainAxisSpacing: cellGap,
                  crossAxisSpacing: cellGap,
                  mainAxisExtent: cellSize,
                ),
                itemBuilder: (context, index) {
                  if (index < leading) {
                    return const SizedBox.shrink();
                  }
                  final day = start.add(Duration(days: index - leading));
                  final key = DateFormat('yyyy-MM-dd').format(day);
                  final quizzes = dayMap[key] ?? 0;
                  final intensity =
                      maxQuiz <= 0 ? 0.0 : (quizzes / maxQuiz).clamp(0.0, 1.0);
                  final fill = Color.lerp(
                    colorScheme.surfaceContainerHighest.withValues(alpha: 0.22),
                    colorScheme.primary.withValues(alpha: 0.84),
                    intensity,
                  )!;

                  return Tooltip(
                    message:
                        '${DateFormat('MMM d').format(day)}: ${quizzes.toStringAsFixed(0)} quizzes',
                    child: Container(
                      decoration: BoxDecoration(
                        color: fill,
                        borderRadius: BorderRadius.circular(3),
                        border: Border.all(
                          color: colorScheme.outline.withValues(alpha: 0.12),
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Text(
                    'Low',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 6),
                  ...List.generate(4, (i) {
                    final t = i / 3;
                    return Container(
                      width: 16,
                      height: 8,
                      margin: const EdgeInsets.only(right: 4),
                      decoration: BoxDecoration(
                        color: Color.lerp(
                          colorScheme.surfaceContainerHighest
                              .withValues(alpha: 0.22),
                          colorScheme.primary.withValues(alpha: 0.84),
                          t,
                        ),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    );
                  }),
                  Text(
                    'High',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MonthlyTopicMatrix extends StatelessWidget {
  final _ReportData data;
  const _MonthlyTopicMatrix({required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    const goodColor = Color(0xFF34C759);
    const focusColor = Color(0xFFF59E0B);

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionLabel('Topic Performance'),
          const SizedBox(height: 2),
          Text(
            'Where you are strongest and what needs deliberate practice next.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          if (data.mostImproved != null) ...[
            _MostImprovedCard(mostImproved: data.mostImproved!),
            const SizedBox(height: 12),
          ],
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 420;
              final strongPanel = _TopicListPanel(
                title: 'Strong',
                color: goodColor,
                items: data.consistentTopics.take(3).toList(),
                fallbackAccuracy: 0.78,
              );
              final focusPanel = _TopicListPanel(
                title: 'Needs Focus',
                color: focusColor,
                items: data.needsWork.take(3).toList(),
                fallbackAccuracy: 0.45,
              );

              if (compact) {
                return Column(
                  children: [
                    strongPanel,
                    const SizedBox(height: 10),
                    focusPanel,
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: strongPanel),
                  const SizedBox(width: 10),
                  Expanded(child: focusPanel),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _TopicListPanel extends StatelessWidget {
  final String title;
  final Color color;
  final List<Map<dynamic, dynamic>> items;
  final double fallbackAccuracy;

  const _TopicListPanel({
    required this.title,
    required this.color,
    required this.items,
    required this.fallbackAccuracy,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (items.isEmpty)
            Text(
              'No data yet',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            )
          else
            ...items.map((item) {
              final topic = item['topic']?.toString() ?? '';
              final rawAccuracy = (item['accuracy'] as num?)?.toDouble();
              final accuracy =
                  (rawAccuracy ?? fallbackAccuracy).clamp(0.0, 1.0);
              final attempts = (item['attempts'] as num?)?.toInt();
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: colorScheme.surface.withValues(alpha: 0.78),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: colorScheme.outline.withValues(alpha: 0.16)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              topic,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurface,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (attempts != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                '$attempts attempts',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: color,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(999),
                              child: LinearProgressIndicator(
                                minHeight: 6,
                                value: accuracy,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(color),
                                backgroundColor:
                                    colorScheme.outline.withValues(alpha: 0.16),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${(accuracy * 100).toStringAsFixed(0)}%',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: color,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _FocusNextMonth extends StatelessWidget {
  final _ReportData data;
  const _FocusNextMonth({required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final highlights = data.actionItems.take(3).toList();
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionLabel('Coach Summary'),
          Text(
            data.coachSummary,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurface,
              height: 1.55,
            ),
          ),
          if (highlights.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Key Next Steps',
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            ...highlights.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        margin: const EdgeInsets.only(top: 6),
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withValues(alpha: 0.75),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            height: 1.45,
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ],
      ),
    );
  }
}

class _ExportButton extends StatelessWidget {
  const _ExportButton();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(_kCardRadius),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.30)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.share_outlined,
              size: 18, color: colorScheme.primary.withValues(alpha: 0.9)),
          const SizedBox(width: 10),
          Text(
            'Export Report',
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: colorScheme.primary.withValues(alpha: 0.9),
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportLoading extends StatelessWidget {
  const _ReportLoading();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation<Color>(
                colorScheme.primary.withValues(alpha: 0.7),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Loading report...',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportError extends StatelessWidget {
  final String message;
  const _ReportError({required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 40,
              color: Colors.red.shade400.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 12),
            Text(
              'Error loading report',
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
