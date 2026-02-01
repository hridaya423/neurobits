import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neurobits/services/supabase.dart';
import 'package:neurobits/services/ai_service.dart';
import 'package:neurobits/services/user_analytics_service.dart';
import 'package:neurobits/core/learning_path_providers.dart';


final challengeFilterDifficultyProvider = StateProvider<String?>((ref) => null);
final challengeFilterTypeProvider = StateProvider<String?>((ref) => null);
final challengeSortOrderProvider =
    StateProvider<String>((ref) => 'difficulty_asc');
final challengesProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final userPath = ref.watch(userPathProvider);
  if (userPath != null && userPath['id'] != null) {
    final pathChallenges = await SupabaseService.client
        .from('user_path_challenges')
        .select('*')
        .eq('user_path_id', userPath['id'])
        .order('day');
    return List<Map<String, dynamic>>.from(pathChallenges);
  } else {
    final challenges = await SupabaseService.client
        .from('challenges')
        .select('*')
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(challenges);
  }
});
final challengeProvider = FutureProvider.family<Map<String, dynamic>, String>(
  (ref, id) async {
    final response = await SupabaseService.client
        .from('challenges')
        .select('*')
        .eq('id', id)
        .single();
    return Map<String, dynamic>.from(response);
  },
);
final categoryChallengesProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
  (ref, categoryId) async {
    final response = await SupabaseService.client
        .from('challenges')
        .select('*')
        .eq('category_id', categoryId)
        .order('difficulty', ascending: true)
        .limit(10);
    return List<Map<String, dynamic>>.from(response);
  },
);
final aiQuestionsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, Map<String, dynamic>>(
  (ref, params) async {
    final topic = params['topic'] as String? ?? 'General Knowledge';
    final difficulty = params['difficulty'] as String? ?? 'Medium';
    final count = params['count'] as int? ?? 5;
    return await AIService.generateQuestions(topic, difficulty, count: count);
  },
);
final trendingTopicsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return await SupabaseService.getTrendingTopics(limit: 5);
});

final personalizedRecommendationsProvider =
    FutureProvider<List<PersonalizedRecommendation>>((ref) async {
  final user = SupabaseService.client.auth.currentUser;
  if (user == null) {
    return [];
  }

  return await UserAnalyticsService.getPersonalizedRecommendations(
    userId: user.id,
    limit: 12,
  );
});
final trendingChallengesProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  try {
    debugPrint('Fetching trending challenges...');
    final challenges =
        await SupabaseService.client.from('challenges').select('''
        id,
        title,
        difficulty,
        type,
        question,
        estimated_time_seconds,
        solve_count,
        created_at
      ''').order('created_at', ascending: false).limit(10);
    debugPrint('Trending challenges fetched: ${challenges.length}');
    return List<Map<String, dynamic>>.from(challenges);
  } catch (e, stackTrace) {
    debugPrint('Error fetching trending challenges: $e');
    debugPrint('Stack trace: $stackTrace');
    debugPrint('Error type: ${e.runtimeType}');
    rethrow;
  }
});
final mostSolvedChallengesProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  try {
    debugPrint('Fetching most solved challenges...');
    final challenges =
        await SupabaseService.client.from('challenges').select('''
        id,
        title,
        difficulty,
        type,
        question,
        estimated_time_seconds,
        solve_count,
        created_at
      ''').order('solve_count', ascending: false).limit(10);
    debugPrint('Most solved challenges fetched: ${challenges.length}');
    return List<Map<String, dynamic>>.from(challenges);
  } catch (e, stackTrace) {
    debugPrint('Error fetching most solved challenges: $e');
    debugPrint('Stack trace: $stackTrace');
    debugPrint('Error type: ${e.runtimeType}');
    rethrow;
  }
});
final userProvider = StreamProvider<Map<String, dynamic>?>((ref) async* {
  bool isCreatingUser = false;

  Future<Map<String, dynamic>?> fetchUserData(String userId) async {
    const maxRetries = 3;
    int retryCount = 0;
    while (retryCount < maxRetries) {
      try {
        debugPrint('[fetchUserData] Attempt ${retryCount + 1} for user: $userId');
        var userData = await SupabaseService.client
            .from('users')
            .select('*')
            .eq('id', userId)
            .maybeSingle();
        if (userData == null) {
          debugPrint('[fetchUserData] User data NOT found for $userId, attempting to create...');
          final userEmail = SupabaseService.client.auth.currentUser?.email;
          if (userEmail != null) {
            final Map<String, dynamic> defaultUserData = {
              'id': userId,
              'email': userEmail,
              'points': 0,
              'xp': 0,
              'level': 1,
              'streak_goal': 7,
              'current_streak': 0,
              'longest_streak': 0,
              'adaptive_difficulty': false,
              'reminders_enabled': false,
              'streak_notifications': false,
              'onboarding_complete': false,
              'adaptive_difficulty_enabled': true,
            };
            try {
              if (isCreatingUser) {
                await Future.delayed(const Duration(milliseconds: 200));
                continue;
              }
              isCreatingUser = true;
              final existing = await SupabaseService.client
                  .from('users')
                  .select('id')
                  .eq('id', userId)
                  .maybeSingle();
              if (existing != null) {
                isCreatingUser = false;
                final fullUser = await SupabaseService.client
                    .from('users')
                    .select('*')
                    .eq('id', userId)
                    .maybeSingle();
                return fullUser ?? existing;
              }
              final upsertResponse = await SupabaseService.client
                  .from('users')
                  .upsert(defaultUserData, onConflict: 'id')
                  .select()
                  .maybeSingle();
              isCreatingUser = false;
              if (upsertResponse != null) {
                debugPrint('[fetchUserData] Successfully CREATED user data via upsert for $userId');
                return upsertResponse;
              }
              return defaultUserData;
            } catch (e) {
              isCreatingUser = false;
              debugPrint('[fetchUserData] Error during user creation: $e');
              retryCount++;
              if (retryCount == maxRetries) rethrow;
              await Future.delayed(Duration(seconds: 1 * retryCount));
              continue;
            }
          }
          return null;
        }
        return userData;
      } catch (e) {
        debugPrint('[fetchUserData] Error fetching user data: $e');
        retryCount++;
        if (retryCount == maxRetries) rethrow;
        await Future.delayed(Duration(seconds: 1 * retryCount));
      }
    }
    return null;
  }


  final initialUser = SupabaseService.client.auth.currentUser;

  yield null;

  if (initialUser != null) {
    final userData = await fetchUserData(initialUser.id);
    yield userData;
  }

  await for (final event in SupabaseService.client.auth.onAuthStateChange) {
    final user = event.session?.user;
    if (user != null) {
      final userData = await fetchUserData(user.id);
      yield userData;
    } else {
      yield null;
    }
  }
});
final userStatsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final userAsyncValue = ref.watch(userProvider);
  final defaultStats = {
    'challenges_attempted': 0,
    'challenges_solved': 0,
    'average_accuracy': 0.0,
    'points': 0,
    'level': 1,
    'xp': 0,
    'xp_needed': 100,
    'completed_quizzes': 0,
    'current_streak': 0,
    'longest_streak': 0,
    'joined': null,
  };
  return await userAsyncValue.when(
    data: (user) async {
      if (user == null || user['id'] == null) {
        return defaultStats;
      }
      try {
        final stats = await SupabaseService.getUserStats(user['id']);
        return stats;
      } catch (e) {
        debugPrint('Error fetching user stats: $e');
        return defaultStats;
      }
    },
    loading: () => defaultStats,
    error: (error, stackTrace) {
      debugPrint('Error in userProvider affecting userStatsProvider: $error');
      return defaultStats;
    },
  );
});
final userPreferencesProvider =
    FutureProvider<Map<String, dynamic>?>((ref) async {
  final user = ref.watch(userProvider).value;
  if (user == null) return null;
  final res = await SupabaseService.client
      .from('user_quiz_preferences')
      .select('*')
      .eq('user_id', user['id'])
      .maybeSingle();
  return res as Map<String, dynamic>?;
});
