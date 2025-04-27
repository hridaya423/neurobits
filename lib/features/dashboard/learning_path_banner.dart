import 'package:flutter/material.dart';
import 'package:neurobits/features/learning_path/tweak_learning_path_screen.dart';
class LearningPathBanner extends StatelessWidget {
  final Map<String, dynamic>? path;
  final int currentStep;
  final int totalSteps;
  final VoidCallback onChangePath;
  const LearningPathBanner({
    Key? key,
    required this.path,
    required this.currentStep,
    required this.totalSteps,
    required this.onChangePath,
  }) : super(key: key);
  String _capitalizeTopicName(String topic) {
    if (topic.isEmpty) return topic;
    final words = topic.split(' ');
    return words.map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }
  @override
  Widget build(BuildContext context) {
    if (path == null) return const SizedBox.shrink();
    final name = path!['name'] ?? 'Learning Path';
    final description = path!['description'] ?? 'No description available';
    final topics = path!['topics'] as List<dynamic>?;
    final topicNames = topics != null
        ? topics
            .map((t) {
              String rawName = '';
              if (t is Map<String, dynamic>) {
                if (t['topics'] is List && (t['topics'] as List).isNotEmpty) {
                  final nested =
                      (t['topics'] as List).first as Map<String, dynamic>;
                  rawName = nested['name'] as String? ?? '';
                } else {
                  rawName = t['topic'] as String? ?? '';
                }
              }
              return _capitalizeTopicName(rawName);
            })
            .where((name) => name.isNotEmpty)
            .toList()
        : <String>[];
    final topicsText = topicNames.isNotEmpty
        ? 'Topics: ${topicNames.join(", ")}'
        : 'No topics available';
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.primaryContainer,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: onChangePath,
                color: Theme.of(context).colorScheme.onPrimary,
                tooltip: 'Change Path',
              ),
              IconButton(
                icon: const Icon(Icons.tune),
                tooltip: 'Tweak Path',
                color: Theme.of(context).colorScheme.onPrimary,
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const TweakLearningPathScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            topicsText,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: totalSteps > 0 ? currentStep / totalSteps : 0,
            backgroundColor:
                Theme.of(context).colorScheme.onPrimary.withOpacity(0.3),
            valueColor:
                AlwaysStoppedAnimation(Theme.of(context).colorScheme.onPrimary),
          ),
          const SizedBox(height: 8),
          Text(
            'Step $currentStep of $totalSteps',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
          ),
        ],
      ),
    );
  }
}