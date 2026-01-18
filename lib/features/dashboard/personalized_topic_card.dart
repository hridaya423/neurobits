import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:neurobits/services/user_analytics_service.dart';

class PersonalizedTopicCard extends StatelessWidget {
  final PersonalizedRecommendation recommendation;
  final int index;

  const PersonalizedTopicCard({
    super.key,
    required this.recommendation,
    this.index = 0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPerfectMatch = (recommendation.semanticRelevance ?? 0) >= 0.95;
    final isHighlyEngaging = (recommendation.engagementPrediction ?? 0) >= 0.9;

    final cardWidget = Card(
        elevation: isPerfectMatch ? 4 : 2,
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Container(
          decoration: isPerfectMatch
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.purple.withOpacity(0.5),
                    width: 2,
                  ),
                )
              : null,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _onTapTopic(context),
            child: Container(
              padding: const EdgeInsets.all(12),
              width: 240,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isPerfectMatch)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Icon(Icons.auto_awesome,
                              size: 16, color: Colors.purple),
                          const SizedBox(width: 4),
                          Text(
                            'Perfect Match',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: Colors.purple,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  Text(
                    recommendation.topicName,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  if (recommendation.isNewTopic &&
                      recommendation.topicDescription != null &&
                      recommendation.topicDescription!.isNotEmpty)
                    Text(
                      recommendation.topicDescription!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                        fontStyle: FontStyle.italic,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  if (recommendation.isNewTopic &&
                      recommendation.topicDescription != null &&
                      recommendation.topicDescription!.isNotEmpty)
                    const SizedBox(height: 4),
                  Text(
                    recommendation.reason,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.7),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getDifficultyColor(theme).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _getDifficultyColor(theme).withOpacity(0.3),
                          ),
                        ),
                        child: Text(
                          recommendation.difficulty,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: _getDifficultyColor(theme),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.schedule_rounded,
                            size: 16,
                            color: theme.colorScheme.onSurface.withOpacity(0.6),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${recommendation.estimatedTime}min',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color:
                                  theme.colorScheme.onSurface.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Icon(
                        Icons.arrow_forward_rounded,
                        size: 20,
                        color: theme.colorScheme.primary,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ));

    return cardWidget;
  }

  void _onTapTopic(BuildContext context) {
    final topicPath = Uri.encodeComponent(recommendation.topicName);
    if (recommendation.isNewTopic) {
      context.push('/topic/$topicPath', extra: {
        'topic': recommendation.topicName,
        'topicId': recommendation.topicId,
        'difficulty': recommendation.difficulty,
        'estimatedTime': recommendation.estimatedTime,
        'isPersonalized': true,
        'isNewTopic': true,
      });
    } else {
      context.push('/topic/$topicPath', extra: {
        'topic': recommendation.topicName,
        'topicId': recommendation.topicId,
        'difficulty': recommendation.difficulty,
        'estimatedTime': recommendation.estimatedTime,
        'isPersonalized': true,
        'isExistingQuiz': true,
      });
    }
  }

  Color _getCategoryColor(ThemeData theme) {
    switch (recommendation.category) {
      case 'might_love':
        return Colors.deepPurple;
      case 'touch_again':
        return Colors.blue;
      default:
        return theme.colorScheme.primary;
    }
  }

  IconData _getCategoryIcon() {
    switch (recommendation.category) {
      case 'might_love':
        return Icons.favorite_rounded;
      case 'touch_again':
        return Icons.refresh_rounded;
      default:
        return Icons.star_rounded;
    }
  }

  Color _getDifficultyColor(ThemeData theme) {
    switch (recommendation.difficulty.toLowerCase()) {
      case 'easy':
        return Colors.green;
      case 'medium':
        return Colors.orange;
      case 'hard':
        return Colors.red;
      default:
        return theme.colorScheme.primary;
    }
  }
}
