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
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pathsAsync = ref.watch(learningPathsProvider);
    final user = ref.watch(userProvider).value;
    return Scaffold(
      appBar: AppBar(title: const Text('Choose Your Learning Path')),
      body: pathsAsync.when(
        data: (paths) => ListView(
          children: [
            ...paths.map((path) => ListTile(
                  title: Text(path['name'] ?? ''),
                  subtitle: Text(path['description'] ?? ''),
                  onTap: () async {
                    if (user == null) return;
                    if (path['id'] != null) {
                      try {
                        final existingPath = await SupabaseService.client
                            .from('user_learning_paths')
                            .select('id, path_id, current_step')
                            .eq('user_id', user['id'])
                            .is_('completed_at', null)
                            .maybeSingle();
                        String? userPathId;
                        if (existingPath != null) {
                          if (existingPath['path_id'] == path['id']) {
                            final learningPath = await SupabaseService.client
                                .from('learning_paths')
                                .select('id, name, description, is_active')
                                .eq('id', path['id'])
                                .single();
                            if (learningPath != null) {
                              userPathId = existingPath['id'];
                              ref.read(userPathProvider.notifier).state = {
                                ...learningPath,
                                'current_step':
                                    existingPath['current_step'] ?? 1,
                                'user_path_id': userPathId,
                              };
                              await SupabaseService.client
                                  .from('users')
                                  .update({
                                    'onboarding_complete': true,
                                    'streak_goal': 7
                                  }).eq('id', user['id']);
                              if (context.mounted) {
                                Navigator.of(context).pop(true);
                              }
                            }
                            return;
                          }
                          final updateResult = await SupabaseService.client
                              .from('user_learning_paths')
                              .update({
                                'path_id': path['id'],
                                'current_step': 1,
                                'started_at': DateTime.now().toIso8601String(),
                                'completed_at': null,
                                'is_complete': false,
                              })
                              .eq('id', existingPath['id'])
                              .select('id')
                              .single();
                          if (updateResult != null) {
                            userPathId = updateResult['id'];
                          }
                        } else {
                          final newPathResult = await SupabaseService.client
                              .from('user_learning_paths')
                              .insert({
                                'user_id': user['id'],
                                'path_id': path['id'],
                                'current_step': 1,
                                'started_at': DateTime.now().toIso8601String(),
                                'completed_at': null,
                                'is_complete': false,
                              })
                              .select('id')
                              .single();
                          if (newPathResult == null) {
                            throw Exception('Failed to create new path');
                          }
                          userPathId = newPathResult['id'];
                        }
                        if (userPathId == null) {
                          throw Exception('Failed to get user path ID');
                        }
                        final learningPath = await SupabaseService.client
                            .from('learning_paths')
                            .select('id, name, description, is_active')
                            .eq('id', path['id'])
                            .single();
                        if (learningPath != null) {
                          ref.read(userPathProvider.notifier).state = {
                            ...learningPath,
                            'current_step': 1,
                            'user_path_id': userPathId,
                          };
                          await SupabaseService.client
                              .from('users')
                              .update({
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
                      await SupabaseService.client.from('users').update({
                        'onboarding_complete': true,
                        'streak_goal': 7
                      }).eq('id', user['id']);
                      if (context.mounted) {
                        Navigator.of(context).pop(false);
                      }
                    }
                  },
                )),
            ListTile(
              title: const Text('Create Custom AI Path'),
              leading: const Icon(Icons.auto_awesome),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const CustomPathOnboardingScreen()),
                );
              },
            ),
            ListTile(
              title: const Text('N/A (Free Mode)'),
              leading: const Icon(Icons.clear),
              onTap: () async {
                if (user == null) return;
                try {
                  ref.read(userPathProvider.notifier).state = null;
                  await SupabaseService.client.from('users').update({
                    'onboarding_complete': true,
                    'streak_goal': 7
                  }).eq('id', user['id']);
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
            ),
          ],
        ),
        loading: () => Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}
