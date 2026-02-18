import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neurobits/services/auth_service.dart';
import 'package:neurobits/services/convex_client_service.dart';
import 'package:neurobits/services/ai_service.dart';
import 'package:neurobits/repositories/user_repository.dart';
import 'package:neurobits/repositories/challenge_repository.dart';
import 'package:neurobits/repositories/topic_repository.dart';
import 'package:neurobits/repositories/preference_repository.dart';
import 'package:neurobits/repositories/progress_repository.dart';
import 'package:neurobits/repositories/path_repository.dart';
import 'package:neurobits/repositories/badge_repository.dart';
import 'package:neurobits/repositories/session_analysis_repository.dart';
import 'package:neurobits/repositories/analytics_repository.dart';
import 'package:neurobits/repositories/recommendation_repository.dart';
import 'package:neurobits/core/learning_path_providers.dart';

final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepository(ConvexClientService.instance);
});

final challengeRepositoryProvider = Provider<ChallengeRepository>((ref) {
  return ChallengeRepository(ConvexClientService.instance);
});

final topicRepositoryProvider = Provider<TopicRepository>((ref) {
  return TopicRepository(ConvexClientService.instance);
});

final preferenceRepositoryProvider = Provider<PreferenceRepository>((ref) {
  return PreferenceRepository(ConvexClientService.instance);
});

final progressRepositoryProvider = Provider<ProgressRepository>((ref) {
  return ProgressRepository(ConvexClientService.instance);
});

final pathRepositoryProvider = Provider<PathRepository>((ref) {
  return PathRepository(ConvexClientService.instance);
});

final badgeRepositoryProvider = Provider<BadgeRepository>((ref) {
  return BadgeRepository(ConvexClientService.instance);
});

final sessionAnalysisRepositoryProvider =
    Provider<SessionAnalysisRepository>((ref) {
  return SessionAnalysisRepository(ConvexClientService.instance);
});

final analyticsRepositoryProvider = Provider<AnalyticsRepository>((ref) {
  return AnalyticsRepository(ConvexClientService.instance);
});

final pendingRecommendationsRefreshProvider =
    StateProvider<bool>((ref) => false);

final recommendationRepositoryProvider =
    Provider<RecommendationRepository>((ref) {
  return RecommendationRepository(ConvexClientService.instance);
});

const List<String> _defaultFallbackTopics = [
  'Python Fundamentals',
  'JavaScript Basics',
  'SQL Basics',
  'Data Structures',
  'Algebra',
  'Statistics',
  'Biology',
  'World History',
];

List<String> _takeUniqueTopics(List<String> topics, int limit,
    {Set<String>? excludeLower}) {
  final seen = <String>{};
  final results = <String>[];
  for (final raw in topics) {
    final name = raw.trim();
    if (name.isEmpty) continue;
    final key = name.toLowerCase();
    if (seen.contains(key)) continue;
    if (excludeLower != null && excludeLower.contains(key)) continue;
    seen.add(key);
    results.add(name);
    if (results.length >= limit) break;
  }
  return results;
}

List<Map<String, dynamic>> _buildFallbackPracticeList(
  List<String> topics,
  String reason, {
  int limit = 8,
  Set<String>? excludeLower,
}) {
  final picked = _takeUniqueTopics(topics, limit, excludeLower: excludeLower);
  return picked
      .map((t) => <String, dynamic>{
            'topicName': t,
            'accuracy': null,
            'attempts': null,
            'lastAttemptedAt': null,
            'reason': reason,
          })
      .toList();
}

List<Map<String, dynamic>> _buildFallbackSuggestionList(
  List<String> topics,
  String reason, {
  int limit = 5,
  Set<String>? excludeLower,
}) {
  final picked = _takeUniqueTopics(topics, limit, excludeLower: excludeLower);
  return picked
      .map((t) => <String, dynamic>{
            'name': t,
            'reason': reason,
            'relatedTopics': <String>[],
          })
      .toList();
}

final challengeFilterDifficultyProvider = StateProvider<String?>((ref) => null);
final challengeFilterTypeProvider = StateProvider<String?>((ref) => null);
final challengeSortOrderProvider =
    StateProvider<String>((ref) => 'difficulty_asc');

final challengesProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final userPath = ref.watch(userPathProvider);
  if (userPath != null && userPath['id'] != null) {
    final pathRepo = ref.read(pathRepositoryProvider);
    final userPathId = userPath['user_path_id'] as String?;
    if (userPathId != null) {
      return await pathRepo.listChallengesForPath(userPathId: userPathId);
    }
  }
  final challengeRepo = ref.read(challengeRepositoryProvider);
  return await challengeRepo.listRecent();
});

final challengeProvider = FutureProvider.family<Map<String, dynamic>?, String>(
  (ref, id) async {
    final challengeRepo = ref.read(challengeRepositoryProvider);
    return await challengeRepo.getById(id);
  },
);

final categoryChallengesProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
  (ref, categoryId) async {
    final challengeRepo = ref.read(challengeRepositoryProvider);
    return await challengeRepo.listByCategory(
        categoryId: categoryId, limit: 10);
  },
);

final aiQuestionsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, Map<String, dynamic>>(
  (ref, params) async {
    final topic = params['topic'] as String? ?? 'General Knowledge';
    final difficulty = params['difficulty'] as String? ?? 'Medium';
    final count = params['count'] is num ? (params['count'] as num).toInt() : 5;
    return await AIService.generateQuestions(topic, difficulty, count: count);
  },
);

final userProvider = StreamProvider<Map<String, dynamic>?>((ref) async* {
  final userRepo = ref.read(userRepositoryProvider);
  const bootstrapTimeout = Duration(seconds: 15);

  Future<Map<String, dynamic>?> fetchCurrentUser() async {
    try {
      final existing = await userRepo.getMe().timeout(bootstrapTimeout);
      if (existing != null) return existing;
    } catch (e) {
      debugPrint('[userProvider] getMe before ensureCurrent failed: $e');
    }

    await ConvexClientService.instance.mutation(
        name: 'users:ensureCurrent', args: {}).timeout(bootstrapTimeout);
    return await userRepo.getMe().timeout(bootstrapTimeout);
  }

  yield null;

  if (AuthService.instance.currentStatus == AuthStatus.authenticated) {
    try {
      final userData = await fetchCurrentUser();
      yield userData;
    } catch (e) {
      debugPrint('[userProvider] Error fetching initial user data: $e');
      yield null;
    }
  }

  await for (final status in AuthService.instance.authStateChanges) {
    if (status == AuthStatus.authenticated) {
      try {
        final idToken = await AuthService.instance.getIdToken();
        if (idToken != null) {
          await ConvexClientService.instance.setAuthToken(idToken);
        }
        final userData = await fetchCurrentUser();
        yield userData;
      } catch (e) {
        debugPrint('[userProvider] Error fetching user data: $e');
        yield null;
      }
    } else {
      yield null;
    }
  }
});
final userStatsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final userAsyncValue = ref.watch(userProvider);
  final defaultStats = {
    'points': 0,
    'xp': 0,
    'level': 1,
    'currentStreak': 0,
    'longestStreak': 0,
    'totalAttempts': 0,
    'totalCompleted': 0,
    'avgAccuracy': 0.0,
  };
  return await userAsyncValue.when(
    data: (user) async {
      if (user == null) {
        return defaultStats;
      }
      try {
        final progressRepo = ref.read(progressRepositoryProvider);
        final stats = await progressRepo.getMyStats();
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
  final prefRepo = ref.read(preferenceRepositoryProvider);
  return await prefRepo.getMine();
});

final recommendationsCacheProvider =
    FutureProvider<Map<String, dynamic>?>((ref) async {
  final user = ref.watch(userProvider).value;
  if (user == null) return null;
  final recRepo = ref.read(recommendationRepositoryProvider);
  return await recRepo.getCached();
});

final practiceRecommendationsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final user = ref.watch(userProvider).value;
  if (user == null) return [];
  final activePath = await ref.watch(activeLearningPathProvider.future);
  if (activePath != null) return [];

  try {
    final analyticsRepo = ref.read(analyticsRepositoryProvider);
    final analytics = await analyticsRepo.getUserPerformanceVector();
    final topicBreakdown =
        (analytics['topicBreakdown'] as List<dynamic>?) ?? [];

    if (topicBreakdown.isEmpty) {
      final prefs = await ref.read(preferenceRepositoryProvider).getMine();
      final interested = prefs?['interestedTopics'];
      final topics = interested is List
          ? interested.map((t) => t.toString()).toList()
          : <String>[];
      if (topics.isNotEmpty) {
        return _buildFallbackPracticeList(topics, 'From your interests');
      }

      final topicRepo = ref.read(topicRepositoryProvider);
      final trending = await topicRepo.getTrending(limit: 8);
      if (trending.isNotEmpty) {
        final trendingNames =
            trending.map((t) => t['name']?.toString() ?? '').toList();
        return _buildFallbackPracticeList(trendingNames, 'Trending');
      }

      final allTopics = await topicRepo.listAll();
      final allTopicNames =
          allTopics.map((t) => t['name']?.toString() ?? '').toList();
      final fromAll =
          _buildFallbackPracticeList(allTopicNames, 'Explore a new topic');
      if (fromAll.isNotEmpty) return fromAll;

      return _buildFallbackPracticeList(
          _defaultFallbackTopics, 'Explore a new topic');
    }

    final sorted = List<Map<String, dynamic>>.from(
        topicBreakdown.map((e) => Map<String, dynamic>.from(e as Map)));
    sorted.sort((a, b) {
      final accA = (a['accuracy'] as num?)?.toDouble() ?? 1.0;
      final accB = (b['accuracy'] as num?)?.toDouble() ?? 1.0;
      final accCmp = accA.compareTo(accB);
      if (accCmp != 0) return accCmp;
      final lastA = (a['lastAttemptedAt'] as num?)?.toDouble() ?? 0;
      final lastB = (b['lastAttemptedAt'] as num?)?.toDouble() ?? 0;
      return lastA.compareTo(lastB);
    });

    final results = sorted.map((t) {
      final acc = (t['accuracy'] as num?)?.toDouble();
      final pct = acc != null ? (acc * 100).round() : null;
      final attempts = (t['attempts'] as num?)?.toInt();
      final lastAttemptedAt = (t['lastAttemptedAt'] as num?)?.toInt();
      return <String, dynamic>{
        'topicName': t['topicName'] ?? '',
        'accuracy': acc,
        'attempts': attempts,
        'lastAttemptedAt': lastAttemptedAt,
        'reason': pct != null ? '$pct% accuracy' : 'Needs practice',
      };
    }).toList();

    return results;
  } catch (e) {
    debugPrint('[practiceRecommendationsProvider] Error: $e');
    try {
      final prefs = await ref.read(preferenceRepositoryProvider).getMine();
      final interested = prefs?['interestedTopics'];
      final topics = interested is List
          ? interested.map((t) => t.toString()).toList()
          : <String>[];
      if (topics.isNotEmpty) {
        return _buildFallbackPracticeList(topics, 'From your interests');
      }
      final topicRepo = ref.read(topicRepositoryProvider);
      final trending = await topicRepo.getTrending(limit: 8);
      if (trending.isNotEmpty) {
        final trendingNames =
            trending.map((t) => t['name']?.toString() ?? '').toList();
        return _buildFallbackPracticeList(trendingNames, 'Trending');
      }
      final allTopics = await topicRepo.listAll();
      final allTopicNames =
          allTopics.map((t) => t['name']?.toString() ?? '').toList();
      final fromAll =
          _buildFallbackPracticeList(allTopicNames, 'Explore a new topic');
      if (fromAll.isNotEmpty) return fromAll;
      return _buildFallbackPracticeList(
          _defaultFallbackTopics, 'Explore a new topic');
    } catch (_) {
      return [];
    }
  }
});

final suggestedNewTopicsProvider = FutureProvider<List<String>>((ref) async {
  final user = ref.watch(userProvider).value;
  if (user == null) {
    return [];
  }

  try {
    final prefRepo = ref.read(preferenceRepositoryProvider);
    final topicRepo = ref.read(topicRepositoryProvider);
    final analyticsRepo = ref.read(analyticsRepositoryProvider);
    final pathRepo = ref.read(pathRepositoryProvider);

    final results = await Future.wait([
      prefRepo.getMine(),
      topicRepo.listAll(),
      analyticsRepo.getUserPerformanceVector(),
      pathRepo.getActive(),
    ]);

    final prefs = results[0] as Map<String, dynamic>?;
    final allTopics = results[1] as List<Map<String, dynamic>>;
    final analytics = results[2] as Map<String, dynamic>;
    final activePath = results[3] as Map<String, dynamic>?;

    final interested = prefs?['interestedTopics'];
    final interestedTopics = interested is List
        ? interested.map((t) => t.toString()).toList()
        : <String>[];

    final experienceLevel =
        (prefs?['experienceLevel'] as String?) ?? 'beginner';

    final topicBreakdown =
        (analytics['topicBreakdown'] as List<dynamic>?) ?? [];
    final practicedTopics = topicBreakdown
        .map((t) => (t as Map)['topicName']?.toString() ?? '')
        .where((n) => n.isNotEmpty)
        .toList();

    final allTopicNames = allTopics
        .map((t) => t['name']?.toString() ?? '')
        .where((n) => n.isNotEmpty)
        .toList();

    List<String> pathTopics = [];
    if (activePath != null) {
      final aiPathJsonStr = activePath['userPath']?['aiPathJson']?.toString();
      if (aiPathJsonStr != null && aiPathJsonStr.isNotEmpty) {
        try {
          final parsed = json.decode(aiPathJsonStr);
          if (parsed is Map && parsed['path'] is List) {
            pathTopics = (parsed['path'] as List)
                .whereType<Map>()
                .map((d) => d['topic']?.toString())
                .whereType<String>()
                .where((t) => t.isNotEmpty)
                .toList();
          }
        } catch (_) {}
      }
    }

    final suggestions = await AIService.suggestNewTopics(
      interestedTopics: interestedTopics,
      practicedTopics: practicedTopics,
      experienceLevel: experienceLevel,
      allAvailableTopics: allTopicNames,
      pathTopics: pathTopics,
      count: 5,
    );
    return suggestions;
  } catch (e) {
    debugPrint('[suggestedNewTopicsProvider] Error: $e');
    return [];
  }
});

final refreshPracticeProvider = StateProvider<bool>((ref) => false);

final enrichedPracticeProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final shouldRefresh = ref.watch(refreshPracticeProvider);
  final activePath = await ref.watch(activeLearningPathProvider.future);
  if (activePath != null) return [];
  final now = DateTime.now();

  if (!shouldRefresh && _cachedPractice != null) {
    return _cachedPractice!.recommendations;
  }

  if (!shouldRefresh) {
    final cached = await ref.watch(recommendationsCacheProvider.future);
    final cachedPractice = cached?['practiceRecs'];
    if (cachedPractice is List && cachedPractice.isNotEmpty) {
      final list = cachedPractice
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      final cachedNames = list
          .where((r) => r['topicName'] != null)
          .map((r) => r['topicName'].toString())
          .toList();
      cachedNames.sort();
      _cachedPractice = _PracticeCache(
        recommendations: list,
        fetchedAt: now,
        practicedTopicsHash: cachedNames.join(','),
      );
      return list;
    }
  }

  final practiceRecs = await ref.watch(practiceRecommendationsProvider.future);

  final topicNames = practiceRecs
      .where((r) => r['topicName'] != null)
      .map((r) => r['topicName'].toString())
      .toList();
  topicNames.sort();
  final topicsHash = topicNames.join(',');

  if (shouldRefresh) {
    Future.microtask(() {
      ref.read(refreshPracticeProvider.notifier).state = false;
    });
  }

  if (!shouldRefresh &&
      _cachedPractice != null &&
      _cachedPractice!.practicedTopicsHash == topicsHash) {
    return _cachedPractice!.recommendations;
  }

  final historyTopics =
      practiceRecs.where((r) => r['accuracy'] != null).toList();

  String experienceLevel = 'beginner';
  try {
    final prefs = await ref.read(preferenceRepositoryProvider).getMine();
    experienceLevel = (prefs?['experienceLevel'] as String?) ?? 'beginner';
  } catch (_) {}

  if (historyTopics.isEmpty) {
    final result = practiceRecs
        .take(3)
        .map((rec) => {
              ...rec,
              'isSuggested': true,
            })
        .toList();

    final prefs = await ref.read(preferenceRepositoryProvider).getMine();
    final prefsUpdatedAt = prefs?['updatedAt'] is num
        ? (prefs?['updatedAt'] as num).toInt()
        : null;
    final source = practiceRecs.isNotEmpty &&
            practiceRecs.every(
                (r) => (r['reason']?.toString() ?? '') == 'From your interests')
        ? 'onboarding'
        : 'fallback';
    final recRepo = ref.read(recommendationRepositoryProvider);
    try {
      await recRepo.upsertCached(
        practiceRecs: result,
        basedOnPreferencesUpdatedAt: prefsUpdatedAt,
        source: source,
      );
    } catch (e) {
      debugPrint('[enrichedPracticeProvider] Cache update failed: $e');
    }

    _cachedPractice = _PracticeCache(
      recommendations: result,
      fetchedAt: now,
      practicedTopicsHash: topicsHash,
    );

    return result;
  }

  final nowMs = DateTime.now().millisecondsSinceEpoch;
  final random = Random(nowMs % 1000);

  final sortedHistory = List<Map<String, dynamic>>.from(historyTopics);
  final sortMode = random.nextInt(4);

  switch (sortMode) {
    case 0:
      sortedHistory.sort((a, b) {
        final lastA =
            (a['lastAttemptedAt'] as num?)?.toDouble() ?? double.infinity;
        final lastB =
            (b['lastAttemptedAt'] as num?)?.toDouble() ?? double.infinity;
        final accA = (a['accuracy'] as num?)?.toDouble() ?? 1.0;
        final accB = (b['accuracy'] as num?)?.toDouble() ?? 1.0;
        final scoreA =
            (nowMs - lastA) / (1000 * 60 * 60 * 24) + (1 - accA) * 30;
        final scoreB =
            (nowMs - lastB) / (1000 * 60 * 60 * 24) + (1 - accB) * 30;
        return scoreB.compareTo(scoreA);
      });
      break;
    case 1:
      sortedHistory.sort((a, b) {
        final accA = (a['accuracy'] as num?)?.toDouble() ?? 1.0;
        final accB = (b['accuracy'] as num?)?.toDouble() ?? 1.0;
        return accA.compareTo(accB);
      });
      break;
    case 2:
      sortedHistory.sort((a, b) {
        final attA = (a['attempts'] as num?)?.toInt() ?? 999;
        final attB = (b['attempts'] as num?)?.toInt() ?? 999;
        final lastA =
            (a['lastAttemptedAt'] as num?)?.toDouble() ?? double.infinity;
        final lastB =
            (b['lastAttemptedAt'] as num?)?.toDouble() ?? double.infinity;
        final scoreA = attA + (nowMs - lastA) / (1000 * 60 * 60 * 24) / 10;
        final scoreB = attB + (nowMs - lastB) / (1000 * 60 * 60 * 24) / 10;
        return scoreA.compareTo(scoreB);
      });
      break;
    case 3:
    default:
      sortedHistory.sort((a, b) {
        final lastA =
            (a['lastAttemptedAt'] as num?)?.toDouble() ?? double.infinity;
        final lastB =
            (b['lastAttemptedAt'] as num?)?.toDouble() ?? double.infinity;
        return lastA.compareTo(lastB);
      });
      break;
  }

  final historyCount = min(3, sortedHistory.length);
  final aiCount = shouldRefresh ? 3 - historyCount : 0;

  final result = <Map<String, dynamic>>[];

  for (var i = 0; i < historyCount; i++) {
    result.add({...sortedHistory[i], 'isSuggested': false});
  }

  if (aiCount > 0) {
    List<String> relatedTopics = [];
    try {
      relatedTopics = await AIService.suggestRelatedPracticeTopics(
        practicedTopics: historyTopics,
        experienceLevel: experienceLevel,
        count: aiCount,
      );
    } catch (e) {
      debugPrint('[enrichedPracticeProvider] AI error: $e');
    }

    final existingNames =
        result.map((r) => r['topicName'].toString().toLowerCase()).toSet();
    for (var i = 0; i < relatedTopics.length && result.length < 3; i++) {
      final topic = relatedTopics[i];
      if (!existingNames.contains(topic.toLowerCase())) {
        result.add({
          'topicName': topic,
          'accuracy': null,
          'attempts': null,
          'lastAttemptedAt': null,
          'isSuggested': true,
        });
      }
    }
  }

  _cachedPractice = _PracticeCache(
    recommendations: result,
    fetchedAt: now,
    practicedTopicsHash: topicsHash,
  );

  final lastAttemptedAtValues = result
      .map((r) => r['lastAttemptedAt'])
      .whereType<num>()
      .map((n) => n.toInt())
      .toList();
  final basedOnLastAttemptAt = lastAttemptedAtValues.isNotEmpty
      ? (lastAttemptedAtValues..sort()).last
      : null;
  final prefs = await ref.read(preferenceRepositoryProvider).getMine();
  final prefsUpdatedAt =
      prefs?['updatedAt'] is num ? (prefs?['updatedAt'] as num).toInt() : null;
  final recRepo = ref.read(recommendationRepositoryProvider);
  try {
    await recRepo.upsertCached(
      practiceRecs: result,
      basedOnLastAttemptAt: basedOnLastAttemptAt,
      basedOnPreferencesUpdatedAt: prefsUpdatedAt,
      source: shouldRefresh ? 'quiz' : 'history',
    );
  } catch (e) {
    debugPrint('[enrichedPracticeProvider] Cache update failed: $e');
  }

  return result;
});

class _SuggestionsCache {
  final List<Map<String, dynamic>> suggestions;
  final DateTime fetchedAt;
  final String practicedTopicsHash;

  _SuggestionsCache({
    required this.suggestions,
    required this.fetchedAt,
    required this.practicedTopicsHash,
  });
}

_SuggestionsCache? _cachedSuggestions;

class _PracticeCache {
  final List<Map<String, dynamic>> recommendations;
  final DateTime fetchedAt;
  final String practicedTopicsHash;

  _PracticeCache({
    required this.recommendations,
    required this.fetchedAt,
    required this.practicedTopicsHash,
  });
}

_PracticeCache? _cachedPractice;

final refreshSuggestionsProvider = StateProvider<bool>((ref) => false);

final suggestedNewTopicsWithReasonsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final user = ref.watch(userProvider).value;
  if (user == null) return [];
  final activePath = await ref.watch(activeLearningPathProvider.future);
  if (activePath != null) return [];

  List<String> pathTopics = [];
  try {
    final pathRepo = ref.read(pathRepositoryProvider);
    final active = await pathRepo.getActive();
    if (active != null) {
      final aiPathJsonStr = active['userPath']?['aiPathJson']?.toString();
      if (aiPathJsonStr != null && aiPathJsonStr.isNotEmpty) {
        final parsed = json.decode(aiPathJsonStr);
        if (parsed is Map && parsed['path'] is List) {
          pathTopics = (parsed['path'] as List)
              .whereType<Map>()
              .map((d) => d['topic']?.toString())
              .whereType<String>()
              .where((t) => t.isNotEmpty)
              .toList();
        }
      }
    }
  } catch (_) {}

  final shouldRefresh = ref.watch(refreshSuggestionsProvider);

  try {
    final prefRepo = ref.read(preferenceRepositoryProvider);
    final analyticsRepo = ref.read(analyticsRepositoryProvider);
    final topicRepo = ref.read(topicRepositoryProvider);

    final results = await Future.wait([
      prefRepo.getMine(),
      analyticsRepo.getUserPerformanceVector(),
    ]);

    final prefs = results[0];
    final analytics = results[1] as Map<String, dynamic>;

    final interested = prefs?['interestedTopics'];
    final interestedTopics = interested is List
        ? interested.map((t) => t.toString()).toList()
        : <String>[];

    final experienceLevel =
        (prefs?['experienceLevel'] as String?) ?? 'beginner';

    final topicBreakdown =
        (analytics['topicBreakdown'] as List<dynamic>?) ?? [];
    final practicedTopics = topicBreakdown
        .map((t) => (t as Map)['topicName']?.toString() ?? '')
        .where((n) => n.isNotEmpty)
        .toList();
    final practicedLower = practicedTopics.map((t) => t.toLowerCase()).toSet();

    final sortedTopics = List<String>.from(practicedTopics)..sort();
    final topicsHash = sortedTopics.join(',');

    final now = DateTime.now();

    if (shouldRefresh) {
      Future.microtask(() {
        ref.read(refreshSuggestionsProvider.notifier).state = false;
      });
    }

    if (!shouldRefresh && _cachedSuggestions != null) {
      return _cachedSuggestions!.suggestions;
    }
    if (!shouldRefresh) {
      final cached = await ref.watch(recommendationsCacheProvider.future);
      final cachedSuggestions = cached?['suggestedTopics'];
      if (cachedSuggestions is List && cachedSuggestions.isNotEmpty) {
        final list = cachedSuggestions
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        _cachedSuggestions = _SuggestionsCache(
          suggestions: list,
          fetchedAt: now,
          practicedTopicsHash: topicsHash,
        );
        return list;
      }
    }

    final prefsUpdatedAt = prefs?['updatedAt'] is num
        ? (prefs?['updatedAt'] as num).toInt()
        : null;
    final lastAttemptedAtValues = topicBreakdown
        .map((t) => (t as Map)['lastAttemptedAt'])
        .whereType<num>()
        .map((n) => n.toInt())
        .toList();
    final basedOnLastAttemptAt = lastAttemptedAtValues.isNotEmpty
        ? (lastAttemptedAtValues..sort()).last
        : null;

    final hasDomains =
        practicedTopics.isNotEmpty || interestedTopics.isNotEmpty;
    final canUseAi = hasDomains && AIService.isConfigured();

    List<Map<String, dynamic>> suggestions = [];

    if (canUseAi && (shouldRefresh || _cachedSuggestions == null)) {
      suggestions = await AIService.suggestNewTopicsWithReasons(
        interestedTopics: interestedTopics,
        practicedTopics: practicedTopics,
        experienceLevel: experienceLevel,
        pathTopics: pathTopics,
        count: 5,
      );
    }

    if (suggestions.isEmpty) {
      final fallback = <Map<String, dynamic>>[];

      if (interestedTopics.isNotEmpty) {
        fallback.addAll(_buildFallbackSuggestionList(
          interestedTopics,
          'From your interests',
          excludeLower: practicedLower,
        ));
      }

      if (fallback.length < 5) {
        final trending = await topicRepo.getTrending(limit: 6);
        final trendingNames =
            trending.map((t) => t['name']?.toString() ?? '').toList();
        fallback.addAll(_buildFallbackSuggestionList(
          trendingNames,
          'Trending',
          excludeLower: practicedLower,
        ));
      }

      if (fallback.length < 5) {
        final allTopics = await topicRepo.listAll();
        final allTopicNames =
            allTopics.map((t) => t['name']?.toString() ?? '').toList();
        fallback.addAll(_buildFallbackSuggestionList(
          allTopicNames,
          'Explore a new topic',
          excludeLower: practicedLower,
        ));
      }

      if (fallback.isEmpty) {
        fallback.addAll(_buildFallbackSuggestionList(
          _defaultFallbackTopics,
          'Explore a new topic',
          excludeLower: practicedLower,
        ));
      }

      suggestions = fallback;
    }

    final deduped = <Map<String, dynamic>>[];
    final seen = <String>{};
    for (final item in suggestions) {
      final name = item['name']?.toString() ?? '';
      if (name.isEmpty) continue;
      final key = name.toLowerCase();
      if (seen.contains(key)) continue;
      seen.add(key);
      deduped.add(item);
      if (deduped.length >= 5) break;
    }

    _cachedSuggestions = _SuggestionsCache(
      suggestions: deduped,
      fetchedAt: now,
      practicedTopicsHash: topicsHash,
    );

    final source = shouldRefresh && practicedTopics.isNotEmpty
        ? 'quiz'
        : practicedTopics.isNotEmpty
            ? 'history'
            : interestedTopics.isNotEmpty
                ? 'onboarding'
                : 'fallback';
    final recRepo = ref.read(recommendationRepositoryProvider);
    try {
      await recRepo.upsertCached(
        suggestedTopics: deduped,
        basedOnLastAttemptAt: basedOnLastAttemptAt,
        basedOnPreferencesUpdatedAt: prefsUpdatedAt,
        source: source,
      );
    } catch (e) {
      debugPrint(
          '[suggestedNewTopicsWithReasonsProvider] Cache update failed: $e');
    }

    return deduped;
  } catch (e) {
    debugPrint('[suggestedNewTopicsWithReasonsProvider] Error: $e');
    if (_cachedSuggestions != null) {
      return _cachedSuggestions!.suggestions;
    }
    return [];
  }
});
