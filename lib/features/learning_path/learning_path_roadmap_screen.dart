import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/learning_path_providers.dart';

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
        data: (challenges) => ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: challenges.length,
          itemBuilder: (context, index) {
            final challenge = challenges[index];
            final bool isCompleted = challenge['completed'] == true;
            final rawStep = userPath['current_step'];
            final int currentStep = rawStep is int
                ? rawStep
                : int.tryParse(rawStep?.toString() ?? '') ?? 1;
            final bool isCurrent = (index + 1) == currentStep;
            final String topic =
                challenge['topic']?.toString() ?? 'Unknown Topic';
            final String challengeId = challenge['id']?.toString() ?? '';
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
                  child:
                      _isGeneratingQuiz && _generatingChallengeId == challengeId
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
                  challenge['title'] ?? 'Challenge Step',
                  style: TextStyle(
                    fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                    color: isCurrent
                        ? Theme.of(context).colorScheme.primary
                        : null,
                    fontSize: 16,
                  ),
                ),
                subtitle: Text(challenge['description'] ?? '',
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Day ${challenge['day']}',
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
                    if (!isCurrent && !isCompleted)
                      Icon(Icons.lock_outline,
                          size: 16, color: Colors.grey.shade400),
                  ],
                ),
                enabled: isCurrent,
                onTap: (!isCurrent || _isGeneratingQuiz)
                    ? null
                    : () async {
                        context.push('/topic/${Uri.encodeComponent(topic)}');
                      },
              ),
            );
          },
        ),
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
