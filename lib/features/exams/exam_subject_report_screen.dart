import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:neurobits/core/providers.dart';
import 'package:neurobits/services/convex_client_service.dart';

class ExamSubjectReportScreen extends ConsumerStatefulWidget {
  final String targetId;

  const ExamSubjectReportScreen({
    super.key,
    required this.targetId,
  });

  @override
  ConsumerState<ExamSubjectReportScreen> createState() =>
      _ExamSubjectReportScreenState();
}

class _ExamSubjectReportScreenState
    extends ConsumerState<ExamSubjectReportScreen> {
  String _period = 'weekly';
  String _chartView = 'momentum';

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

  int _defaultWindowDays(String period) {
    switch (period) {
      case 'daily':
        return 1;
      case 'monthly':
        return 30;
      default:
        return 7;
    }
  }

  String _pluralize(String word, int count) {
    return '$count $word${count == 1 ? '' : 's'}';
  }

  String _changeNarrative({
    required double delta,
    required int attempts,
    required double currentValue,
  }) {
    if (attempts < 2) {
      return 'Early baseline at ${(currentValue * 100).toStringAsFixed(0)}%';
    }
    final pct = delta * 100;
    if (pct >= 1) return 'Up ${pct.toStringAsFixed(1)} pts vs previous period';
    if (pct <= -1) {
      return 'Down ${pct.abs().toStringAsFixed(1)} pts; one focused session can recover this';
    }
    return 'Stable vs previous period';
  }

  Color _changeColor(BuildContext context, double value) {
    final theme = Theme.of(context).colorScheme;
    if (value > 0.0001) return Colors.green;
    if (value < -0.0001) return theme.tertiary;
    return theme.onSurfaceVariant;
  }

  String _signalConfidenceLabel(int attempts) {
    if (attempts >= 10) return 'High confidence insights';
    if (attempts >= 4) return 'Building confidence insights';
    return 'Early signal insights';
  }

  String _reportHeadline({
    required double avgMarksPct,
    required double marksDeltaPct,
    required String momentumLabel,
    required int attempts,
  }) {
    if (attempts < 2) {
      return 'This is your first signal. Complete two more sessions for a reliable trend.';
    }
    if (avgMarksPct >= 0.72 && marksDeltaPct >= 0) {
      return 'Strong work. You are sustaining a high-performance band.';
    }
    if (marksDeltaPct >= 0.02) {
      return 'Great momentum. Your marks are trending upward.';
    }
    if (momentumLabel == 'slipping') {
      return 'You are close. A focused reset session should lift performance quickly.';
    }
    return 'Good foundation. Keep your rhythm and build on current gains.';
  }

  String _formatDuration(int totalSeconds) {
    if (totalSeconds <= 0) return '0m';
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    if (hours <= 0) return '${minutes}m';
    return '${hours}h ${minutes}m';
  }

  String _momentumText(String label) {
    switch (label) {
      case 'strong_upward':
        return 'Strong upward momentum';
      case 'building':
        return 'Momentum is building';
      case 'slipping':
        return 'Recent dip detected; quick correction will recover this';
      case 'stable':
        return 'Stable performance band';
      default:
        return 'Early signal';
    }
  }

  String _speedSignalText(String signal) {
    switch (signal) {
      case 'rushing':
        return 'You may be rushing; slow slightly for higher marks.';
      case 'overthinking':
        return 'You may be overthinking; tighter pacing should help.';
      case 'balanced':
        return 'Pacing looks balanced for current accuracy.';
      default:
        return 'Not enough pace data yet.';
    }
  }

  String _gradeStatusNarrative(String gradeStatus) {
    switch (gradeStatus) {
      case 'on_track':
        return 'On track';
      case 'close':
        return 'Close to target';
      case 'at_risk':
        return 'Focus window to close the target gap';
      default:
        return 'Early signal';
    }
  }

  Map<String, dynamic> _buildReportPracticePreset({
    required bool includeHints,
    required String difficulty,
    int questionCount = 12,
  }) {
    final count = questionCount.clamp(8, 20);
    const timePerQuestion = 70;
    return {
      'questionCount': count,
      'timePerQuestion': timePerQuestion,
      'totalTimeLimit': count * timePerQuestion,
      'timedMode': true,
      'difficulty': difficulty,
      'includeCodeChallenges': false,
      'includeMcqs': true,
      'includeInput': true,
      'includeFillBlank': false,
      'includeHints': includeHints,
      'includeImageQuestions': false,
      'examModeProfile': 'exam_standard',
      'autoStart': true,
    };
  }

  void _startPractice({
    required BuildContext context,
    required String targetId,
    required String topic,
    required Map<String, dynamic> preset,
  }) {
    final encoded = Uri.encodeComponent(topic);
    context.push('/topic/$encoded', extra: {
      'examTargetId': targetId,
      'quizPreset': preset,
    });
  }

  @override
  Widget build(BuildContext context) {
    final dashboardAsync =
        ref.watch(userExamDashboardByTargetProvider(widget.targetId));
    final reportAsync = ref.watch(
      userExamSubjectReportProvider(
        ExamSubjectReportArgs(targetId: widget.targetId, period: _period),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Subject Report'),
      ),
      body: reportAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Could not load subject report: $error'),
          ),
        ),
        data: (report) {
          final target = report['target'] as Map<String, dynamic>?;
          if (target == null) {
            return const Center(child: Text('Subject target not found.'));
          }

          final subject = target['subject']?.toString() ?? 'Subject';
          final board = target['board']?.toString() ?? '';
          final level = target['level']?.toString() ?? '';
          final family = target['examFamily']?.toString().toUpperCase() ?? '';

          final avgMarksPct = (report['avgMarksPct'] as num?)?.toDouble() ?? 0;
          final avgAccuracy = (report['avgAccuracy'] as num?)?.toDouble() ?? 0;
          final marksDeltaPct =
              (report['marksDeltaPct'] as num?)?.toDouble() ?? 0;
          final accuracyDeltaPct =
              (report['accuracyDeltaPct'] as num?)?.toDouble() ?? 0;
          final totalStudySeconds = convexInt(report['totalStudySeconds']);
          final consistency = report['consistency'] is Map
              ? toMap(report['consistency'])
              : const <String, dynamic>{};
          final progression = report['progression'] is Map
              ? toMap(report['progression'])
              : const <String, dynamic>{};
          final execution = report['execution'] is Map
              ? toMap(report['execution'])
              : const <String, dynamic>{};
          final motivation = report['motivation'] is Map
              ? toMap(report['motivation'])
              : const <String, dynamic>{};
          final errorProfile = isConvexList(report['errorProfile'])
              ? toMapList(report['errorProfile'])
              : <Map<String, dynamic>>[];
          final insightActions = isConvexList(report['insightActions'])
              ? toMapList(report['insightActions'])
              : <Map<String, dynamic>>[];

          final trend = isConvexList(report['trend'])
              ? toMapList(report['trend'])
              : <Map<String, dynamic>>[];
          final topics = isConvexList(report['topicBreakdown'])
              ? toMapList(report['topicBreakdown'])
              : <Map<String, dynamic>>[];
          final topWeakTopic = topics.isNotEmpty
              ? topics.first['topic']?.toString().trim() ?? ''
              : '';

          final activeDays = convexInt(consistency['activeDays']);
          final windowDays = convexInt(consistency['windowDays']);
          final completionRate =
              (consistency['completionRate'] as num?)?.toDouble() ?? 0;
          final dailyMinutes =
              (consistency['dailyMinutes'] as num?)?.toDouble() ?? 0;

          final trendSlopePct =
              (progression['trendSlopePct'] as num?)?.toDouble() ?? 0;
          final volatilityPct =
              (progression['volatilityPct'] as num?)?.toDouble() ?? 0;
          final bestRunDays = convexInt(progression['bestRunDays']);
          final momentumLabel =
              progression['momentumLabel']?.toString() ?? 'build_evidence';

          final avgSecondsPerQuestion =
              (execution['avgSecondsPerQuestion'] as num?)?.toDouble() ?? 0;
          final speedAccuracySignal =
              execution['speedAccuracySignal']?.toString() ??
                  'insufficient_data';

          final winLinesRaw = motivation['wins'];
          final winLines = winLinesRaw is List
              ? winLinesRaw
                  .map((line) => line.toString().trim())
                  .where((line) => line.isNotEmpty)
                  .toList()
              : <String>[];
          final nextMilestone =
              motivation['nextMilestone']?.toString().trim() ?? '';

          final dashboard = dashboardAsync.valueOrNull;
          final currentGrade = dashboard?['currentGrade']?.toString();
          final targetGrade = dashboard?['targetGrade']?.toString();
          final projectedGrade = convexInt(dashboard?['projectedGrade']);
          final gradeStatus =
              dashboard?['gradeStatus']?.toString() ?? 'no_target';
          final totalAttempts = convexInt(report['totalAttempts']);
          final hasEvidence = totalAttempts > 0;
          final activeDaysFromTrend =
              trend.where((point) => convexInt(point['attempts']) > 0).length;
          final displayWindowDays =
              windowDays > 0 ? windowDays : _defaultWindowDays(_period);
          final displayActiveDays = math.max(activeDays, activeDaysFromTrend);
          final hasTrajectoryEvidence = totalAttempts >= 3;
          final hasTrendEvidence = activeDaysFromTrend >= 2;
          final headline = _reportHeadline(
            avgMarksPct: avgMarksPct,
            marksDeltaPct: marksDeltaPct,
            momentumLabel: momentumLabel,
            attempts: totalAttempts,
          );
          final confidenceLabel = _signalConfidenceLabel(totalAttempts);
          final showMotivation =
              winLines.isNotEmpty || nextMilestone.trim().isNotEmpty;
          final firstInsightAction =
              insightActions.isNotEmpty ? toMap(insightActions.first) : null;
          final fallbackPracticeTopic = topWeakTopic.isNotEmpty
              ? '$subject $topWeakTopic'
              : '$subject timed mixed practice';
          final actionTitle =
              firstInsightAction?['title']?.toString().trim().isNotEmpty == true
                  ? firstInsightAction!['title'].toString().trim()
                  : 'Start focused recovery';
          final actionWhyNow =
              firstInsightAction?['whyNow']?.toString().trim() ?? '';
          final actionWhyItWorks =
              firstInsightAction?['whyItWorks']?.toString().trim() ?? '';
          final actionTopic =
              firstInsightAction?['topic']?.toString().trim().isNotEmpty == true
                  ? firstInsightAction!['topic'].toString().trim()
                  : fallbackPracticeTopic;
          final actionPreset = firstInsightAction?['quizPreset'] is Map
              ? toMap(firstInsightAction!['quizPreset'])
              : _buildReportPracticePreset(
                  includeHints: avgMarksPct < 0.6,
                  difficulty: avgMarksPct < 0.55 ? 'Easy' : 'Medium',
                  questionCount: 12,
                );
          final chartOptions = <String>[
            if (hasEvidence) 'momentum',
            if (hasEvidence) 'rhythm',
            if (topics.isNotEmpty) 'topics',
            if (errorProfile.isNotEmpty) 'errors',
          ];
          if (chartOptions.isNotEmpty && !chartOptions.contains(_chartView)) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              setState(() => _chartView = chartOptions.first);
            });
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$subject Report',
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        [family, board, level]
                            .where((part) => part.trim().isNotEmpty)
                            .join(' • '),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: ['daily', 'weekly', 'monthly'].map((period) {
                          return ChoiceChip(
                            selected: _period == period,
                            label: Text(_periodLabel(period)),
                            onSelected: (_) {
                              setState(() {
                                _period = period;
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (hasEvidence)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'At a glance',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          headline,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _SignalChip(
                              label: hasTrajectoryEvidence
                                  ? _momentumText(momentumLabel)
                                  : 'Trend unlocks after 3 sessions',
                              icon: Icons.trending_up,
                            ),
                            _SignalChip(
                              label: confidenceLabel,
                              icon: Icons.insights,
                            ),
                            _SignalChip(
                              label:
                                  '${_pluralize('session', totalAttempts)} in this ${_periodLabel(_period).toLowerCase()} window',
                              icon: Icons.fact_check,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              if (hasEvidence) const SizedBox(height: 12),
              if (hasEvidence)
                GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 1.55,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _ReportMetric(
                      label: 'Avg marks',
                      value: '${(avgMarksPct * 100).toStringAsFixed(0)}%',
                      subtitle: _changeNarrative(
                        delta: marksDeltaPct,
                        attempts: totalAttempts,
                        currentValue: avgMarksPct,
                      ),
                      subtitleColor: totalAttempts < 2
                          ? Theme.of(context).colorScheme.onSurfaceVariant
                          : _changeColor(context, marksDeltaPct),
                    ),
                    _ReportMetric(
                      label: 'Avg accuracy',
                      value: '${(avgAccuracy * 100).toStringAsFixed(0)}%',
                      subtitle: _changeNarrative(
                        delta: accuracyDeltaPct,
                        attempts: totalAttempts,
                        currentValue: avgAccuracy,
                      ),
                      subtitleColor: totalAttempts < 2
                          ? Theme.of(context).colorScheme.onSurfaceVariant
                          : _changeColor(context, accuracyDeltaPct),
                    ),
                    _ReportMetric(
                      label: 'Sessions',
                      value: totalAttempts.toString(),
                      subtitle:
                          '${displayActiveDays.toString()}/$displayWindowDays active days',
                    ),
                    _ReportMetric(
                      label: 'Study time',
                      value: _formatDuration(totalStudySeconds),
                      subtitle:
                          '${dailyMinutes.toStringAsFixed(0)}m/day • ${(completionRate * 100).toStringAsFixed(0)}% completion',
                    ),
                  ],
                )
              else
                _ReportEmptyStateCard(subject: subject),
              if (hasEvidence) ...[
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Next best move',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          hasTrajectoryEvidence
                              ? _momentumText(momentumLabel)
                              : 'Build your baseline: complete 2 more sessions this week.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 6),
                        _ReportActionRow(
                          title: actionTitle,
                          detail: actionWhyNow.isNotEmpty
                              ? actionWhyNow
                              : actionTopic,
                          cta: 'Start',
                          onPressed: () => _startPractice(
                            context: context,
                            targetId: widget.targetId,
                            topic: actionTopic,
                            preset: actionPreset,
                          ),
                        ),
                        if (actionWhyItWorks.isNotEmpty)
                          Text(
                            actionWhyItWorks,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        const SizedBox(height: 6),
                        Text(
                          (currentGrade ?? '').trim().isEmpty
                              ? 'Set your current grade to unlock projected grade tracking.'
                              : 'Current Grade $currentGrade • Projected ${projectedGrade > 0 ? 'Grade $projectedGrade' : 'pending'}${(targetGrade ?? '').trim().isEmpty ? '' : ' • Target Grade $targetGrade'} • ${_gradeStatusNarrative(gradeStatus)}',
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                        if (hasTrajectoryEvidence) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Trajectory ${trendSlopePct >= 0 ? '+' : ''}${trendSlopePct.toStringAsFixed(1)} pts/day • Volatility ${volatilityPct.toStringAsFixed(1)} pts • Best run $bestRunDays days',
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                if (showMotivation) ...[
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Wins and momentum',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 8),
                          ...winLines.take(2).map((line) => Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Text('• $line'),
                              )),
                          if (nextMilestone.isNotEmpty)
                            Text(
                              nextMilestone,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Performance views',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: chartOptions.map((view) {
                            final label = switch (view) {
                              'momentum' => 'Momentum',
                              'rhythm' => 'Rhythm',
                              'topics' => 'Topics',
                              'errors' => 'Errors',
                              _ => view,
                            };
                            return ChoiceChip(
                              selected: _chartView == view,
                              label: Text(label),
                              onSelected: (_) {
                                setState(() => _chartView = view);
                              },
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 10),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 180),
                          child: switch (_chartView) {
                            'rhythm' => _SessionCadenceChart(
                                trend: trend,
                                periodLabel: _periodLabel(_period),
                                hasTrendEvidence: hasTrendEvidence,
                              ),
                            'topics' => _TopicStrengthChart(
                                topics: topics,
                              ),
                            'errors' => _ExecutionQualityView(
                                avgSecondsPerQuestion: avgSecondsPerQuestion,
                                speedAccuracySignal: speedAccuracySignal,
                                errorProfile: errorProfile,
                                speedSignalText: _speedSignalText,
                              ),
                            _ => _MomentumTrendChart(
                                trend: trend,
                                hasTrendEvidence: hasTrendEvidence,
                              ),
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _ReportMetric extends StatelessWidget {
  final String label;
  final String value;
  final String subtitle;
  final Color? subtitleColor;

  const _ReportMetric({
    required this.label,
    required this.value,
    required this.subtitle,
    this.subtitleColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.22),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: subtitleColor ??
                      Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}

class _ReportEmptyStateCard extends StatelessWidget {
  final String subject;

  const _ReportEmptyStateCard({required this.subject});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.insights_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Build your first report signal',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'You need a few completed $subject sessions to unlock progression, execution, and motivation insights.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Recommended: 3 sessions this week, then this report becomes fully personalized.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportActionRow extends StatelessWidget {
  final String title;
  final String detail;
  final String cta;
  final VoidCallback onPressed;

  const _ReportActionRow({
    required this.title,
    required this.detail,
    required this.cta,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.56),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context)
                      .textTheme
                      .labelLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  detail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.tonal(
            onPressed: onPressed,
            child: Text(cta),
          ),
        ],
      ),
    );
  }
}

class _SignalChip extends StatelessWidget {
  final String label;
  final IconData icon;

  const _SignalChip({
    required this.label,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: theme.colorScheme.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.labelSmall,
          ),
        ],
      ),
    );
  }
}

class _ExecutionQualityView extends StatelessWidget {
  final double avgSecondsPerQuestion;
  final String speedAccuracySignal;
  final List<Map<String, dynamic>> errorProfile;
  final String Function(String signal) speedSignalText;

  const _ExecutionQualityView({
    required this.avgSecondsPerQuestion,
    required this.speedAccuracySignal,
    required this.errorProfile,
    required this.speedSignalText,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      key: const ValueKey('execution-quality-view'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Avg pace: ${avgSecondsPerQuestion.toStringAsFixed(0)} sec/question • ${speedSignalText(speedAccuracySignal)}',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 10),
        _ErrorPatternPieChart(errorProfile: errorProfile),
      ],
    );
  }
}

class _MomentumTrendChart extends StatelessWidget {
  final List<Map<String, dynamic>> trend;
  final bool hasTrendEvidence;

  const _MomentumTrendChart({
    required this.trend,
    required this.hasTrendEvidence,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sorted = [...trend]..sort(
        (a, b) => convexInt(a['dayStart']).compareTo(convexInt(b['dayStart'])));

    if (sorted.isEmpty) {
      return const Text('No momentum data available yet.');
    }

    final active = sorted
        .where((point) => convexInt(point['attempts']) > 0)
        .toList(growable: false);

    if (active.isEmpty) {
      return const Text('No completed sessions in this window yet.');
    }

    if (!hasTrendEvidence || active.length < 2) {
      final latest = active.last;
      final latestMarks =
          (((latest['avgMarksPct'] as num?)?.toDouble() ?? 0) * 100)
              .clamp(0.0, 100.0);
      final latestAttempts = convexInt(latest['attempts']);
      final latestDate =
          DateTime.fromMillisecondsSinceEpoch(convexInt(latest['dayStart']));
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color:
              theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
          border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.2),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${latestMarks.toStringAsFixed(0)}% latest marks',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              '${latestDate.month}/${latestDate.day} • $latestAttempts session${latestAttempts == 1 ? '' : 's'}',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 6),
            Text(
              'Complete one more session to unlock a meaningful trend line.',
              style: theme.textTheme.labelSmall,
            ),
          ],
        ),
      );
    }

    final attempts =
        active.map((point) => convexInt(point['attempts'])).toList();
    final marks = active
        .map((point) =>
            (((point['avgMarksPct'] as num?)?.toDouble() ?? 0) * 100)
                .clamp(0.0, 100.0))
        .toList();

    final spots =
        List.generate(marks.length, (i) => FlSpot(i.toDouble(), marks[i]));
    final xLabelStep = math.max(1, (active.length / 4).ceil());

    final lineColor = theme.colorScheme.primary;
    return SizedBox(
      height: 185,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: math.max(0, spots.length - 1).toDouble(),
          minY: 0,
          maxY: 100,
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: false,
              barWidth: 3,
              color: lineColor,
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    lineColor.withValues(alpha: 0.24),
                    lineColor.withValues(alpha: 0.04),
                  ],
                ),
              ),
              dotData: FlDotData(
                show: true,
                checkToShowDot: (_, __) => true,
              ),
            ),
          ],
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 25,
            getDrawingHorizontalLine: (_) => FlLine(
              color: theme.colorScheme.outline.withValues(alpha: 0.14),
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(
            show: true,
            border: Border(
              left: BorderSide(
                color: theme.colorScheme.outline.withValues(alpha: 0.3),
              ),
              bottom: BorderSide(
                color: theme.colorScheme.outline.withValues(alpha: 0.3),
              ),
              top: BorderSide.none,
              right: BorderSide.none,
            ),
          ),
          titlesData: FlTitlesData(
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 34,
                interval: 25,
                getTitlesWidget: (value, meta) => SideTitleWidget(
                  meta: meta,
                  child: Text(
                    '${value.toInt()}%',
                    style: theme.textTheme.labelSmall?.copyWith(fontSize: 10),
                  ),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                interval: active.length > 8 ? 2 : 1,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= active.length) {
                    return const SizedBox.shrink();
                  }
                  if (index % xLabelStep != 0 && index != active.length - 1) {
                    return const SizedBox.shrink();
                  }
                  final dayStart = convexInt(active[index]['dayStart']);
                  final date = DateTime.fromMillisecondsSinceEpoch(dayStart);
                  return SideTitleWidget(
                    meta: meta,
                    child: Text(
                      '${date.month}/${date.day}',
                      style: theme.textTheme.labelSmall?.copyWith(fontSize: 10),
                    ),
                  );
                },
              ),
            ),
          ),
          lineTouchData: LineTouchData(
            enabled: true,
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => theme.colorScheme.surface,
              getTooltipItems: (spots) {
                return spots.map((spot) {
                  final index = spot.x.toInt();
                  final dayStart = convexInt(active[index]['dayStart']);
                  final date = DateTime.fromMillisecondsSinceEpoch(dayStart);
                  final attemptCount = attempts[index];
                  return LineTooltipItem(
                    '${date.month}/${date.day}\n${spot.y.toStringAsFixed(0)}% marks\n$attemptCount session${attemptCount == 1 ? '' : 's'}',
                    TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  );
                }).toList();
              },
            ),
          ),
        ),
        duration: const Duration(milliseconds: 220),
      ),
    );
  }
}

class _SessionCadenceChart extends StatelessWidget {
  final List<Map<String, dynamic>> trend;
  final String periodLabel;
  final bool hasTrendEvidence;

  const _SessionCadenceChart({
    required this.trend,
    required this.periodLabel,
    required this.hasTrendEvidence,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sorted = [...trend]..sort(
        (a, b) => convexInt(a['dayStart']).compareTo(convexInt(b['dayStart'])));

    if (sorted.isEmpty) {
      return const Text('No cadence data available yet.');
    }

    final active = sorted
        .where((point) => convexInt(point['attempts']) > 0)
        .toList(growable: false);
    if (active.isEmpty) {
      return Text(
        'No activity recorded in this ${periodLabel.toLowerCase()} window yet.',
        style: theme.textTheme.bodySmall,
      );
    }

    if (!hasTrendEvidence || active.length < 2) {
      final latest = active.last;
      final latestDate =
          DateTime.fromMillisecondsSinceEpoch(convexInt(latest['dayStart']));
      final latestAttempts = convexInt(latest['attempts']);
      return Text(
        'Most recent activity: ${latestDate.month}/${latestDate.day} • $latestAttempts session${latestAttempts == 1 ? '' : 's'}. Complete one more session to map your rhythm.',
        style: theme.textTheme.bodySmall,
      );
    }

    final attempts =
        active.map((point) => convexInt(point['attempts'])).toList();
    final maxAttempts = math.max(1, attempts.fold<int>(0, math.max));
    final xLabelStep = math.max(1, (active.length / 4).ceil());

    final groups = List.generate(active.length, (i) {
      final count = attempts[i].toDouble();
      return BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: count,
            width: 13,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
            color: theme.colorScheme.secondary,
          ),
        ],
      );
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 150,
          child: BarChart(
            BarChartData(
              minY: 0,
              maxY: maxAttempts.toDouble() + 1,
              barGroups: groups,
              alignment: BarChartAlignment.spaceAround,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: 1,
                getDrawingHorizontalLine: (_) => FlLine(
                  color: theme.colorScheme.outline.withValues(alpha: 0.14),
                ),
              ),
              borderData: FlBorderData(
                show: true,
                border: Border(
                  left: BorderSide(
                    color: theme.colorScheme.outline.withValues(alpha: 0.3),
                  ),
                  bottom: BorderSide(
                    color: theme.colorScheme.outline.withValues(alpha: 0.3),
                  ),
                  top: BorderSide.none,
                  right: BorderSide.none,
                ),
              ),
              titlesData: FlTitlesData(
                topTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 22,
                    interval: 1,
                    getTitlesWidget: (value, meta) => SideTitleWidget(
                      meta: meta,
                      child: Text(
                        value.toInt().toString(),
                        style:
                            theme.textTheme.labelSmall?.copyWith(fontSize: 10),
                      ),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 26,
                    interval: active.length > 8 ? 2 : 1,
                    getTitlesWidget: (value, meta) {
                      final index = value.toInt();
                      if (index < 0 || index >= active.length) {
                        return const SizedBox.shrink();
                      }
                      if (index % xLabelStep != 0 &&
                          index != active.length - 1) {
                        return const SizedBox.shrink();
                      }
                      final dayStart = convexInt(active[index]['dayStart']);
                      final date =
                          DateTime.fromMillisecondsSinceEpoch(dayStart);
                      return SideTitleWidget(
                        meta: meta,
                        child: Text(
                          '${date.month}/${date.day}',
                          style: theme.textTheme.labelSmall
                              ?.copyWith(fontSize: 10),
                        ),
                      );
                    },
                  ),
                ),
              ),
              barTouchData: BarTouchData(
                enabled: true,
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (_) => theme.colorScheme.surface,
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final dayStart = convexInt(active[group.x]['dayStart']);
                    final date = DateTime.fromMillisecondsSinceEpoch(dayStart);
                    return BarTooltipItem(
                      '${date.month}/${date.day}\n${rod.toY.toStringAsFixed(0)} sessions',
                      TextStyle(
                        color: theme.colorScheme.onSurface,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    );
                  },
                ),
              ),
            ),
            duration: const Duration(milliseconds: 220),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'This $periodLabel chart tracks your session rhythm on active days.',
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _TopicStrengthChart extends StatelessWidget {
  final List<Map<String, dynamic>> topics;

  const _TopicStrengthChart({required this.topics});

  @override
  Widget build(BuildContext context) {
    if (topics.isEmpty) {
      return const Text('No topic strength chart available yet.');
    }

    final theme = Theme.of(context);
    final selected = topics
        .map((topic) => {
              'topic': topic['topic']?.toString() ?? 'General',
              'attempts': convexInt(topic['attempts']),
              'marks': ((topic['avgMarksPct'] as num?)?.toDouble() ?? 0)
                  .clamp(0.0, 1.0),
            })
        .toList()
      ..sort(
          (a, b) => ((a['marks'] as double).compareTo((b['marks'] as double))));

    return Column(
      children: selected.take(6).map((row) {
        final name = row['topic'] as String;
        final attempts = row['attempts'] as int;
        final marks = row['marks'] as double;
        final barColor = Color.lerp(
              theme.colorScheme.tertiary,
              theme.colorScheme.primary,
              marks,
            ) ??
            theme.colorScheme.primary;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      name,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${(marks * 100).toStringAsFixed(0)}% • $attempts sessions',
                    style: theme.textTheme.labelSmall,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  minHeight: 9,
                  value: marks,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.6),
                  valueColor: AlwaysStoppedAnimation<Color>(barColor),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _ErrorPatternPieChart extends StatelessWidget {
  final List<Map<String, dynamic>> errorProfile;

  const _ErrorPatternPieChart({required this.errorProfile});

  @override
  Widget build(BuildContext context) {
    if (errorProfile.isEmpty) {
      return const Text('No mark-loss pattern data yet.');
    }

    final theme = Theme.of(context);
    const palette = [
      Color(0xFF1E88E5),
      Color(0xFF00ACC1),
      Color(0xFFF9A825),
      Color(0xFF7E57C2),
    ];
    final rows = errorProfile.take(4).toList();
    final totalShare = rows.fold<double>(
      0,
      (sum, row) => sum + ((row['share'] as num?)?.toDouble() ?? 0),
    );

    if (totalShare <= 0.0001) {
      return const Text('No significant error concentration detected.');
    }

    final sections = List.generate(rows.length, (i) {
      final share =
          ((rows[i]['share'] as num?)?.toDouble() ?? 0).clamp(0.0, 1.0);
      return PieChartSectionData(
        value: share,
        color: palette[i % palette.length],
        radius: 58,
        title: '${(share * 100).toStringAsFixed(0)}%',
        titleStyle: theme.textTheme.labelSmall?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      );
    });

    return Column(
      children: [
        SizedBox(
          height: 170,
          child: PieChart(
            PieChartData(
              centerSpaceRadius: 26,
              sectionsSpace: 2,
              sections: sections,
            ),
            duration: const Duration(milliseconds: 220),
          ),
        ),
        const SizedBox(height: 6),
        ...rows.asMap().entries.map((entry) {
          final i = entry.key;
          final row = entry.value;
          final label = row['label']?.toString() ?? 'Pattern';
          final share = ((row['share'] as num?)?.toDouble() ?? 0) * 100;
          final delta = ((row['deltaShare'] as num?)?.toDouble() ?? 0) * 100;
          final trendText = delta <= -0.5
              ? 'improving'
              : (delta >= 0.5 ? 'rising' : 'steady');
          return Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: palette[i % palette.length],
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$label • ${share.toStringAsFixed(0)}% • $trendText',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}
