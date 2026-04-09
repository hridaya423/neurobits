import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:neurobits/core/providers.dart';
import 'package:neurobits/features/exams/exam_curriculum.dart';
import 'package:neurobits/services/convex_client_service.dart';

const Map<int, double> _gcseGradeThresholds = {
  9: 0.85,
  8: 0.76,
  7: 0.67,
  6: 0.58,
  5: 0.49,
  4: 0.40,
  3: 0.32,
  2: 0.24,
  1: 0.16,
};

int _estimateGcseGrade(double pct) {
  final value = pct.clamp(0.0, 1.0);
  for (int grade = 9; grade >= 1; grade--) {
    if (value >= (_gcseGradeThresholds[grade] ?? 1.0)) return grade;
  }
  return 1;
}

double _thresholdForGrade(int grade) => _gcseGradeThresholds[grade] ?? 1.0;

int? _daysUntilTimestamp(int? timestamp) {
  if (timestamp == null || timestamp <= 0) return null;
  final now = DateTime.now().millisecondsSinceEpoch;
  final diff = timestamp - now;
  return (diff / 86400000).ceil();
}

bool _isTieredMathsSubject(String subject) {
  final normalized = subject.trim().toLowerCase();
  return normalized.contains('math');
}

String _tierAwareLaunchTopic({
  required String subject,
  required String level,
  required String topic,
}) {
  final trimmed = topic.trim();
  if (trimmed.isEmpty) return trimmed;
  if (!_isTieredMathsSubject(subject)) return trimmed;

  final tier = level.trim().toLowerCase();
  if (tier != 'foundation' && tier != 'higher') return trimmed;
  final marker = '$tier tier';
  if (trimmed.toLowerCase().contains(marker)) return trimmed;

  final label = '${tier[0].toUpperCase()}${tier.substring(1)} tier';
  return '$trimmed ($label)';
}

Map<String, dynamic>? _tierAwareQuizPreset({
  required String subject,
  required String level,
}) {
  if (!_isTieredMathsSubject(subject)) return null;
  final tier = level.trim().toLowerCase();
  if (tier == 'higher') {
    return {
      'difficulty': 'Hard',
      'includeHints': false,
    };
  }
  if (tier == 'foundation') {
    return {
      'difficulty': 'Easy',
      'includeHints': true,
    };
  }
  return null;
}

Set<String> _seenTopicsFromReport(Map<String, dynamic> report) {
  final topicRows = isConvexList(report['topicBreakdown'])
      ? toMapList(report['topicBreakdown'])
      : <Map<String, dynamic>>[];
  return topicRows
      .map((row) => (row['topic']?.toString() ?? '').toLowerCase())
      .where((topic) => topic.isNotEmpty)
      .toSet();
}

Map<String, dynamic> _buildPaperPreset(
  CurriculumPaper paper, {
  required String subject,
  required String level,
}) {
  final questionCount = (paper.marks / 4).round().clamp(8, 32);
  final totalPaperSeconds = paper.durationMinutes > 0
      ? paper.durationMinutes * 60
      : questionCount * 75;
  final timePerQuestion =
      (totalPaperSeconds / questionCount).round().clamp(20, 180);
  final tierPreset = _tierAwareQuizPreset(subject: subject, level: level);
  final paperDifficulty = tierPreset?['difficulty']?.toString() ??
      (paper.tiers.any((tier) => tier.toLowerCase() == 'higher')
          ? 'Hard'
          : 'Medium');
  return {
    'questionCount': questionCount,
    'timePerQuestion': timePerQuestion,
    'totalTimeLimit': totalPaperSeconds,
    'timedMode': true,
    'difficulty': paperDifficulty,
    'includeCodeChallenges': false,
    'includeMcqs': true,
    'includeInput': true,
    'includeFillBlank': false,
    'includeHints': tierPreset?['includeHints'] ?? false,
    'examModeProfile': 'exam_standard',
    'autoStart': true,
  };
}

SubjectCurriculum? _curriculumFromProfile(
  String subject,
  Map<String, dynamic>? profile,
  SubjectCurriculum? fallback,
) {
  if (profile == null) return fallback;

  final sectionRows = isConvexList(profile['sections'])
      ? toMapList(profile['sections'])
      : const <Map<String, dynamic>>[];
  final paperRows = isConvexList(profile['papers'])
      ? toMapList(profile['papers'])
      : const <Map<String, dynamic>>[];

  if (sectionRows.isEmpty && paperRows.isEmpty) {
    return fallback;
  }

  final sections = sectionRows
      .map((row) {
        final id = row['id']?.toString().trim() ?? '';
        final title = row['title']?.toString().trim() ?? '';
        final topicGroupsRaw = row['topics'];
        final topicGroups = topicGroupsRaw is List
            ? topicGroupsRaw
                .map((item) {
                  if (item is! Map) return null;
                  final groupTitle = item['title']?.toString().trim() ?? '';
                  if (groupTitle.isEmpty) return null;
                  final groupSubsRaw = item['subtopics'];
                  final groupSubtopics = groupSubsRaw is List
                      ? groupSubsRaw
                          .map((sub) {
                            if (sub is Map) {
                              return sub['title']?.toString().trim() ?? '';
                            }
                            return sub.toString().trim();
                          })
                          .where((sub) => sub.isNotEmpty)
                          .toList()
                      : <String>[];
                  return CurriculumTopicGroup(
                    title: groupTitle,
                    subtopics: groupSubtopics,
                  );
                })
                .whereType<CurriculumTopicGroup>()
                .toList()
            : <CurriculumTopicGroup>[];

        final topicsRaw = row['subtopics'];
        final legacySubtopics = topicsRaw is List
            ? topicsRaw
                .map((item) => item.toString().trim())
                .where((item) => item.isNotEmpty)
                .toList()
            : <String>[];

        final topics = topicGroups.isNotEmpty
            ? [
                for (final group in topicGroups) group.title,
                for (final group in topicGroups) ...group.subtopics,
              ]
            : legacySubtopics;
        if (id.isEmpty || title.isEmpty) return null;
        return CurriculumSection(
          id: id,
          title: title,
          topics: topics,
          topicGroups: topicGroups,
        );
      })
      .whereType<CurriculumSection>()
      .toList();

  final papers = paperRows
      .map((row) {
        final id = row['id']?.toString().trim() ?? '';
        final title = row['title']?.toString().trim() ?? '';
        final sectionIdsRaw = row['sectionIds'];
        final sectionIds = sectionIdsRaw is List
            ? sectionIdsRaw
                .map((item) => item.toString().trim())
                .where((item) => item.isNotEmpty)
                .toList()
            : <String>[];
        if (id.isEmpty || title.isEmpty) return null;
        return CurriculumPaper(
          id: id,
          title: title,
          durationMinutes: convexInt(row['durationMinutes']),
          marks: convexInt(row['marks']),
          sectionIds: sectionIds,
          weightPercent: row['weightPercent'] is num
              ? (row['weightPercent'] as num).toInt()
              : null,
        );
      })
      .whereType<CurriculumPaper>()
      .toList();

  if (sections.isEmpty && papers.isEmpty) {
    return fallback;
  }

  return SubjectCurriculum(
      subject: subject, sections: sections, papers: papers);
}

class ExamDashboardScreen extends ConsumerWidget {
  final String targetId;

  const ExamDashboardScreen({super.key, required this.targetId});

  Future<void> _startRevision(
    BuildContext context,
    WidgetRef ref, {
    required String targetId,
    required String launchTopic,
    Map<String, dynamic>? quizPreset,
  }) async {
    final repo = ref.read(examRepositoryProvider);
    await repo.setActiveTarget(targetId: targetId);
    ref.invalidate(userExamTargetProvider);
    ref.invalidate(userExamTargetsProvider);
    if (!context.mounted) return;
    final encoded = Uri.encodeComponent(launchTopic);
    context.push('/topic/$encoded', extra: {
      'examTargetId': targetId,
      if (quizPreset != null) 'quizPreset': quizPreset,
    });
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardAsync =
        ref.watch(userExamDashboardByTargetProvider(targetId));
    final homeAsync = ref.watch(gcseExamHomeProvider);
    final profileAsync = ref.watch(userExamProfileByTargetProvider(targetId));
    final reportAsync = ref.watch(
      userExamSubjectReportProvider(
        ExamSubjectReportArgs(targetId: targetId, period: 'monthly'),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Subject Dashboard'),
        actions: [
          IconButton(
            onPressed: () => context.push('/exam-dashboard/planning'),
            icon: const Icon(Icons.calendar_month_outlined),
            tooltip: 'Dates & timetable',
          ),
        ],
      ),
      body: dashboardAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Could not load subject dashboard: $error'),
          ),
        ),
        data: (dashboard) {
          final target = dashboard['target'] as Map<String, dynamic>?;
          if (target == null) {
            return const Center(
              child: Text('Exam target not found for this dashboard.'),
            );
          }

          final family = target['examFamily']?.toString() ?? '';
          if (family.toLowerCase() != 'gcse') {
            return _GcseOnlyCard(
                onSetup: () => context.push('/exam-mode/setup'));
          }

          final subject = target['subject']?.toString() ?? 'Subject';
          final board = target['board']?.toString() ?? '';
          final level = target['level']?.toString() ?? '';
          final country = target['countryName']?.toString() ?? '';
          final year = target['year']?.toString() ?? '';

          final profile = profileAsync.valueOrNull;
          final curriculum = _curriculumFromProfile(subject, profile, null);
          final isProfileLoading = profileAsync.isLoading;
          final hasProfileError = profileAsync.hasError;
          final profileSourceCount = convexInt(profile?['sourceCount']);
          final examTechniquesRaw = profile?['examTechniques'];
          final priorityPitfallsRaw = profile?['priorityPitfalls'];
          final weaknessTagsRaw = profile?['weaknessTags'];
          final examTechniques = isConvexList(examTechniquesRaw)
              ? toMapList(examTechniquesRaw)
              : <Map<String, dynamic>>[];
          final priorityPitfalls = isConvexList(priorityPitfallsRaw)
              ? toMapList(priorityPitfallsRaw)
              : <Map<String, dynamic>>[];
          final weaknessTags = weaknessTagsRaw is List
              ? weaknessTagsRaw
                  .map((tag) => tag.toString())
                  .where((tag) => tag.trim().isNotEmpty)
                  .toList()
              : <String>[];

          final curriculumStatusText = profileAsync.when(
            data: (_) => profileSourceCount > 0
                ? 'Board-aligned curriculum map with parent topics and subtopics.'
                : 'Board curriculum map is syncing for this target.',
            loading: () => 'Loading board-specific curriculum.',
            error: (_, __) => 'Board curriculum sync is unavailable right now.',
          );

          final totalAttempts = convexInt(dashboard['totalAttempts']);
          final avgMarksPct =
              (dashboard['avgMarksPct'] as num?)?.toDouble() ?? 0;
          final savedTargetGrade = dashboard['targetGrade']?.toString();
          final projectedGrade = convexInt(dashboard['projectedGrade']);
          final gradeStatus =
              dashboard['gradeStatus']?.toString() ?? 'no_target';
          final mockDateAt = convexInt(target['mockDateAt']);
          final examDateAt = convexInt(target['examDateAt']);
          final mockInDays =
              _daysUntilTimestamp(mockDateAt > 0 ? mockDateAt : null);
          final examInDays =
              _daysUntilTimestamp(examDateAt > 0 ? examDateAt : null);
          final weakTopics = isConvexList(dashboard['weakTopics'])
              ? toMapList(dashboard['weakTopics'])
              : <Map<String, dynamic>>[];

          final initialTopicBase =
              curriculum != null && curriculum.sections.isNotEmpty
                  ? '$subject ${curriculum.sections.first.title}'
                  : '$subject revision';
          final initialTopic = _tierAwareLaunchTopic(
            subject: subject,
            level: level,
            topic: initialTopicBase,
          );

          final topWeakTopic = weakTopics.isNotEmpty
              ? weakTopics.first['topic']?.toString().trim() ?? ''
              : '';

          final homePayload = homeAsync.valueOrNull;
          final homeMissionRows = homePayload?['todayMission'] is Map
              ? toMap(homePayload!['todayMission'])['sessions']
              : null;
          final missionRows = isConvexList(homeMissionRows)
              ? toMapList(homeMissionRows)
              : <Map<String, dynamic>>[];
          final homeReviseRows = isConvexList(homePayload?['reviseToday'])
              ? toMapList(homePayload!['reviseToday'])
              : <Map<String, dynamic>>[];

          List<Map<String, dynamic>> byTarget(List<Map<String, dynamic>> rows) {
            return rows.where((row) {
              final id = row['targetId']?.toString().trim();
              return id != null && id == targetId;
            }).toList();
          }

          final recommendedSessions = <Map<String, dynamic>>[];
          final seenTopics = <String>{};
          for (final row in [
            ...byTarget(missionRows),
            ...byTarget(homeReviseRows)
          ]) {
            final topic = row['topic']?.toString().toLowerCase().trim() ?? '';
            if (topic.isEmpty || !seenTopics.add(topic)) continue;
            recommendedSessions.add(row);
            if (recommendedSessions.length >= 4) break;
          }

          String missionLaunchTopic(Map<String, dynamic> mission) {
            final rawTopic = mission['topic']?.toString().trim() ?? '';
            if (rawTopic.isEmpty) {
              return initialTopic;
            }
            final loweredSubject = subject.toLowerCase();
            return _tierAwareLaunchTopic(
              subject: subject,
              level: level,
              topic: rawTopic.toLowerCase().contains(loweredSubject)
                  ? rawTopic
                  : '$subject $rawTopic',
            );
          }

          final fallbackMission = <String, dynamic>{
            'topic': topWeakTopic.isNotEmpty
                ? topWeakTopic
                : '$subject mixed practice',
            'sessionType': totalAttempts == 0 ? 'baseline' : 'weak_focus',
            'actionLabel': totalAttempts == 0
                ? 'Build your baseline profile'
                : 'Repair weakest performance area',
            'estimatedMinutes': totalAttempts == 0 ? 24 : 22,
            'effortLabel': totalAttempts == 0 ? '~20-28 min' : '~18-25 min',
            'whyNow': totalAttempts == 0
                ? 'Build your starting profile'
                : (topWeakTopic.isNotEmpty
                    ? 'Lowest scoring area right now'
                    : 'Highest expected score gain right now'),
            'expectedGain': totalAttempts == 0
                ? 'Pinpoint weak areas and calibrate your next sessions.'
                : (topWeakTopic.isNotEmpty
                    ? 'Improve marks in $topWeakTopic with targeted retrieval.'
                    : 'Stabilize exam performance with a focused mixed set.'),
            'learningMethods': const [
              'Retrieval practice',
              'Error-focused feedback'
            ],
            'completedToday': false,
            'quizPreset': _tierAwareQuizPreset(subject: subject, level: level),
          };

          final primaryMission = recommendedSessions.isNotEmpty
              ? recommendedSessions.first
              : fallbackMission;
          final backupMission =
              recommendedSessions.length > 1 ? recommendedSessions[1] : null;
          final primaryCompletedToday =
              primaryMission['completedToday'] == true;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _PrimaryMissionCard(
                subject: subject,
                details: [
                  country,
                  board,
                  level,
                  year.isNotEmpty ? 'Y$year' : '',
                ].where((part) => part.trim().isNotEmpty).join(' • '),
                mission: primaryMission,
                backupMission: backupMission,
                primaryCompletedToday: primaryCompletedToday,
                onStartMission: () => _startRevision(
                  context,
                  ref,
                  targetId: targetId,
                  launchTopic: missionLaunchTopic(primaryMission),
                  quizPreset: primaryMission['quizPreset'] is Map
                      ? toMap(primaryMission['quizPreset'])
                      : _tierAwareQuizPreset(subject: subject, level: level),
                ),
                onStartBackup: backupMission == null
                    ? null
                    : () => _startRevision(
                          context,
                          ref,
                          targetId: targetId,
                          launchTopic: missionLaunchTopic(backupMission),
                          quizPreset: backupMission['quizPreset'] is Map
                              ? toMap(backupMission['quizPreset'])
                              : _tierAwareQuizPreset(
                                  subject: subject, level: level),
                        ),
              ),
              const SizedBox(height: 12),
              _SubjectDetailsPanel(
                targetGrade: savedTargetGrade,
                projectedGrade: projectedGrade,
                gradeStatus: gradeStatus,
                weaknessTags: weaknessTags,
                priorityPitfalls: priorityPitfalls,
                examTechniques: examTechniques,
                weakTopics: weakTopics,
                reportAsync: reportAsync,
                subject: subject,
                level: level,
                curriculum: curriculum,
                avgMarksPct: avgMarksPct,
                totalAttempts: totalAttempts,
                mockInDays: mockInDays,
                examInDays: examInDays,
                recommendedSessions: recommendedSessions,
                curriculumStatusText: curriculumStatusText,
                isProfileLoading: isProfileLoading,
                hasProfileError: hasProfileError,
                onPractice: (topic, preset) => _startRevision(
                  context,
                  ref,
                  targetId: targetId,
                  launchTopic: topic,
                  quizPreset: preset,
                ),
                onOpenReport: () =>
                    context.push('/exam-dashboard/subject/$targetId/report'),
                onOpenPlanning: () => context.push('/exam-dashboard/planning'),
                onOpenCurriculum: () => context
                    .push('/exam-dashboard/subject/$targetId/curriculum'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _GcseOnlyCard extends StatelessWidget {
  final VoidCallback onSetup;

  const _GcseOnlyCard({required this.onSetup});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.school_outlined, size: 44),
            const SizedBox(height: 10),
            Text(
              'GCSE dashboards only',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            const Text(
              'Exam Mode is currently focused on GCSE. Reconfigure your setup to continue.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onSetup,
              icon: const Icon(Icons.tune),
              label: const Text('Open GCSE setup'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PrimaryMissionCard extends StatelessWidget {
  final String subject;
  final String details;
  final Map<String, dynamic> mission;
  final Map<String, dynamic>? backupMission;
  final bool primaryCompletedToday;
  final VoidCallback onStartMission;
  final VoidCallback? onStartBackup;

  const _PrimaryMissionCard({
    required this.subject,
    required this.details,
    required this.mission,
    required this.backupMission,
    required this.primaryCompletedToday,
    required this.onStartMission,
    required this.onStartBackup,
  });

  String _sessionLabel(String type) {
    switch (type.trim().toLowerCase()) {
      case 'baseline':
        return 'Build baseline profile';
      case 'weak_focus':
        return 'Repair weakest area';
      case 'mixed_practice':
        return 'Stabilize mixed performance';
      default:
        return 'Run focused mission';
    }
  }

  @override
  Widget build(BuildContext context) {
    final topic = mission['topic']?.toString().trim().isNotEmpty == true
        ? mission['topic'].toString().trim()
        : '$subject focused set';
    final sessionType = mission['sessionType']?.toString() ?? '';
    final headline =
        mission['actionLabel']?.toString().trim().isNotEmpty == true
            ? mission['actionLabel'].toString().trim()
            : _sessionLabel(sessionType);
    final whyNow = mission['whyNow']?.toString().trim().isNotEmpty == true
        ? mission['whyNow'].toString().trim()
        : 'Highest expected score gain right now';
    final expectedGain =
        mission['expectedGain']?.toString().trim().isNotEmpty == true
            ? mission['expectedGain'].toString().trim()
            : 'Improve score reliability on this topic.';
    final effortLabel =
        mission['effortLabel']?.toString().trim().isNotEmpty == true
            ? mission['effortLabel'].toString().trim()
            : '~20-25 min';
    final methods = mission['learningMethods'] is List
        ? (mission['learningMethods'] as List)
            .map((entry) => entry.toString().trim())
            .where((entry) => entry.isNotEmpty)
            .toList(growable: false)
        : const <String>[];
    final backupTitle =
        backupMission?['topic']?.toString().trim().isNotEmpty == true
            ? backupMission!['topic'].toString().trim()
            : null;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.2),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.24),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            subject,
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          if (details.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              details,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            headline,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          Text(
            topic,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 6),
          Text(
            'Why now: $whyNow',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 2),
          Text(
            'Expected gain: $expectedGain',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 2),
          Text(
            'Effort: $effortLabel',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (methods.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: methods
                  .take(2)
                  .map((method) => _SignalPill(label: method, compact: true))
                  .toList(),
            ),
          ],
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: onStartMission,
            icon: const Icon(Icons.play_arrow),
            label: const Text('Start mission'),
          ),
          if (backupTitle != null && onStartBackup != null) ...[
            const SizedBox(height: 8),
            if (primaryCompletedToday)
              OutlinedButton.icon(
                onPressed: onStartBackup,
                icon: const Icon(Icons.skip_next_outlined),
                label: Text('Optional backup: $backupTitle'),
              )
            else
              Text(
                'Complete this mission to unlock your backup option.',
                style: Theme.of(context).textTheme.labelSmall,
              ),
          ],
        ],
      ),
    );
  }
}

class _SubjectDetailsPanel extends StatelessWidget {
  final String? targetGrade;
  final int projectedGrade;
  final String gradeStatus;
  final List<String> weaknessTags;
  final List<Map<String, dynamic>> priorityPitfalls;
  final List<Map<String, dynamic>> examTechniques;
  final List<Map<String, dynamic>> weakTopics;
  final AsyncValue<Map<String, dynamic>> reportAsync;
  final String subject;
  final String level;
  final SubjectCurriculum? curriculum;
  final double avgMarksPct;
  final int totalAttempts;
  final int? mockInDays;
  final int? examInDays;
  final List<Map<String, dynamic>> recommendedSessions;
  final String curriculumStatusText;
  final bool isProfileLoading;
  final bool hasProfileError;
  final void Function(String topic, Map<String, dynamic>? preset) onPractice;
  final VoidCallback onOpenReport;
  final VoidCallback onOpenPlanning;
  final VoidCallback onOpenCurriculum;

  const _SubjectDetailsPanel({
    required this.targetGrade,
    required this.projectedGrade,
    required this.gradeStatus,
    required this.weaknessTags,
    required this.priorityPitfalls,
    required this.examTechniques,
    required this.weakTopics,
    required this.reportAsync,
    required this.subject,
    required this.level,
    required this.curriculum,
    required this.avgMarksPct,
    required this.totalAttempts,
    required this.mockInDays,
    required this.examInDays,
    required this.recommendedSessions,
    required this.curriculumStatusText,
    required this.isProfileLoading,
    required this.hasProfileError,
    required this.onPractice,
    required this.onOpenReport,
    required this.onOpenPlanning,
    required this.onOpenCurriculum,
  });

  @override
  Widget build(BuildContext context) {
    final actionButtonStyle = OutlinedButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      minimumSize: const Size(0, 42),
      visualDensity: const VisualDensity(horizontal: -1, vertical: -1),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                style: actionButtonStyle,
                onPressed: onOpenReport,
                icon: const Icon(Icons.summarize_outlined, size: 18),
                label: const Text(
                  'Report',
                  softWrap: false,
                  overflow: TextOverflow.fade,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                style: actionButtonStyle,
                onPressed: onOpenPlanning,
                icon: const Icon(Icons.calendar_month_outlined, size: 18),
                label: const Text(
                  'Planning',
                  softWrap: false,
                  overflow: TextOverflow.fade,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                style: actionButtonStyle,
                onPressed: onOpenCurriculum,
                icon: const Icon(Icons.account_tree_outlined, size: 18),
                label: const Text(
                  'Curriculum',
                  softWrap: false,
                  overflow: TextOverflow.fade,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _PersonalizedFeedbackCard(
          targetGrade: targetGrade,
          projectedGrade: projectedGrade,
          gradeStatus: gradeStatus,
          weaknessTags: weaknessTags,
          priorityPitfalls: priorityPitfalls,
          examTechniques: examTechniques,
        ),
        const SizedBox(height: 10),
        reportAsync.when(
          loading: () => _DailyPlanCard(
            subject: subject,
            level: level,
            curriculum: curriculum,
            weakTopics: weakTopics,
            seenTopics: const <String>{},
            mockInDays: mockInDays,
            examInDays: examInDays,
            recommendedSessions: recommendedSessions,
            onPractice: onPractice,
            onOpenPlanning: onOpenPlanning,
          ),
          error: (_, __) => _DailyPlanCard(
            subject: subject,
            level: level,
            curriculum: curriculum,
            weakTopics: weakTopics,
            seenTopics: const <String>{},
            mockInDays: mockInDays,
            examInDays: examInDays,
            recommendedSessions: recommendedSessions,
            onPractice: onPractice,
            onOpenPlanning: onOpenPlanning,
          ),
          data: (report) => _DailyPlanCard(
            subject: subject,
            level: level,
            curriculum: curriculum,
            weakTopics: weakTopics,
            seenTopics: _seenTopicsFromReport(report),
            mockInDays: mockInDays,
            examInDays: examInDays,
            recommendedSessions: recommendedSessions,
            onPractice: onPractice,
            onOpenPlanning: onOpenPlanning,
          ),
        ),
        const SizedBox(height: 10),
        reportAsync.when(
          loading: () => _PaperPlanCard(
            subject: subject,
            level: level,
            curriculum: curriculum,
            isCurriculumLoading: isProfileLoading,
            hasCurriculumError: hasProfileError,
            avgMarksPct: avgMarksPct,
            totalAttempts: totalAttempts,
            seenTopics: const <String>{},
            statusText: curriculumStatusText,
            onOpenCurriculum: onOpenCurriculum,
            onPractice: onPractice,
          ),
          error: (_, __) => _PaperPlanCard(
            subject: subject,
            level: level,
            curriculum: curriculum,
            isCurriculumLoading: isProfileLoading,
            hasCurriculumError: hasProfileError,
            avgMarksPct: avgMarksPct,
            totalAttempts: totalAttempts,
            seenTopics: const <String>{},
            statusText: curriculumStatusText,
            onOpenCurriculum: onOpenCurriculum,
            onPractice: onPractice,
          ),
          data: (report) => _PaperPlanCard(
            subject: subject,
            level: level,
            curriculum: curriculum,
            isCurriculumLoading: isProfileLoading,
            hasCurriculumError: hasProfileError,
            avgMarksPct: avgMarksPct,
            totalAttempts: totalAttempts,
            seenTopics: _seenTopicsFromReport(report),
            statusText: curriculumStatusText,
            onOpenCurriculum: onOpenCurriculum,
            onPractice: onPractice,
          ),
        ),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: onOpenReport,
            icon: const Icon(Icons.insights_outlined),
            label: const Text('View full trend and weak-topic analysis'),
          ),
        ),
      ],
    );
  }
}

class _SignalPill extends StatelessWidget {
  final String label;
  final bool compact;

  const _SignalPill({required this.label, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 3 : 5,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.62),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Text(
        label,
        style: compact
            ? Theme.of(context).textTheme.labelSmall
            : Theme.of(context).textTheme.labelMedium,
      ),
    );
  }
}

class _DailyTask {
  final String title;
  final String detail;
  final String cta;
  final String launchTopic;
  final Map<String, dynamic>? quizPreset;

  const _DailyTask({
    required this.title,
    required this.detail,
    required this.cta,
    required this.launchTopic,
    this.quizPreset,
  });
}

class _DailyPlanCard extends StatelessWidget {
  final String subject;
  final String level;
  final SubjectCurriculum? curriculum;
  final List<Map<String, dynamic>> weakTopics;
  final Set<String> seenTopics;
  final int? mockInDays;
  final int? examInDays;
  final List<Map<String, dynamic>> recommendedSessions;
  final void Function(String topic, Map<String, dynamic>? preset) onPractice;
  final VoidCallback onOpenPlanning;

  const _DailyPlanCard({
    required this.subject,
    required this.level,
    required this.curriculum,
    required this.weakTopics,
    required this.seenTopics,
    required this.mockInDays,
    required this.examInDays,
    required this.recommendedSessions,
    required this.onPractice,
    required this.onOpenPlanning,
  });

  bool _sectionCovered(CurriculumSection section) {
    for (final topic in section.topics) {
      final normalized = topic.trim().toLowerCase();
      if (normalized.isEmpty) continue;
      if (seenTopics.any((seen) => seen.contains(normalized))) {
        return true;
      }
    }
    return false;
  }

  List<_DailyTask> _buildTasks() {
    final tasks = <_DailyTask>[];
    final usedTopics = <String>{};
    final tierPreset = _tierAwareQuizPreset(subject: subject, level: level);

    void addTask(_DailyTask task) {
      final key = task.launchTopic.trim().toLowerCase();
      if (key.isEmpty || !usedTopics.add(key)) return;
      tasks.add(task);
    }

    for (final row in recommendedSessions.take(3)) {
      final rawTopic = row['topic']?.toString().trim() ?? '';
      if (rawTopic.isEmpty) continue;
      final launchTopic = _tierAwareLaunchTopic(
        subject: subject,
        level: level,
        topic: rawTopic.toLowerCase().contains(subject.toLowerCase())
            ? rawTopic
            : '$subject $rawTopic',
      );
      final reasonLabels = row['reasonLabels'] is List
          ? (row['reasonLabels'] as List)
              .map((entry) => entry.toString().trim())
              .where((entry) => entry.isNotEmpty)
              .toList()
          : const <String>[];
      final expectedGain =
          row['expectedGain']?.toString().trim().isNotEmpty == true
              ? row['expectedGain'].toString().trim()
              : null;
      final minutes = convexInt(row['estimatedMinutes']);
      final sessionType = row['sessionType']?.toString().trim() ?? '';

      String title;
      switch (sessionType) {
        case 'baseline':
          title = 'Build starting profile';
          break;
        case 'weak_focus':
          title = 'Repair weak topic';
          break;
        case 'mixed_practice':
          title = 'Maintain exam rhythm';
          break;
        default:
          title = 'Focused session';
      }

      addTask(
        _DailyTask(
          title: title,
          detail: expectedGain ??
              '$rawTopic${reasonLabels.isNotEmpty ? ' • ${reasonLabels.take(2).join(' • ')}' : ''}',
          cta: minutes > 0 ? 'Start • ${minutes}m' : 'Start',
          launchTopic: launchTopic,
          quizPreset:
              row['quizPreset'] is Map ? toMap(row['quizPreset']) : null,
        ),
      );
    }

    if (tasks.length >= 3) {
      return tasks.take(3).toList();
    }

    final weakTopic = weakTopics.isNotEmpty
        ? weakTopics.first['topic']?.toString().trim() ?? ''
        : '';
    if (weakTopic.isNotEmpty) {
      addTask(
        _DailyTask(
          title: 'Repair weakest area',
          detail: weakTopic,
          cta: 'Start repair set',
          launchTopic: _tierAwareLaunchTopic(
            subject: subject,
            level: level,
            topic: '$subject $weakTopic',
          ),
          quizPreset: tierPreset,
        ),
      );
    }

    final map = curriculum;
    if (map != null) {
      if (examInDays != null && examInDays! <= 45 && map.papers.isNotEmpty) {
        final paper = map.papers.first;
        addTask(
          _DailyTask(
            title: 'Timed paper sprint',
            detail: '${paper.title} • exam in ${examInDays}d',
            cta: 'Simulate paper',
            launchTopic: _tierAwareLaunchTopic(
              subject: subject,
              level: level,
              topic: '$subject ${paper.title}',
            ),
            quizPreset: _buildPaperPreset(
              paper,
              subject: subject,
              level: level,
            ),
          ),
        );
      } else if (mockInDays != null &&
          mockInDays! <= 21 &&
          map.papers.isNotEmpty) {
        final paper = map.papers.first;
        addTask(
          _DailyTask(
            title: 'Mock prep paper',
            detail: '${paper.title} • mock in ${mockInDays}d',
            cta: 'Run mock set',
            launchTopic: _tierAwareLaunchTopic(
              subject: subject,
              level: level,
              topic: '$subject ${paper.title}',
            ),
            quizPreset: _buildPaperPreset(
              paper,
              subject: subject,
              level: level,
            ),
          ),
        );
      }

      final untouched =
          map.sections.where((section) => !_sectionCovered(section));
      if (untouched.isNotEmpty) {
        final section = untouched.first;
        addTask(
          _DailyTask(
            title: 'Start untouched section',
            detail: section.title,
            cta: 'Start section',
            launchTopic: _tierAwareLaunchTopic(
              subject: subject,
              level: level,
              topic: '$subject ${section.title}',
            ),
            quizPreset: tierPreset,
          ),
        );
      }

      if (tasks.length < 3) {
        for (final section in map.sections) {
          if (section.topicGroups.isEmpty) continue;
          final group = section.topicGroups.first;
          addTask(
            _DailyTask(
              title: 'Parent-topic consolidation',
              detail: '${section.title} → ${group.title}',
              cta: 'Revise topic',
              launchTopic: _tierAwareLaunchTopic(
                subject: subject,
                level: level,
                topic: '$subject ${section.title} ${group.title}',
              ),
              quizPreset: tierPreset,
            ),
          );
          if (tasks.length >= 3) break;
        }
      }
    }

    return tasks.take(3).toList();
  }

  @override
  Widget build(BuildContext context) {
    final tasks = _buildTasks();
    final dateMessage = examInDays != null
        ? 'GCSE in ${examInDays}d'
        : mockInDays != null
            ? 'Mock in ${mockInDays}d'
            : 'No exam date set yet';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.16),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.24),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.today_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Personalized mission queue',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '$dateMessage • tuned for this subject',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 10),
            if (tasks.isEmpty)
              const Text(
                  'No tasks generated yet. Complete one practice set first.')
            else
              ...tasks.asMap().entries.map((entry) {
                final index = entry.key;
                final task = entry.value;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: Theme.of(context)
                        .colorScheme
                        .surface
                        .withValues(alpha: 0.62),
                    border: Border.all(
                      color: Theme.of(context)
                          .colorScheme
                          .outline
                          .withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 26,
                        height: 26,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: 0.16),
                        ),
                        child: Text(
                          '${index + 1}',
                          style: Theme.of(context)
                              .textTheme
                              .labelMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              task.title,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              task.detail,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.tonal(
                        onPressed: () =>
                            onPractice(task.launchTopic, task.quizPreset),
                        child: Text(task.cta),
                      ),
                    ],
                  ),
                );
              }),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: onOpenPlanning,
                icon: const Icon(Icons.calendar_month_outlined),
                label: const Text('Adjust dates and planning'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PersonalizedFeedbackCard extends StatelessWidget {
  final String? targetGrade;
  final int projectedGrade;
  final String gradeStatus;
  final List<String> weaknessTags;
  final List<Map<String, dynamic>> priorityPitfalls;
  final List<Map<String, dynamic>> examTechniques;

  const _PersonalizedFeedbackCard({
    required this.targetGrade,
    required this.projectedGrade,
    required this.gradeStatus,
    required this.weaknessTags,
    required this.priorityPitfalls,
    required this.examTechniques,
  });

  @override
  Widget build(BuildContext context) {
    final safeTarget = (targetGrade ?? '').trim();

    String gradeMessage() {
      if (safeTarget.isEmpty || projectedGrade <= 0) {
        return 'Run a few sessions to unlock grade trajectory and target guidance.';
      }
      if (gradeStatus == 'on_track') {
        return 'You are currently on track for Grade $safeTarget. Keep your revision consistency high.';
      }
      if (gradeStatus == 'close') {
        return 'You are close to Grade $safeTarget. Target high-mark command-word questions this week.';
      }
      return 'To reach Grade $safeTarget, prioritize weak examiner patterns first.';
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Performance snapshot',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              gradeMessage(),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (weaknessTags.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: weaknessTags
                    .take(3)
                    .map((tag) => Chip(label: Text('Focus: $tag')))
                    .toList(),
              ),
            ],
            if (priorityPitfalls.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                'Top fixes to apply now',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              ...priorityPitfalls.take(2).map((pitfall) {
                final summary = pitfall['summary']?.toString() ?? '';
                final fix = pitfall['fix']?.toString() ?? '';
                if (summary.trim().isEmpty) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest
                          .withValues(alpha: 0.28),
                    ),
                    child: Text(
                      fix.trim().isEmpty ? summary : '$summary\nFix: $fix',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                );
              }),
            ],
            if (examTechniques.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                'Technique to layer in',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              ...examTechniques.take(1).map((technique) {
                final label = technique['label']?.toString() ?? '';
                final guidance = technique['guidance']?.toString() ?? '';
                if (label.trim().isEmpty || guidance.trim().isEmpty) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    '$label: $guidance',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }
}

class _PaperPlanCard extends StatelessWidget {
  final String subject;
  final String level;
  final SubjectCurriculum? curriculum;
  final bool isCurriculumLoading;
  final bool hasCurriculumError;
  final double avgMarksPct;
  final int totalAttempts;
  final Set<String> seenTopics;
  final String statusText;
  final VoidCallback onOpenCurriculum;
  final void Function(String topic, Map<String, dynamic>? preset) onPractice;

  const _PaperPlanCard({
    required this.subject,
    required this.level,
    required this.curriculum,
    required this.isCurriculumLoading,
    required this.hasCurriculumError,
    required this.avgMarksPct,
    required this.totalAttempts,
    required this.seenTopics,
    required this.statusText,
    required this.onOpenCurriculum,
    required this.onPractice,
  });

  @override
  Widget build(BuildContext context) {
    if (isCurriculumLoading) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Subject Structure',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              const Text('Loading board-specific curriculum map...'),
            ],
          ),
        ),
      );
    }

    if (hasCurriculumError) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Subject Structure',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              const Text(
                  'Could not load board-specific curriculum map right now.'),
            ],
          ),
        ),
      );
    }

    if (curriculum == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Subject Structure',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              const Text(
                'Board-specific curriculum map is not available for this target yet. You can still run mission and paper sessions.',
              ),
            ],
          ),
        ),
      );
    }

    final sectionById = {
      for (final section in curriculum!.sections) section.id: section,
    };

    final touchedBySection = <String, bool>{};
    int coveredSections = 0;
    for (final section in curriculum!.sections) {
      final touched = section.topics.any((topic) {
        final normalized = topic.toLowerCase().trim();
        if (normalized.isEmpty) return false;
        return seenTopics.any((seen) => seen.contains(normalized));
      });
      touchedBySection[section.id] = touched;
      if (touched) coveredSections += 1;
    }

    final coveragePct = curriculum!.sections.isEmpty
        ? 0.0
        : coveredSections / curriculum!.sections.length;
    final overallReadiness = totalAttempts > 0
        ? (avgMarksPct * 0.75) + (coveragePct * 0.25)
        : coveragePct * 0.75;
    final currentGrade = _estimateGcseGrade(overallReadiness);
    final nextGrade = currentGrade < 9 ? currentGrade + 1 : null;
    final gapToNext = nextGrade == null
        ? 0.0
        : (((_thresholdForGrade(nextGrade) - overallReadiness)
                    .clamp(0.0, 1.0)) *
                100)
            .toDouble();

    final paperProfiles = curriculum!.papers.map((paper) {
      final totalSections = paper.sectionIds.length;
      final coveredInPaper = paper.sectionIds
          .where((sectionId) => touchedBySection[sectionId] == true)
          .length;
      final coverage =
          totalSections == 0 ? 0.0 : coveredInPaper / totalSections;
      final paperReadiness =
          ((avgMarksPct * 0.7) + (coverage * 0.3)).clamp(0.0, 1.0);
      final paperSections = paper.sectionIds
          .map((sectionId) => sectionById[sectionId])
          .whereType<CurriculumSection>()
          .toList(growable: false);
      var weakestSectionTitle = 'Mixed focus';
      for (final section in paperSections) {
        if (touchedBySection[section.id] != true) {
          weakestSectionTitle = section.title;
          break;
        }
      }
      if (weakestSectionTitle == 'Mixed focus' && paperSections.isNotEmpty) {
        weakestSectionTitle = paperSections.first.title;
      }
      return {
        'paper': paper,
        'readiness': paperReadiness,
        'coveredSections': coveredInPaper,
        'totalSections': totalSections,
        'weakSection': weakestSectionTitle.trim().isNotEmpty
            ? weakestSectionTitle
            : 'Mixed focus',
      };
    }).toList()
      ..sort((a, b) =>
          ((a['readiness'] as double)).compareTo(b['readiness'] as double));

    final focusSections = curriculum!.sections
        .where((section) => touchedBySection[section.id] != true)
        .take(2)
        .toList(growable: false);
    final sectionActions = focusSections.isNotEmpty
        ? focusSections
        : curriculum!.sections.take(2).toList(growable: false);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Paper actions',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              statusText,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(
                  label: Text(
                    '$coveredSections/${curriculum!.sections.length} sections started',
                  ),
                ),
                Chip(
                  label: Text(
                    nextGrade == null
                        ? 'Projected grade $currentGrade'
                        : 'Grade $currentGrade now • ${gapToNext.toStringAsFixed(1)}% to grade $nextGrade',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (paperProfiles.isEmpty)
              const Text('Paper actions will appear once papers are available.')
            else
              ...paperProfiles.take(2).map((profile) {
                final paper = profile['paper'] as CurriculumPaper;
                final readiness =
                    ((profile['readiness'] as double) * 100).round();
                final weakSection =
                    profile['weakSection']?.toString() ?? 'Mixed focus';
                final paperTopic = _tierAwareLaunchTopic(
                  subject: subject,
                  level: level,
                  topic: '$subject ${paper.title}',
                );
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest
                        .withValues(alpha: 0.16),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              paper.title,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Readiness $readiness% • fastest gain in $weakSection',
                              style: Theme.of(context).textTheme.bodySmall,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.tonal(
                        onPressed: () => onPractice(
                          paperTopic,
                          _buildPaperPreset(
                            paper,
                            subject: subject,
                            level: level,
                          ),
                        ),
                        child: const Text('Run'),
                      ),
                    ],
                  ),
                );
              }),
            if (sectionActions.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                'Quick section starts',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: sectionActions.map((section) {
                  return ActionChip(
                    label: Text(section.title),
                    onPressed: () => onPractice(
                      _tierAwareLaunchTopic(
                        subject: subject,
                        level: level,
                        topic: '$subject ${section.title}',
                      ),
                      _tierAwareQuizPreset(subject: subject, level: level),
                    ),
                  );
                }).toList(),
              ),
            ],
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: onOpenCurriculum,
                icon: const Icon(Icons.account_tree_outlined),
                label: const Text('View full paper and section map'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
