import 'package:flutter/material.dart';

class LearningPathChallengeCard extends StatelessWidget {
  final Map<String, dynamic> challenge;
  final bool isCurrent;
  const LearningPathChallengeCard({
    super.key,
    required this.challenge,
    this.isCurrent = false,
  });
  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: isCurrent ? 4 : 1,
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8.0),
        side: isCurrent
            ? BorderSide(
                color: Theme.of(context).colorScheme.primary, width: 1.5)
            : BorderSide.none,
      ),
      color: isCurrent
          ? Theme.of(context).colorScheme.primary.withOpacity(0.08)
          : null,
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
        title: Text(challenge['title'] ?? 'Challenge Title Missing'),
        subtitle: Text(challenge['description'] ?? 'No description.'),
      ),
    );
  }
}
