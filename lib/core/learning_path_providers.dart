import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neurobits/services/supabase.dart';
import 'package:neurobits/core/providers.dart';
import 'package:flutter/foundation.dart';

final userPathProvider = StateProvider<Map<String, dynamic>?>((ref) {
  return null;
});
final userPathDataProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final userAsync = ref.watch(userProvider);
  return await userAsync.when(
    data: (user) async {
      if (user == null) return null;
      try {
        final path = await ref.watch(activeLearningPathProvider(user['id']).future);
        if (path != null) {
          ref.read(userPathProvider.notifier).state = path;
        }
        return path;
      } catch (e) {
        debugPrint('Error in userPathDataProvider: $e');
        return null;
      }
    },
    loading: () => null,
    error: (_, __) => null,
  );
});
final currentChallengeProvider =
    FutureProvider<Map<String, dynamic>?>((ref) async {
  final userPath = ref.watch(userPathProvider);
  if (userPath == null) return null;
  final currentStep = userPath['current_step'] ?? 1;
  final topics = userPath['topics'] as List<dynamic>?;
  if (topics == null || topics.isEmpty) return null;
  final currentTopic = topics.firstWhere(
    (t) => t['step_number'] == currentStep,
    orElse: () => null,
  );
  return currentTopic;
});
final roadmapProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final userPath = ref.watch(userPathProvider);
  if (userPath == null) return [];
  final topics = userPath['topics'] as List<dynamic>?;
  if (topics == null) return [];
  return List<Map<String, dynamic>>.from(topics);
});
void initializeUserPathProvider(WidgetRef ref) {
  final userAsync = ref.watch(userProvider);

  userAsync.whenData((user) {
    if (user == null) return;

    ref.read(userPathDataProvider.future).then((path) {
      if (path != null) {
        ref.read(userPathProvider.notifier).state = path;
      }
    });

    ref.listen(activeLearningPathProvider(user['id']), (previous, next) {
      next.whenData((path) {
        if (path != null) {
          final currentPath = ref.read(userPathProvider);
          if (currentPath == null || currentPath['id'] != path['id']) {
            ref.read(userPathProvider.notifier).state = path;
          }
        }
      });
    });
  });
}

final isPathLoadingProvider = StateProvider<bool>((ref) => false);
final initializePathProvider =
    FutureProvider<Map<String, dynamic>?>((ref) async {
  final userAsync = ref.watch(userProvider);
  return await userAsync.when(
    data: (user) async {
      if (user == null) return null;
      try {
        final path = await ref.read(activeLearningPathProvider(user['id']).future);
        return path;
      } catch (e) {
        debugPrint('Error initializing path: $e');
        return null;
      }
    },
    loading: () => null,
    error: (_, __) => null,
  );
});
final completedPathsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
        (ref, userId) async {
  try {
    final completedPaths = await SupabaseService.client
        .from('user_learning_paths')
        .select('''
          id,
          path_id,
          current_step,
          started_at,
          completed_at,
          learning_paths (
            id,
            name,
            description,
            is_active
          )
        ''')
        .eq('user_id', userId)
        .not('completed_at', 'is', null)
        .order('completed_at', ascending: false);
    return List<Map<String, dynamic>>.from(completedPaths);
  } catch (e) {
    debugPrint('Error fetching completed paths: $e');
    return [];
  }
});
final activeLearningPathProvider =
    FutureProvider.family<Map<String, dynamic>?, String>((ref, userId) async {
  try {
    final userPath = await SupabaseService.client
        .from('user_learning_paths')
        .select(
            'id, path_id, current_step, started_at, completed_at, is_complete, duration_days, daily_minutes, level, ai_path_json')
        .eq('user_id', userId)
        .is_('completed_at', null)
        .maybeSingle();
    if (userPath == null) return null;
    final learningPath = await SupabaseService.client
        .from('learning_paths')
        .select('id, name, description, is_active')
        .eq('id', userPath['path_id'])
        .single();
    if (learningPath == null) return null;
    final pathTopics = await SupabaseService.client
        .from('learning_path_topics')
        .select('*, topics(name)')
        .eq('path_id', learningPath['id'])
        .order('step_number', ascending: true);
    final pathChallenges = await SupabaseService.client
        .from('user_path_challenges')
        .select('*')
        .eq('user_path_id', userPath['id'])
        .order('day', ascending: true);
    final Map<String, dynamic>? metadata =
        userPath['ai_path_json'] as Map<String, dynamic>?;
    return {
      'id': learningPath['id'],
      'name': learningPath['name'],
      'description': learningPath['description'],
      'is_active': learningPath['is_active'],
      'current_step': userPath['current_step'] ?? 1,
      'user_path_id': userPath['id'],
      'started_at': userPath['started_at'],
      'completed_at': userPath['completed_at'],
      'is_complete': userPath['is_complete'] ?? false,
      'duration_days': userPath['duration_days'] as int? ?? 0,
      'daily_minutes': userPath['daily_minutes'] as int? ?? 0,
      'level': userPath['level'] as String? ?? '',
      'ai_path_json': userPath['ai_path_json'] as Map<String, dynamic>?,
      'topics': pathTopics,
      'challenges': pathChallenges,
      'metadata': metadata,
      'total_steps': pathTopics.length,
    };
  } catch (e) {
    debugPrint('Error fetching active learning path: $e');
    return null;
  }
});
final userPathChallengesProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
        (ref, userPathId) async {
  try {
    final res = await SupabaseService.client
        .from('user_path_challenges')
        .select('*')
        .eq('user_path_id', userPathId)
        .order('day', ascending: true);
    return List<Map<String, dynamic>>.from(res);
  } catch (e) {
    debugPrint('Error fetching path challenges: $e');
    return [];
  }
});
