import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:neurobits/core/providers.dart';
import 'package:neurobits/features/exams/exam_curriculum.dart';
import 'package:neurobits/services/convex_client_service.dart';

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

Map<String, dynamic> _buildCurriculumQuizPreset({
  required String subject,
  required String level,
  required String board,
  required int questionCount,
  required int timePerQuestion,
  required String scopeContext,
  bool includeHints = false,
}) {
  final tierPreset = _tierAwareQuizPreset(subject: subject, level: level);
  final safeCount = questionCount.clamp(10, 32);
  final safeTime = timePerQuestion.clamp(45, 120);
  final boardText = board.trim().isEmpty ? '' : ' (${board.trim()})';
  final baseHints = tierPreset?['includeHints'] is bool
      ? tierPreset!['includeHints'] as bool
      : false;
  return {
    'questionCount': safeCount,
    'timePerQuestion': safeTime,
    'totalTimeLimit': safeCount * safeTime,
    'timedMode': true,
    'difficulty': tierPreset?['difficulty']?.toString() ?? 'Medium',
    'includeCodeChallenges': false,
    'includeMcqs': true,
    'includeInput': true,
    'includeFillBlank': false,
    'includeHints': includeHints || baseHints,
    'includeImageQuestions': false,
    'examModeProfile': 'exam_standard',
    'examFocusContext':
        'GCSE ${subject.trim()}$boardText. $scopeContext Use GCSE command words, board-level framing, and mark-scheme-ready phrasing.',
    'autoStart': true,
  };
}

class _SubtopicCluster {
  final String label;
  final List<String> members;

  const _SubtopicCluster({
    required this.label,
    required this.members,
  });

  bool get isMerged => members.length > 1;
}

List<_SubtopicCluster> _buildSubtopicClusters(List<String> subtopics) {
  final seen = <String>{};
  final out = <_SubtopicCluster>[];
  for (final raw in subtopics) {
    final title = raw.trim();
    if (title.isEmpty) continue;
    final key = title.toLowerCase();
    if (!seen.add(key)) continue;
    out.add(_SubtopicCluster(label: title, members: [title]));
  }
  return out;
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

  if (sectionRows.isEmpty) {
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

  if (sections.isEmpty) {
    return fallback;
  }

  return SubjectCurriculum(
    subject: subject,
    sections: sections,
    papers: fallback?.papers ?? const <CurriculumPaper>[],
  );
}

class ExamCurriculumBreakdownScreen extends ConsumerWidget {
  final String targetId;

  const ExamCurriculumBreakdownScreen({
    super.key,
    required this.targetId,
  });

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
    final profileAsync = ref.watch(userExamProfileByTargetProvider(targetId));

    return Scaffold(
      appBar: AppBar(title: const Text('Curriculum Breakdown')),
      body: dashboardAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Could not load curriculum: $error'),
          ),
        ),
        data: (dashboard) {
          final target = dashboard['target'] as Map<String, dynamic>?;
          if (target == null) {
            return const Center(child: Text('Exam target not found.'));
          }

          final subject = target['subject']?.toString() ?? 'Subject';
          final board = target['board']?.toString() ?? '';
          final level = target['level']?.toString() ?? '';

          if (profileAsync.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (profileAsync.hasError) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Could not load board-specific curriculum right now.',
                ),
              ),
            );
          }

          final profile = profileAsync.valueOrNull;
          final sourceCount = convexInt(profile?['sourceCount']);
          final curriculum = _curriculumFromProfile(subject, profile, null);

          if (sourceCount <= 0 ||
              curriculum == null ||
              curriculum.sections.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'No board curriculum map is available for this target yet.',
                ),
              ),
            );
          }

          final topicCount = curriculum.sections.fold<int>(
            0,
            (sum, section) =>
                sum +
                (section.topicGroups.isNotEmpty
                    ? section.topicGroups.length
                    : (section.topics.isNotEmpty ? 1 : 0)),
          );
          final subtopicCount = curriculum.sections.fold<int>(
            0,
            (sum, section) {
              if (section.topicGroups.isNotEmpty) {
                return sum +
                    section.topicGroups.fold<int>(
                      0,
                      (inner, group) => inner + group.subtopics.length,
                    );
              }
              return sum + section.topics.length;
            },
          );

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: Theme.of(context)
                      .colorScheme
                      .surfaceContainerHighest
                      .withValues(alpha: 0.28),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$subject • $board ${level.trim().isEmpty ? '' : '• $level'}',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Chip(
                            label:
                                Text('${curriculum.sections.length} sections')),
                        Chip(label: Text('$topicCount topics')),
                        Chip(label: Text('$subtopicCount subtopics')),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              ...curriculum.sections.map((section) {
                final sectionTopic = _tierAwareLaunchTopic(
                  subject: subject,
                  level: level,
                  topic: '$subject ${section.title}',
                );
                final sectionSubtopicCount = section.topicGroups.isNotEmpty
                    ? section.topicGroups.fold<int>(
                        0,
                        (sum, group) => sum + group.subtopics.length,
                      )
                    : section.topics.length;
                final sectionPreset = _buildCurriculumQuizPreset(
                  subject: subject,
                  level: level,
                  board: board,
                  questionCount: 20,
                  timePerQuestion: 80,
                  scopeContext:
                      'Section focus: "${section.title}". Sample the full section and include both short recall and written exam responses.',
                );

                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    section.title,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    section.topicGroups.isNotEmpty
                                        ? '${section.topicGroups.length} parent topics • $sectionSubtopicCount subtopics'
                                        : '${section.topics.length} subtopics',
                                    style:
                                        Theme.of(context).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            FilledButton.tonal(
                              onPressed: () => _startRevision(
                                context,
                                ref,
                                targetId: targetId,
                                launchTopic: sectionTopic,
                                quizPreset: sectionPreset,
                              ),
                              child: const Text('Practice section'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (section.topicGroups.isNotEmpty)
                          ...section.topicGroups.map((group) {
                            final subtopicClusters =
                                _buildSubtopicClusters(group.subtopics);
                            final groupTopic = _tierAwareLaunchTopic(
                              subject: subject,
                              level: level,
                              topic: '$subject ${section.title} ${group.title}',
                            );
                            final groupPreset = _buildCurriculumQuizPreset(
                              subject: subject,
                              level: level,
                              board: board,
                              questionCount: 16,
                              timePerQuestion: 75,
                              scopeContext:
                                  'Parent topic focus: section "${section.title}", parent topic "${group.title}". Cover multiple subtopics and apply exam command words.',
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
                                border: Border.all(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .outline
                                      .withValues(alpha: 0.22),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          group.title,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleSmall
                                              ?.copyWith(
                                                fontWeight: FontWeight.w700,
                                              ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      OutlinedButton(
                                        onPressed: () => _startRevision(
                                          context,
                                          ref,
                                          targetId: targetId,
                                          launchTopic: groupTopic,
                                          quizPreset: groupPreset,
                                        ),
                                        child:
                                            const Text('Practice parent topic'),
                                      ),
                                    ],
                                  ),
                                  if (subtopicClusters.isEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 6),
                                      child: Text(
                                        'No mapped subtopics yet.',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall,
                                      ),
                                    )
                                  else
                                    Container(
                                      margin: const EdgeInsets.only(top: 6),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .outline
                                              .withValues(alpha: 0.2),
                                        ),
                                      ),
                                      child: ExpansionTile(
                                        tilePadding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 0,
                                        ),
                                        childrenPadding:
                                            const EdgeInsets.fromLTRB(
                                                10, 0, 10, 8),
                                        title: Text(
                                          'Subtopics (${subtopicClusters.length})',
                                          style: Theme.of(context)
                                              .textTheme
                                              .labelLarge
                                              ?.copyWith(
                                                fontWeight: FontWeight.w700,
                                              ),
                                        ),
                                        children: [
                                          ...subtopicClusters.map((cluster) {
                                            final subtopic = cluster.label;
                                            final subtopicLaunch =
                                                _tierAwareLaunchTopic(
                                              subject: subject,
                                              level: level,
                                              topic:
                                                  '$subject ${section.title} ${group.title} $subtopic',
                                            );
                                            final subtopicPreset =
                                                _buildCurriculumQuizPreset(
                                              subject: subject,
                                              level: level,
                                              board: board,
                                              questionCount: 12,
                                              timePerQuestion: 70,
                                              includeHints: true,
                                              scopeContext:
                                                  'Subtopic focus: section "${section.title}", parent topic "${group.title}", cluster "$subtopic". Include close points: ${cluster.members.join('; ')}. Keep GCSE-level specificity and exam-style phrasing.',
                                            );
                                            return Padding(
                                              padding: const EdgeInsets.only(
                                                  bottom: 6),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    children: [
                                                      Expanded(
                                                        child: Text(
                                                          subtopic,
                                                          style:
                                                              Theme.of(context)
                                                                  .textTheme
                                                                  .bodyMedium,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      TextButton(
                                                        onPressed: () =>
                                                            _startRevision(
                                                          context,
                                                          ref,
                                                          targetId: targetId,
                                                          launchTopic:
                                                              subtopicLaunch,
                                                          quizPreset:
                                                              subtopicPreset,
                                                        ),
                                                        child: const Text(
                                                            'Practice subtopic'),
                                                      ),
                                                    ],
                                                  ),
                                                  if (cluster.isMerged)
                                                    Text(
                                                      'Merged ${cluster.members.length} close points',
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .labelSmall,
                                                    ),
                                                ],
                                              ),
                                            );
                                          }),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            );
                          })
                        else
                          Builder(
                            builder: (context) {
                              final subtopicClusters =
                                  _buildSubtopicClusters(section.topics);
                              return Container(
                                margin: const EdgeInsets.only(top: 6),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .outline
                                        .withValues(alpha: 0.2),
                                  ),
                                ),
                                child: ExpansionTile(
                                  tilePadding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 0,
                                  ),
                                  childrenPadding:
                                      const EdgeInsets.fromLTRB(10, 0, 10, 8),
                                  title: Text(
                                    'Subtopics (${subtopicClusters.length})',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelLarge
                                        ?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                  children: [
                                    ...subtopicClusters.map((cluster) {
                                      final subtopic = cluster.label;
                                      final launch = _tierAwareLaunchTopic(
                                        subject: subject,
                                        level: level,
                                        topic:
                                            '$subject ${section.title} $subtopic',
                                      );
                                      final subtopicPreset =
                                          _buildCurriculumQuizPreset(
                                        subject: subject,
                                        level: level,
                                        board: board,
                                        questionCount: 12,
                                        timePerQuestion: 70,
                                        includeHints: true,
                                        scopeContext:
                                            'Subtopic focus: section "${section.title}", cluster "$subtopic". Include close points: ${cluster.members.join('; ')}. Keep GCSE-level specificity and exam-style phrasing.',
                                      );
                                      return Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 6),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(child: Text(subtopic)),
                                                const SizedBox(width: 8),
                                                TextButton(
                                                  onPressed: () =>
                                                      _startRevision(
                                                    context,
                                                    ref,
                                                    targetId: targetId,
                                                    launchTopic: launch,
                                                    quizPreset: subtopicPreset,
                                                  ),
                                                  child: const Text(
                                                      'Practice subtopic'),
                                                ),
                                              ],
                                            ),
                                            if (cluster.isMerged)
                                              Text(
                                                'Merged ${cluster.members.length} close points',
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .labelSmall,
                                              ),
                                          ],
                                        ),
                                      );
                                    }),
                                  ],
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }
}
