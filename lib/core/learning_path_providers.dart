import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neurobits/core/providers.dart';
import 'package:neurobits/services/convex_client_service.dart';
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
        final path = await ref.watch(activeLearningPathProvider.future);
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
  final currentStep = (userPath['current_step'] as num?)?.toInt() ?? 1;
  final topics =
      isConvexList(userPath['topics']) ? toList(userPath['topics']) : null;
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
  final topics =
      isConvexList(userPath['topics']) ? toList(userPath['topics']) : null;
  if (topics == null) return [];
  return topics.map((e) => toMap(e)).toList();
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

    ref.listen(activeLearningPathProvider, (previous, next) {
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
        final path = await ref.read(activeLearningPathProvider.future);
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
    final pathRepo = ref.read(pathRepositoryProvider);
    final completed = await pathRepo.listCompleted();
    return completed.map((entry) {
      final up = entry['userPath'] as Map<String, dynamic>? ?? {};
      return {
        'id': up['_id'],
        'user_path_id': up['_id'],
        'path_id': up['pathId'],
        'current_step': up['currentStep'],
        'started_at': up['startedAt'],
        'completed_at': up['completedAt'],
        'name': entry['pathName'] ?? 'Unnamed Path',
        'description': entry['pathDescription'] ?? '',
        'ai_path_json': up['aiPathJson'],
        'duration_days': up['durationDays'],
        'daily_minutes': up['dailyMinutes'],
        'level': up['level'],
        'is_custom': up['isCustom'] ?? false,
      };
    }).toList();
  } catch (e) {
    debugPrint('Error fetching completed paths: $e');
    return [];
  }
});

final activeLearningPathProvider =
    FutureProvider<Map<String, dynamic>?>((ref) async {
  final userAsync = ref.watch(userProvider);
  final user = userAsync.value;
  if (user == null) return null;

  try {
    final pathRepo = ref.read(pathRepositoryProvider);
    final activeResult = await pathRepo.getActive();
    if (activeResult == null) return null;

    final userPath = activeResult['userPath'] as Map<String, dynamic>? ?? {};
    final progress = activeResult['progress'] as Map<String, dynamic>? ?? {};
    final pathName = activeResult['pathName'] as String?;
    final pathDescription = activeResult['pathDescription'] as String?;

    final userPathId = userPath['_id'] as String?;
    if (userPathId == null) return null;

    final challenges =
        await pathRepo.listChallengesForPath(userPathId: userPathId);

    Map<String, dynamic>? metadata;
    String? aiDescription;
    List<dynamic>? aiPathList;
    final aiPathJsonStr = userPath['aiPathJson'] as String?;
    if (aiPathJsonStr != null && aiPathJsonStr.isNotEmpty) {
      try {
        final parsed = json.decode(aiPathJsonStr);
        if (parsed is Map<String, dynamic>) {
          metadata = parsed;
          aiDescription = parsed['path_description']?.toString();
          if (parsed['path'] is List) {
            aiPathList = parsed['path'] as List<dynamic>;
          }
        } else if (parsed is List<dynamic>) {
          aiPathList = parsed;
        }
      } catch (_) {
      }
    }

    final String? resolvedDescription = (pathDescription == null ||
            pathDescription.toLowerCase().startsWith('ai-generated') ||
            pathDescription.trim().isEmpty)
        ? (aiDescription ?? pathDescription)
        : pathDescription;

    List<Map<String, dynamic>> topics = [];
    if (aiPathList != null) {
      topics = aiPathList.whereType<Map>().map((item) {
        final data = Map<String, dynamic>.from(item);
        final day = (data['day'] as num?)?.toInt() ?? 1;
        return {
          'step_number': day,
          'day': day,
          'topic': data['topic'],
          'title': data['title'],
          'description': data['description'],
          'challenge_type': data['challenge_type'],
        };
      }).toList();
    }

    if (topics.isEmpty) {
      final byDay = <int, Map<String, dynamic>>{};
      for (final ch in challenges) {
        final day = (ch['day'] as num?)?.toInt() ?? 1;
        if (!byDay.containsKey(day)) {
          byDay[day] = {
            'step_number': day,
            'day': day,
            'topic': ch['topic'],
            'title': ch['title'],
            'description': ch['description'],
            'challenge_type': ch['challengeType'],
            '_id': ch['_id']?.toString(),
          };
        }
      }
      final dayKeys = byDay.keys.toList()..sort();
      topics = dayKeys.map((day) => byDay[day]!).toList();
    }

    return {
      'id': userPath['pathId'] ?? userPathId,
      'name': pathName ?? 'Learning Path',
      'description': resolvedDescription ?? '',
      'is_active': userPath['isActive'] ?? false,
      'current_step': (userPath['currentStep'] as num?)?.toInt() ?? 1,
      'user_path_id': userPathId,
      'started_at': userPath['startedAt'],
      'completed_at': userPath['completedAt'],
      'is_complete': userPath['isComplete'] ?? false,
      'duration_days': userPath['durationDays'] is num
          ? (userPath['durationDays'] as num).toInt()
          : 0,
      'daily_minutes': userPath['dailyMinutes'] is num
          ? (userPath['dailyMinutes'] as num).toInt()
          : 0,
      'level': userPath['level'] as String? ?? '',
      'ai_path_json': aiPathJsonStr,
      'topics': topics,
      'path': topics,
      'challenges': challenges,
      'metadata': metadata,
      'total_steps': topics.isNotEmpty
          ? topics.length
          : (userPath['durationDays'] as num?)?.toInt() ?? 0,
      'progress': progress,
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
    final pathRepo = ref.read(pathRepositoryProvider);
    return await pathRepo.listChallengesForPath(userPathId: userPathId);
  } catch (e) {
    debugPrint('Error fetching path challenges: $e');
    return [];
  }
});
