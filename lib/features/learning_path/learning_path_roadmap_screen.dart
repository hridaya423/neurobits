import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/learning_path_providers.dart';
import 'package:neurobits/services/convex_client_service.dart';

class LearningPathRoadmapScreen extends ConsumerStatefulWidget {
  const LearningPathRoadmapScreen({super.key});
  @override
  ConsumerState<LearningPathRoadmapScreen> createState() =>
      _LearningPathRoadmapScreenState();
}

class _LearningPathRoadmapScreenState
    extends ConsumerState<LearningPathRoadmapScreen> {
  final bool _isGeneratingQuiz = false;
  String? _generatingChallengeId;

  Map<int, Map<String, dynamic>> _buildDayProgress(
      List<Map<String, dynamic>> challenges) {
    final progress = <int, Map<String, dynamic>>{};
    for (final challenge in challenges) {
      final day = (challenge['day'] as num?)?.toInt() ?? 1;
      final entry = progress.putIfAbsent(
          day,
          () => {
                'total': 0,
                'completed': 0,
                'firstChallengeId': null,
                'topic': null,
              });
      entry['total'] = (entry['total'] as int) + 1;
      if (challenge['completed'] == true) {
        entry['completed'] = (entry['completed'] as int) + 1;
      }
      entry['firstChallengeId'] ??= challenge['_id']?.toString();
      entry['topic'] ??= challenge['topic']?.toString();
    }
    return progress;
  }

  List<Map<String, dynamic>> _buildRoadmapDays(
    Map<String, dynamic> userPath,
    List<Map<String, dynamic>> challenges,
  ) {
    final pathList =
        isConvexList(userPath['path']) ? toList(userPath['path']) : null;
    if (pathList != null && pathList.isNotEmpty) {
      final days = pathList
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
      days.sort((a, b) {
        final aDay = (a['day'] as num?)?.toInt() ?? 1;
        final bDay = (b['day'] as num?)?.toInt() ?? 1;
        return aDay.compareTo(bDay);
      });
      return days;
    }

    final byDay = <int, Map<String, dynamic>>{};
    for (final ch in challenges) {
      final day = (ch['day'] as num?)?.toInt() ?? 1;
      byDay.putIfAbsent(day, () {
        return {
          'day': day,
          'topic': ch['topic'],
          'title': ch['title'],
          'description': ch['description'],
        };
      });
    }
    final dayKeys = byDay.keys.toList()..sort();
    return dayKeys.map((day) => byDay[day]!).toList();
  }

  @override
  Widget build(BuildContext context) {
    final userPath = ref.watch(userPathProvider);
    if (userPath == null) {
      return const Scaffold(
        appBar: null,
        body: Center(child: Text('No active learning path')),
      );
    }
    final challengesAsync =
        ref.watch(userPathChallengesProvider(userPath['user_path_id']));
    return Scaffold(
      appBar: AppBar(
        title: Text(userPath['name'] ?? 'Learning Path Roadmap'),
      ),
      body: challengesAsync.when(
        data: (challenges) {
          final days = _buildRoadmapDays(userPath, challenges);
          final progress = _buildDayProgress(challenges);
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: days.length,
            itemBuilder: (context, index) {
              final dayItem = days[index];
              final int currentStep =
                  (userPath['current_step'] as num?)?.toInt() ?? 1;
              final int dayNumber =
                  (dayItem['day'] as num?)?.toInt() ?? (index + 1);
              final dayProgress = progress[dayNumber] ??
                  {'total': 0, 'completed': 0, 'firstChallengeId': null};
              final total = dayProgress['total'] as int;
              final completed = dayProgress['completed'] as int;
              final required = total > 0 ? ((total * 2) / 3).ceil() : 0;
              final bool isCompleted = total > 0 && completed >= required;
              final bool isCurrent = dayNumber == currentStep;
              final bool isUnlocked = dayNumber <= currentStep;
              final String topic = (dayItem['topic'] ?? '').toString().trim();
              final String title =
                  (dayItem['title'] ?? topic).toString().trim();
              final String description =
                  (dayItem['description'] ?? '').toString();
              final String challengeId =
                  dayProgress['firstChallengeId']?.toString() ?? '';
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                elevation: isCurrent ? 4 : 1,
                color: isCurrent
                    ? Theme.of(context).colorScheme.primary.withOpacity(0.08)
                    : null,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: isCurrent
                      ? BorderSide(
                          color: Theme.of(context).colorScheme.primary,
                          width: 1.5)
                      : BorderSide.none,
                ),
                child: ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  leading: CircleAvatar(
                    radius: 24,
                    backgroundColor: isCompleted
                        ? Colors.green.shade400
                        : isCurrent
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.secondaryContainer,
                    child: _isGeneratingQuiz &&
                            _generatingChallengeId == challengeId
                        ? const Padding(
                            padding: EdgeInsets.all(8.0),
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : Icon(
                            isCompleted
                                ? Icons.check_circle_outline
                                : isCurrent
                                    ? Icons.play_circle_outline
                                    : Icons.radio_button_unchecked,
                            color: isCompleted || isCurrent
                                ? Colors.white
                                : Theme.of(context)
                                    .colorScheme
                                    .onSecondaryContainer,
                            size: 28,
                          ),
                  ),
                  title: Text(
                    title.isEmpty ? 'Day $dayNumber' : title,
                    style: TextStyle(
                      fontWeight:
                          isCurrent ? FontWeight.bold : FontWeight.normal,
                      color: isCurrent
                          ? Theme.of(context).colorScheme.primary
                          : null,
                      fontSize: 16,
                    ),
                  ),
                  subtitle: Text(description,
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Day $dayNumber',
                          style: Theme.of(context).textTheme.bodySmall),
                      const SizedBox(width: 8),
                      if (isCurrent)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'CURRENT',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      if (!isUnlocked && !isCompleted)
                        Icon(Icons.lock_outline,
                            size: 16, color: Colors.grey.shade400),
                    ],
                  ),
                  enabled: isUnlocked,
                  onTap: (!isUnlocked || _isGeneratingQuiz)
                      ? null
                      : () async {
                          if (topic.isEmpty) return;
                          context.push(
                            '/topic/${Uri.encodeComponent(topic)}',
                            extra: {'userPathChallengeId': challengeId},
                          );
                        },
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text('Error loading challenges: $error'),
            const SizedBox(height: 16),
            ElevatedButton(
                onPressed: () => ref.refresh(
                    userPathChallengesProvider(userPath['user_path_id'])),
                child: const Text("Retry"))
          ]),
        ),
      ),
    );
  }
}
