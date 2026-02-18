import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers.dart';
import 'package:neurobits/services/convex_client_service.dart';
import '../../core/learning_path_providers.dart';
import 'custom_path_onboarding_screen.dart';

final learningPathsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final pathRepo = ref.read(pathRepositoryProvider);
  final selectableResult = await pathRepo.listSelectable();
  return selectableResult.map((entry) {
    final path = entry['path'] as Map<String, dynamic>? ?? {};
    return {
      'id': path['_id'],
      'name': path['name'] ?? 'Learning Path',
      'description': path['description'] ?? 'No description available',
    };
  }).toList();
});

final incompletePathsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final pathRepo = ref.read(pathRepositoryProvider);
  return await pathRepo.listIncomplete();
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
    final incompleteAsync = ref.watch(incompletePathsProvider);
    final templatesAsync = ref.watch(learningPathsProvider);
    final userAsync = ref.watch(userProvider);
    final activePathAsync = ref.watch(activeLearningPathProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Choose Your Learning Path'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: userAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (user) {
          if (user == null) {
            return const Center(child: Text('Not logged in'));
          }
          final userId = user['_id']?.toString() ?? user['id']?.toString();
          final activePath = activePathAsync.value;
          final isInPath = activePath != null;
          final activeUserPathId = activePath?['user_path_id']?.toString();
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Select a structured learning path to guide your journey',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.grey.shade700,
                    ),
              ),
              const SizedBox(height: 16),
              incompleteAsync.when(
                data: (paths) {
                  final filtered = paths.where((entry) {
                    final userPath =
                        entry['userPath'] as Map<String, dynamic>? ?? {};
                    final userPathId = userPath['_id']?.toString() ??
                        entry['user_path_id']?.toString();
                    return userPathId != null && userPathId != activeUserPathId;
                  }).toList();

                  if (filtered.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionTitle(context, 'Your Paths'),
                      const SizedBox(height: 8),
                      Column(
                        children: filtered
                            .map((entry) => _buildUserPathCard(
                                  context,
                                  ref,
                                  user,
                                  entry,
                                  isCompleted: false,
                                  activeUserPathId: activeUserPathId,
                                ))
                            .toList(),
                      ),
                      const SizedBox(height: 16),
                    ],
                  );
                },
                loading: () => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    SizedBox(height: 8),
                    Center(
                      child: Padding(
                        padding: EdgeInsets.all(8),
                        child: CircularProgressIndicator(),
                      ),
                    ),
                    SizedBox(height: 16),
                  ],
                ),
                error: (_, __) => const SizedBox.shrink(),
              ),
              templatesAsync.when(
                data: (paths) {
                  if (paths.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionTitle(context, 'Templates'),
                      const SizedBox(height: 8),
                      Column(
                        children: paths
                            .map((path) => _buildPathCard(
                                  context,
                                  ref,
                                  user,
                                  path,
                                ))
                            .toList(),
                      ),
                      const SizedBox(height: 16),
                    ],
                  );
                },
                loading: () => const Center(
                    child: Padding(
                        padding: EdgeInsets.all(8),
                        child: CircularProgressIndicator())),
                error: (_, __) => const SizedBox.shrink(),
              ),
              _sectionTitle(context, 'Create New'),
              const SizedBox(height: 8),
              _buildCustomPathCard(context),
              const SizedBox(height: 16),
              if (userId != null)
                ref.watch(completedPathsProvider(userId)).when(
                      data: (paths) {
                        if (paths.isEmpty) {
                          return const SizedBox.shrink();
                        }
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _sectionTitle(context, 'Completed'),
                            const SizedBox(height: 8),
                            Column(
                              children: paths
                                  .map((entry) => _buildUserPathCard(
                                        context,
                                        ref,
                                        user,
                                        entry,
                                        isCompleted: true,
                                        activeUserPathId: activeUserPathId,
                                      ))
                                  .toList(),
                            ),
                            const SizedBox(height: 8),
                          ],
                        );
                      },
                      loading: () => const Center(
                          child: Padding(
                              padding: EdgeInsets.all(8),
                              child: CircularProgressIndicator())),
                      error: (_, __) => const SizedBox.shrink(),
                    ),
              if (isInPath) _buildFreeModeCard(context, ref, user),
            ],
          );
        },
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
    );
  }

  Widget _emptyHint(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(text, style: const TextStyle(color: Colors.grey)),
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
            final pathId = path['id'] as String?;
            if (pathId == null) {
              ref.read(userPathProvider.notifier).state = null;
              final userRepo = ref.read(userRepositoryProvider);
              await userRepo.completeOnboarding();
              if (context.mounted) {
                Navigator.of(context).pop(false);
              }
              return;
            }
            try {
              final pathRepo = ref.read(pathRepositoryProvider);
              await pathRepo.selectTemplatePath(pathId: pathId);

              final userRepo = ref.read(userRepositoryProvider);
              await userRepo.completeOnboarding();

              ref.invalidate(activeLearningPathProvider);
              final activePath =
                  await ref.read(activeLearningPathProvider.future);
              if (activePath != null) {
                ref.read(userPathProvider.notifier).state = activePath;
              }

              if (context.mounted) {
                Navigator.of(context).pop(true);
              }
            } catch (e) {
              debugPrint('Error setting learning path: $e');
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content:
                        Text('Failed to set learning path. Please try again.'),
                  ),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
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

  Widget _buildUserPathCard(
    BuildContext context,
    WidgetRef ref,
    dynamic user,
    Map<String, dynamic> entry, {
    required bool isCompleted,
    String? activeUserPathId,
  }) {
    final userPath = entry['userPath'] as Map<String, dynamic>? ?? {};
    final userPathId =
        userPath['_id']?.toString() ?? entry['user_path_id']?.toString();
    final pathId =
        userPath['pathId']?.toString() ?? entry['path_id']?.toString();
    final name = entry['pathName'] ?? entry['name'] ?? 'Learning Path';
    final description = entry['pathDescription'] ?? entry['description'] ?? '';
    final progress = entry['progress'] as Map<String, dynamic>?;
    final isCurrent =
        activeUserPathId != null && userPathId == activeUserPathId;

    final bool isCustom = (userPath['isCustom'] ?? entry['is_custom']) == true;
    final String? aiPathJson =
        userPath['aiPathJson']?.toString() ?? entry['ai_path_json']?.toString();
    final int durationDays = (userPath['durationDays'] as num?)?.toInt() ??
        (entry['duration_days'] as num?)?.toInt() ??
        7;
    final int dailyMinutes = (userPath['dailyMinutes'] as num?)?.toInt() ??
        (entry['daily_minutes'] as num?)?.toInt() ??
        10;
    final String level = userPath['level']?.toString() ??
        entry['level']?.toString() ??
        'Intermediate';

    return Opacity(
      opacity: isCompleted ? 0.6 : 1.0,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: isCompleted
                ? null
                : () async {
                    if (user == null || userPathId == null) return;
                    if (isCurrent) {
                      Navigator.of(context).pop(true);
                      return;
                    }
                    try {
                      final pathRepo = ref.read(pathRepositoryProvider);
                      await pathRepo.setActivePath(userPathId: userPathId);
                      ref.invalidate(activeLearningPathProvider);
                      ref.invalidate(userPathDataProvider);
                      final activePath =
                          await ref.read(activeLearningPathProvider.future);
                      if (activePath != null) {
                        ref.read(userPathProvider.notifier).state = activePath;
                      }
                      if (context.mounted) {
                        Navigator.of(context).pop(true);
                      }
                    } catch (e) {
                      debugPrint('Error switching path: $e');
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Failed to switch path.'),
                          ),
                        );
                      }
                    }
                  },
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: isCurrent
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.outline,
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              description,
                              style: Theme.of(context).textTheme.bodyMedium,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      if (isCurrent)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .primary
                                .withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Current',
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                          ),
                        ),
                    ],
                  ),
                  if (!isCompleted && progress != null) ...[
                    const SizedBox(height: 12),
                    LinearProgressIndicator(
                      value: (progress['percentComplete'] as num?) != null
                          ? (progress['percentComplete'] as num).toDouble() /
                              100
                          : 0,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Progress: ${convexInt(progress['completedDays'])}/${convexInt(progress['totalDays'])}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                  if (isCompleted) ...[
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () async {
                          if (user == null) return;
                          try {
                            final pathRepo = ref.read(pathRepositoryProvider);
                            if (isCustom && aiPathJson != null) {
                              await pathRepo.createCustomPathFromAi(
                                topic: name.toString(),
                                level: level,
                                durationDays: durationDays,
                                dailyMinutes: dailyMinutes,
                                aiPathJson: aiPathJson,
                                pathDescription: description,
                              );
                            } else if (pathId != null) {
                              await pathRepo.selectTemplatePath(pathId: pathId);
                            } else {
                              throw Exception('Unable to restart this path');
                            }

                            ref.invalidate(activeLearningPathProvider);
                            final activePath = await ref
                                .read(activeLearningPathProvider.future);
                            if (activePath != null) {
                              ref.read(userPathProvider.notifier).state =
                                  activePath;
                            }
                            if (context.mounted) {
                              Navigator.of(context).pop(true);
                            }
                          } catch (e) {
                            debugPrint('Error restarting path: $e');
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Failed to restart path.'),
                                ),
                              );
                            }
                          }
                        },
                        child: const Text('Restart'),
                      ),
                    ),
                  ],
                ],
              ),
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
          onTap: () async {
            final bool? created = await Navigator.push<bool?>(
              context,
              MaterialPageRoute(
                builder: (_) => const CustomPathOnboardingScreen(),
              ),
            );
            if (created == true && context.mounted) {
              Navigator.of(context).pop(true);
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
                    color:
                        Theme.of(context).colorScheme.surfaceContainerHighest,
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
              final pathRepo = ref.read(pathRepositoryProvider);
              await pathRepo.selectFreeMode();
              ref.read(userPathProvider.notifier).state = null;
              ref.invalidate(activeLearningPathProvider);
              ref.invalidate(userPathDataProvider);
              await ref.refresh(activeLearningPathProvider.future);
              ref.read(userPathProvider.notifier).state = null;
              final userRepo = ref.read(userRepositoryProvider);
              await userRepo.completeOnboarding();
              if (context.mounted) {
                Navigator.of(context).pop(true);
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
                    color:
                        Theme.of(context).colorScheme.surfaceContainerHighest,
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
