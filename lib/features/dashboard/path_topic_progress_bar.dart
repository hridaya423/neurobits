import 'package:flutter/material.dart';
class PathTopicProgressBar extends StatelessWidget {
  final int currentStep;
  final int totalSteps;
  final String? topicName;
  final String? topicDescription;
  const PathTopicProgressBar({
    super.key,
    required this.currentStep,
    required this.totalSteps,
    this.topicName,
    this.topicDescription,
  });
  @override
  Widget build(BuildContext context) {
    final percent =
        totalSteps > 0 ? (currentStep / totalSteps).clamp(0.0, 1.0) : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (topicName != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 4.0),
            child: Text(
              'Now learning: $topicName',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        if (topicDescription != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Text(
              topicDescription!,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        LinearProgressIndicator(value: percent),
        Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Text('Step $currentStep of $totalSteps'),
        ),
      ],
    );
  }
}