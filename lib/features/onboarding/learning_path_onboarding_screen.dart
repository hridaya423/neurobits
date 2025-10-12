import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/supabase.dart';
import '../../core/providers.dart';
import '../../core/learning_path_providers.dart';
import 'custom_path_onboarding_screen.dart';

final learningPathsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final currentUser = ref.watch(userProvider).value;
  final query = SupabaseService.client
      .from('learning_paths')
      .select('id, name, description')
      .eq('is_active', true);
  if (currentUser != null) {
    final otherCustomRows = await SupabaseService.client
        .from('user_learning_paths')
        .select('path_id')
        .eq('is_custom', true)
        .neq('user_id', currentUser['id']);
    final blockedIds = (otherCustomRows as List)
        .map((e) => e['path_id']?.toString())
        .whereType<String>()
        .toList();
    if (blockedIds.isNotEmpty) {
      query.not('id', 'in', blockedIds);
    }
  }
  final result = await query.order('created_at');
  return List<Map<String, dynamic>>.from(result);
});

class LearningPathOnboardingScreen extends ConsumerWidget {
  const LearningPathOnboardingScreen({super.key});
  IconData _getPathIcon(String pathName) {
    final nameLower = pathName.toLowerCase();
    if (nameLower.contains('python') || nameLower.contains('programming')) {
      return Icons.code;
    } else if (nameLower.contains('math')) {
      return Icons.calculate;
    } else if (nameLower.contains('science')) {
      return Icons.science;
    } else if (nameLower.contains('language')) {
      return Icons.language;
    } else if (nameLower.contains('business')) {
      return Icons.business;
    }
    return Icons.school;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pathsAsync = ref.watch(learningPathsProvider);
    final user = ref.watch(userProvider).value;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Choose Your Learning Path'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: pathsAsync.when(
        data: (paths) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Select a structured learning path to guide your journey',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.grey.shade700,
                  ),
            ),
            const SizedBox(height: 24),
            ...paths.map((path) => _buildPathCard(context, ref, user, path)),
            const SizedBox(height: 8),
            _buildCustomPathCard(context),
            const SizedBox(height: 8),
            _buildFreeModeCard(context, ref, user),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _buildPathCard(BuildContext context, WidgetRef ref, dynamic user,
      Map<String, dynamic> path) {
    final pathName = path['name'] ?? 'Learning Path';
    final pathDescription = path['description'] ?? 'No description available';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () async {
            if (user == null) return;
            if (path['id'] != null) {
              try {
                final existingPathResults = await SupabaseService.client
                    .from('user_learning_paths')
                    .select('id, path_id, current_step')
                    .eq('user_id', user['id'])
                    .is_('completed_at', null);

                Map<String, dynamic>? existingPath;
                if (existingPathResults.isNotEmpty) {
                  existingPath = existingPathResults.first;
                }

                String? userPathId;
                if (existingPath != null) {
                  if (existingPath['path_id'] == path['id']) {
                    final pathId = path['id'];

                    if (pathId == null) {
                      throw Exception(
                          'Path ID is null - cannot query learning path');
                    }

                    final learningPathResults = await SupabaseService.client
                        .from('learning_paths')
                        .select('id, name, description, is_active')
                        .eq('id', pathId);

                    if (learningPathResults.isEmpty) {
                      throw Exception('Learning path not found');
                    }

                    final learningPath = learningPathResults.first;
                    if (learningPath != null) {
                      userPathId = existingPath['id'];

                      final existingChallenges = await SupabaseService.client
                          .from('user_path_challenges')
                          .select('id')
                          .eq('user_path_id', userPathId);

                      if (existingChallenges.isEmpty) {
                        final pathTopicsResults = await SupabaseService.client
                            .from('learning_path_topics')
                            .select('*, topics(name)')
                            .eq('path_id', path['id'])
                            .order('step_number', ascending: true);

                        if (pathTopicsResults.isNotEmpty) {
                          final challengesToInsert =
                              pathTopicsResults.map((topic) {
                            final topicData = topic['topics'];
                            final topicName =
                                topicData != null && topicData['name'] != null
                                    ? topicData['name']
                                    : 'Topic ${topic['step_number']}';
                            return {
                              'user_path_id': userPathId,
                              'day': topic['step_number'],
                              'topic': topicName,
                              'challenge_type': 'quiz',
                              'title': topicName,
                              'description': topic['description'] ?? '',
                              'completed': false,
                            };
                          }).toList();

                          await SupabaseService.client
                              .from('user_path_challenges')
                              .insert(challengesToInsert);

                          debugPrint(
                              '[LearningPathSelection] Created ${challengesToInsert.length} challenges for existing user path');
                        }
                      }

                      ref.read(userPathProvider.notifier).state = {
                        ...learningPath,
                        'current_step': existingPath['current_step'] ?? 1,
                        'user_path_id': userPathId,
                      };
                      await SupabaseService.client.from('users').update({
                        'onboarding_complete': true,
                        'streak_goal': 7
                      }).eq('id', user['id']);
                      if (context.mounted) {
                        Navigator.of(context).pop(true);
                      }
                    }
                    return;
                  }
                  final updateResults = await SupabaseService.client
                      .from('user_learning_paths')
                      .update({
                        'path_id': path['id'],
                        'current_step': 1,
                        'started_at': DateTime.now().toIso8601String(),
                        'completed_at': null,
                        'is_complete': false,
                      })
                      .eq('id', existingPath['id'])
                      .select('id');

                  if (updateResults.isEmpty) {
                    throw Exception('Failed to update user path');
                  }

                  final updateResult = updateResults.first;
                  if (updateResult != null) {
                    userPathId = updateResult['id'];
                  }
                } else {
                  final newPathResults = await SupabaseService.client
                      .from('user_learning_paths')
                      .insert({
                    'user_id': user['id'],
                    'path_id': path['id'],
                    'current_step': 1,
                    'started_at': DateTime.now().toIso8601String(),
                    'completed_at': null,
                    'is_complete': false,
                  }).select('id');

                  if (newPathResults.isEmpty) {
                    throw Exception('Failed to create new path');
                  }

                  final newPathResult = newPathResults.first;
                  if (newPathResult == null) {
                    throw Exception('Failed to create new path');
                  }
                  userPathId = newPathResult['id'];
                }
                if (userPathId == null) {
                  throw Exception('Failed to get user path ID');
                }
                await SupabaseService.client
                    .from('user_path_challenges')
                    .delete()
                    .eq('user_path_id', userPathId);

                final pathTopicsResults = await SupabaseService.client
                    .from('learning_path_topics')
                    .select('*, topics(name)')
                    .eq('path_id', path['id'])
                    .order('step_number', ascending: true);

                if (pathTopicsResults.isNotEmpty) {
                  final challengesToInsert = pathTopicsResults.map((topic) {
                    final topicData = topic['topics'];
                    final topicName =
                        topicData != null && topicData['name'] != null
                            ? topicData['name']
                            : 'Topic ${topic['step_number']}';
                    return {
                      'user_path_id': userPathId,
                      'day': topic['step_number'],
                      'topic': topicName,
                      'challenge_type': 'quiz',
                      'title': topicName,
                      'description': topic['description'] ?? '',
                      'completed': false,
                    };
                  }).toList();

                  await SupabaseService.client
                      .from('user_path_challenges')
                      .insert(challengesToInsert);

                  debugPrint(
                      '[LearningPathSelection] Created ${challengesToInsert.length} challenges for user path');
                }

                final pathId = path['id'];

                if (pathId == null) {
                  throw Exception(
                      'Path ID is null - cannot query learning path');
                }

                final learningPathResults = await SupabaseService.client
                    .from('learning_paths')
                    .select('id, name, description, is_active')
                    .eq('id', pathId);

                if (learningPathResults.isEmpty) {
                  throw Exception('Learning path not found');
                }

                if (learningPathResults.length > 1) {
                  debugPrint(
                      '[LearningPathSelection] WARNING: Multiple paths found (${learningPathResults.length}) for id ${path['id']}, using first');
                }

                final learningPath = learningPathResults.first;
                if (learningPath != null) {
                  ref.read(userPathProvider.notifier).state = {
                    ...learningPath,
                    'current_step': 1,
                    'user_path_id': userPathId,
                  };
                  await SupabaseService.client.from('users').update({
                    'onboarding_complete': true,
                    'streak_goal': 7
                  }).eq('id', user['id']);
                  if (context.mounted) {
                    Navigator.of(context).pop(true);
                  }
                }
              } catch (e) {
                debugPrint('Error setting learning path: $e');
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                          'Failed to set learning path. Please try again.'),
                    ),
                  );
                }
              }
            } else {
              ref.read(userPathProvider.notifier).state = null;
              await SupabaseService.client
                  .from('users')
                  .update({'onboarding_complete': true, 'streak_goal': 7}).eq(
                      'id', user['id']);
              if (context.mounted) {
                Navigator.of(context).pop(false);
              }
            }
          },
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: Theme.of(context).colorScheme.outline,
                width: 2,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceVariant,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        _getPathIcon(pathName),
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            pathName,
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            pathDescription,
                            style: Theme.of(context).textTheme.bodyMedium,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios,
                      color: Theme.of(context).colorScheme.onSurface,
                      size: 20,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCustomPathCard(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const CustomPathOnboardingScreen(),
              ),
            );
          },
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: Theme.of(context).colorScheme.outline,
                width: 2,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.auto_awesome,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Create Custom AI Path',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Let AI build a personalized learning journey just for you',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  color: Theme.of(context).colorScheme.onSurface,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFreeModeCard(BuildContext context, WidgetRef ref, dynamic user) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () async {
            if (user == null) return;
            try {
              ref.read(userPathProvider.notifier).state = null;
              await SupabaseService.client
                  .from('users')
                  .update({'onboarding_complete': true, 'streak_goal': 7}).eq(
                      'id', user['id']);
              if (context.mounted) {
                Navigator.of(context).pop(false);
              }
            } catch (e) {
              debugPrint("Error setting free mode during onboarding: $e");
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Failed to set free mode: $e")),
                );
              }
            }
          },
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: Theme.of(context).colorScheme.outline,
                width: 2,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.explore_outlined,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Free Mode',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Explore topics at your own pace without a structured path',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  color: Theme.of(context).colorScheme.onSurface,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
