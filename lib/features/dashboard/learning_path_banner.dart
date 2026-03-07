import 'package:flutter/material.dart';
import 'package:neurobits/features/learning_path/tweak_learning_path_screen.dart';

class LearningPathBanner extends StatelessWidget {
  final Map<String, dynamic>? path;
  final int currentStep;
  final int totalSteps;
  final VoidCallback onViewRoadmap;
  const LearningPathBanner({
    super.key,
    required this.path,
    required this.currentStep,
    required this.totalSteps,
    required this.onViewRoadmap,
  });

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
    final description = path!['description'] ?? 'AI-generated learning path.';

    final colorScheme = Theme.of(context).colorScheme;
    final primary = colorScheme.primary;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withOpacity(0.18),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colorScheme.outline.withOpacity(0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.map_outlined),
            onPressed: onViewRoadmap,
            color: colorScheme.onSurfaceVariant,
            tooltip: 'View Roadmap',
          ),
          IconButton(
            icon: const Icon(Icons.tune),
            tooltip: 'Tweak Path',
            color: colorScheme.onSurfaceVariant,
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
    );
  }
}
