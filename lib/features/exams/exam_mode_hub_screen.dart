import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:neurobits/core/providers.dart';
import 'package:neurobits/services/convex_client_service.dart';

int? _parseYearGroup(dynamic value) {
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value.trim());
  return null;
}

DateTime? _estimatedGcseDateForYearGroup(int? yearGroup) {
  if (yearGroup == null || yearGroup < 7 || yearGroup > 13) return null;
  final now = DateTime.now();
  final yearsUntilExam = (11 - yearGroup).clamp(0, 4);
  final academicOffset = now.month >= 8 ? 1 : 0;
  final examYear = now.year + yearsUntilExam + academicOffset;
  return DateTime(examYear, 6, 5);
}

int? _daysUntilDate(DateTime? date) {
  if (date == null) return null;
  final now = DateTime.now();
  final diff = date.millisecondsSinceEpoch - now.millisecondsSinceEpoch;
  return (diff / 86400000).ceil();
}

int? _estimatedNearestGcseDaysFromTargets(List<Map<String, dynamic>> targets) {
  int? nearest;
  for (final target in targets) {
    final year = _parseYearGroup(target['year']);
    final estimatedDate = _estimatedGcseDateForYearGroup(year);
    final days = _daysUntilDate(estimatedDate);
    if (days == null) continue;
    nearest = nearest == null ? days : (days < nearest ? days : nearest);
  }
  return nearest;
}

class ExamModeHubScreen extends ConsumerStatefulWidget {
  const ExamModeHubScreen({super.key});

  @override
  ConsumerState<ExamModeHubScreen> createState() => _ExamModeHubScreenState();
}

class _ExamModeHubScreenState extends ConsumerState<ExamModeHubScreen> {
  @override
  Widget build(BuildContext context) {
    final homeAsync = ref.watch(gcseExamHomeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Exam Mode'),
        actions: [
          IconButton(
            onPressed: () => context.push('/exam-dashboard/planning'),
            icon: const Icon(Icons.calendar_month_outlined),
            tooltip: 'Dates & timetable',
          ),
          IconButton(
            onPressed: () => context.push('/exam-mode/setup'),
            icon: const Icon(Icons.tune),
            tooltip: 'Manage setup',
          ),
        ],
      ),
      body: homeAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Failed to load GCSE dashboard: $error'),
          ),
        ),
        data: (payload) {
          final gcseTargets = isConvexList(payload['targets'])
              ? toMapList(payload['targets'])
              : <Map<String, dynamic>>[];
          final reviseToday = isConvexList(payload['reviseToday'])
              ? toMapList(payload['reviseToday'])
              : <Map<String, dynamic>>[];
          final todayMission = payload['todayMission'] is Map
              ? toMap(payload['todayMission'])
              : <String, dynamic>{};
          final subjectProgress = isConvexList(payload['subjectProgress'])
              ? toMapList(payload['subjectProgress'])
              : <Map<String, dynamic>>[];
          final revisionIntelligence = payload['revisionIntelligence'] is Map
              ? toMap(payload['revisionIntelligence'])
              : <String, dynamic>{};

          final progressByTargetId = <String, Map<String, dynamic>>{};
          for (final item in subjectProgress) {
            final targetId = item['targetId']?.toString();
            if (targetId == null || targetId.trim().isEmpty) continue;
            progressByTargetId[targetId] = item;
          }

          if (gcseTargets.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.school_outlined, size: 46),
                    const SizedBox(height: 10),
                    Text(
                      'No GCSE setup yet',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Create your GCSE setup (subjects, boards, tiers, and year) to unlock revision planning.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 14),
                    FilledButton.icon(
                      onPressed: () => context.push('/exam-mode/setup'),
                      icon: const Icon(Icons.auto_fix_high),
                      label: const Text('Start GCSE Setup'),
                    ),
                  ],
                ),
              ),
            );
          }

          final scoped = gcseTargets.toList()
            ..sort((a, b) {
              final sa = a['subject']?.toString() ?? '';
              final sb = b['subject']?.toString() ?? '';
              return sa.compareTo(sb);
            });

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _RevisionIntelligenceCard(
                intelligence: revisionIntelligence,
                targets: gcseTargets,
                onManageTimetable: () =>
                    context.push('/exam-dashboard/planning'),
              ),
              const SizedBox(height: 12),
              _TodayMissionCard(
                mission: todayMission,
                fallbackItems: reviseToday,
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Your GCSE subjects',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => context.push('/exam-mode/setup'),
                    icon: const Icon(Icons.tune, size: 16),
                    label: const Text('Setup'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...scoped.map(
                (target) => _ExamSubjectCompactCard(
                  target: target,
                  progress: progressByTargetId[target['_id']?.toString() ?? ''],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _RevisionIntelligenceCard extends StatelessWidget {
  final Map<String, dynamic> intelligence;
  final List<Map<String, dynamic>> targets;
  final VoidCallback onManageTimetable;

  const _RevisionIntelligenceCard({
    required this.intelligence,
    required this.targets,
    required this.onManageTimetable,
  });

  @override
  Widget build(BuildContext context) {
    final subjectCount = convexInt(intelligence['subjectCount']);
    final gcsesInDays = intelligence['gcsesInDays'] as int?;
    final estimatedGcseInDays = _estimatedNearestGcseDaysFromTargets(targets);
    final effectiveGcseInDays = gcsesInDays ?? estimatedGcseInDays;
    final showGcseHorizon =
        effectiveGcseInDays != null && effectiveGcseInDays <= 180;

    String formatHorizon(int? days, {bool estimated = false}) {
      if (days == null) return estimated ? 'May/Jun window' : 'Not set';
      if (days < 0) return 'Past';
      if (days <= 21) return '$days days';
      if (days <= 120) {
        final weeks = (days / 7).round();
        return '$weeks weeks${estimated ? ' est' : ''}';
      }
      final months = (days / 30.4).round();
      return '$months months${estimated ? ' est' : ''}';
    }

    final gcseWindowText = formatHorizon(
      effectiveGcseInDays,
      estimated: gcsesInDays == null,
    );
    final timelineLine = showGcseHorizon
        ? (gcsesInDays == null
            ? 'Using estimated GCSE timing from year group.'
            : 'Exact GCSE date is set and used for pacing.')
        : 'Long runway. Focus on consistency and weak-topic repair.';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary.withValues(alpha: 0.16),
            Theme.of(context).colorScheme.secondary.withValues(alpha: 0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.26),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Plan settings',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            '$subjectCount subjects active',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (showGcseHorizon) ...[
            const SizedBox(height: 10),
            _SmallMetric(
              label: 'GCSE window',
              value: gcseWindowText,
            ),
          ],
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color:
                  Theme.of(context).colorScheme.surface.withValues(alpha: 0.48),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your mission is tuned automatically from recent performance and study behavior.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 2),
                Text(
                  timelineLine,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onManageTimetable,
              icon: const Icon(Icons.tune_outlined),
              label: const Text('Adjust plan and dates'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SmallMetric extends StatelessWidget {
  final String label;
  final String value;

  const _SmallMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall,
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: Theme.of(context)
                .textTheme
                .labelLarge
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _TodayMissionCard extends StatelessWidget {
  final Map<String, dynamic> mission;
  final List<Map<String, dynamic>> fallbackItems;

  const _TodayMissionCard({
    required this.mission,
    required this.fallbackItems,
  });

  @override
  Widget build(BuildContext context) {
    final missionSessions = mission['sessions'] is List
        ? toMapList(mission['sessions'])
        : <Map<String, dynamic>>[];
    final sessions = missionSessions.isNotEmpty
        ? missionSessions
        : fallbackItems.take(3).toList();
    final plannedSessions = convexInt(mission['plannedSessions']);
    final primaryCompletedToday = mission['primaryCompletedToday'] == true;
    final headline = mission['headline']?.toString().trim().isNotEmpty == true
        ? mission['headline'].toString().trim()
        : 'Priority tasks based on weak areas and pacing.';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary.withValues(alpha: 0.14),
            Theme.of(context).colorScheme.tertiary.withValues(alpha: 0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.22),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Today\'s Mission',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              if (plannedSessions > 0)
                Chip(
                  label: Text(
                      '$plannedSessions task${plannedSessions == 1 ? '' : 's'}'),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            headline,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (sessions.length > 1) ...[
            const SizedBox(height: 2),
            Text(
              primaryCompletedToday
                  ? 'Backup mission is ready if you want to continue.'
                  : 'Backup mission unlocks after the first task.',
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
          const SizedBox(height: 10),
          if (sessions.isEmpty)
            const Text(
              'No mission tasks yet. Complete one session to unlock a focused plan.',
            )
          else
            ...sessions.take(1).map((item) => _PlanItemRow(item: item)),
        ],
      ),
    );
  }
}

class _PlanItemRow extends StatelessWidget {
  final Map<String, dynamic> item;

  const _PlanItemRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final subject = item['subject']?.toString() ?? 'Subject';
    final topic = item['topic']?.toString() ?? 'Priority topic';
    final actionLabel =
        item['actionLabel']?.toString().trim().isNotEmpty == true
            ? item['actionLabel'].toString().trim()
            : topic;
    final estimatedMinutes = convexInt(item['estimatedMinutes']);
    final sessionType = item['sessionType']?.toString().trim() ?? '';
    final effortLabel =
        item['effortLabel']?.toString().trim().isNotEmpty == true
            ? item['effortLabel'].toString().trim()
            : (estimatedMinutes > 0 ? '~$estimatedMinutes min' : '~20 min');
    final whyNow = item['whyNow']?.toString().trim().isNotEmpty == true
        ? item['whyNow'].toString().trim()
        : null;
    final expectedGain =
        item['expectedGain']?.toString().trim().isNotEmpty == true
            ? item['expectedGain'].toString().trim()
            : null;
    final learningMethods = item['learningMethods'] is List
        ? (item['learningMethods'] as List)
            .map((entry) => entry.toString().trim())
            .where((entry) => entry.isNotEmpty)
            .toList(growable: false)
        : const <String>[];
    final reasonLabels = item['reasonLabels'] is List
        ? (item['reasonLabels'] as List)
            .map((entry) => entry.toString().trim())
            .where((entry) => entry.isNotEmpty)
            .toList(growable: false)
        : const <String>[];
    final targetId = item['targetId']?.toString() ?? '';
    final quizPreset =
        item['quizPreset'] is Map ? toMap(item['quizPreset']) : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.58),
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
                    actionLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context)
                        .textTheme
                        .labelLarge
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$subject • $effortLabel',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Why now: ${whyNow ?? (reasonLabels.isNotEmpty ? reasonLabels.first : 'closes your weakest gap first')}',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  if (expectedGain != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Expected gain: $expectedGain',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                  if (learningMethods.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: learningMethods.take(2).map((label) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(999),
                            color: Theme.of(context)
                                .colorScheme
                                .surface
                                .withValues(alpha: 0.48),
                            border: Border.all(
                              color: Theme.of(context)
                                  .colorScheme
                                  .outline
                                  .withValues(alpha: 0.25),
                            ),
                          ),
                          child: Text(
                            label,
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: targetId.isEmpty
                  ? null
                  : () {
                      final encoded = Uri.encodeComponent('$subject $topic');
                      context.push('/topic/$encoded', extra: {
                        'examTargetId': targetId,
                        if (quizPreset != null) 'quizPreset': quizPreset,
                      });
                    },
              child:
                  Text(sessionType == 'baseline' ? 'Start baseline' : 'Start'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExamSubjectCompactCard extends StatelessWidget {
  final Map<String, dynamic> target;
  final Map<String, dynamic>? progress;

  const _ExamSubjectCompactCard({required this.target, required this.progress});

  @override
  Widget build(BuildContext context) {
    final targetId = target['_id']?.toString();
    if (targetId == null || targetId.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    final subject = target['subject']?.toString() ?? 'Subject';
    final board = target['board']?.toString() ?? '';
    final level = target['level']?.toString() ?? '';
    final year = target['year']?.toString() ?? '';
    final country = target['countryName']?.toString() ?? '';
    final currentGrade = target['currentGrade']?.toString() ?? '';
    final targetGrade = target['targetGrade']?.toString() ?? '';
    final mockInDays = progress?['mockInDays'] as int?;
    final examInDays = progress?['examInDays'] as int?;
    final estimatedExamInDays = _daysUntilDate(
        _estimatedGcseDateForYearGroup(_parseYearGroup(target['year'])));
    final avgMarksPct = (progress?['avgMarksPct'] as num?)?.toDouble() ?? 0.0;
    final totalAttempts = convexInt(progress?['totalAttempts']);
    final gradeStatus = progress?['gradeStatus']?.toString() ?? 'no_target';
    final topReasonLabels = progress?['topReasonLabels'] is List
        ? (progress!['topReasonLabels'] as List)
            .map((entry) => entry.toString().trim())
            .where((entry) => entry.isNotEmpty)
            .toList(growable: false)
        : const <String>[];

    String horizonText(int? days, {bool estimated = false}) {
      if (days == null) return '';
      if (days < 0) return 'past';
      if (days <= 21) return '$days days';
      if (days <= 120) return '${(days / 7).round()} weeks';
      final months = (days / 30.4).round();
      return '$months months${estimated ? ' est' : ''}';
    }

    String nextActionText() {
      if (totalAttempts == 0) return 'Next: run baseline diagnostic';
      if (topReasonLabels.isNotEmpty) {
        return 'Next: fix ${topReasonLabels.first.toLowerCase()}';
      }
      switch (gradeStatus) {
        case 'on_track':
          return 'Next: maintain with timed mixed set';
        case 'close':
          return 'Next: weak-focus repair set';
        case 'at_risk':
          return 'Next: targeted weak-topic session';
        default:
          return 'Next: complete focused session';
      }
    }

    final gradeText = (currentGrade.trim().isNotEmpty ||
            targetGrade.trim().isNotEmpty)
        ? 'Grade ${currentGrade.isEmpty ? '?' : currentGrade}→${targetGrade.isEmpty ? '?' : targetGrade}'
        : '';
    final mockText = (mockInDays != null && mockInDays <= 90)
        ? 'Mock ${horizonText(mockInDays)}'
        : '';
    final effectiveExamInDays = examInDays ?? estimatedExamInDays;
    final examText = (effectiveExamInDays != null && effectiveExamInDays <= 180)
        ? 'GCSE ${horizonText(effectiveExamInDays, estimated: examInDays == null)}'
        : '';
    final scheduleText = [mockText, examText]
        .where((value) => value.trim().isNotEmpty)
        .join(' • ');

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    subject,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                if (scheduleText.isNotEmpty)
                  Text(
                    scheduleText,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              [country, board, level, year.isNotEmpty ? 'Y$year' : '']
                  .where((part) => part.trim().isNotEmpty)
                  .join(' • '),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Text(
              totalAttempts > 0
                  ? '${(avgMarksPct * 100).toStringAsFixed(0)}% marks • $totalAttempts sessions'
                  : 'No sessions yet',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (gradeText.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                gradeText,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 4),
            Text(
              nextActionText(),
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            if (topReasonLabels.isNotEmpty) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: topReasonLabels.take(2).map((label) {
                  return Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      color: Theme.of(context)
                          .colorScheme
                          .surface
                          .withValues(alpha: 0.62),
                      border: Border.all(
                        color: Theme.of(context)
                            .colorScheme
                            .outline
                            .withValues(alpha: 0.22),
                      ),
                    ),
                    child: Text(
                      label,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  );
                }).toList(),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () =>
                        context.push('/exam-dashboard/subject/$targetId'),
                    icon: const Icon(Icons.space_dashboard_outlined),
                    label: const Text('Open subject'),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () =>
                      context.push('/exam-dashboard/subject/$targetId/report'),
                  child: const Text('Report'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
