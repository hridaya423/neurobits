import 'dart:async';
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
import 'package:neurobits/repositories/exam_repository.dart';
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

final examRepositoryProvider = Provider<ExamRepository>((ref) {
  return ExamRepository(ConvexClientService.instance);
});

final progressRepositoryProvider = Provider<ProgressRepository>((ref) {
  return ProgressRepository(ConvexClientService.instance);
});

final reportSummaryProvider =
    FutureProvider.family<Map<String, dynamic>, String>(
  (ref, key) async {
    final parts = key.split(':');
    final period = parts.isNotEmpty ? parts[0] : 'weekly';
    final scope = parts.length > 1 ? parts[1] : 'all';
    final repo = ref.read(progressRepositoryProvider);
    return await repo.getReportSummary(period: period, scope: scope);
  },
);

final reportDetailProvider =
    FutureProvider.family<Map<String, dynamic>, String>(
  (ref, key) async {
    final parts = key.split(':');
    final period = parts.isNotEmpty ? parts[0] : 'weekly';
    final scope = parts.length > 1 ? parts[1] : 'all';
    final repo = ref.read(progressRepositoryProvider);
    return await repo.getReportDetail(period: period, scope: scope);
  },
);

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

  bool isTimeoutError(Object error) {
    return error is TimeoutException ||
        error.toString().contains('TimeoutException');
  }

  Future<void> ensureCurrentBestEffort() async {
    try {
      await ConvexClientService.instance.mutation(
        name: 'users:ensureCurrent',
        args: {},
        timeout: bootstrapTimeout,
      );
    } catch (e) {
      if (!isTimeoutError(e)) {
        debugPrint('[userProvider] users:ensureCurrent failed: $e');
      }
    }
  }

  Future<void> syncAuthToken() async {
    try {
      final idToken = await AuthService.instance.getIdToken();
      await ConvexClientService.instance.setAuthToken(idToken);
    } catch (e) {
      debugPrint('[userProvider] Failed to sync auth token: $e');
    }
  }

  Future<Map<String, dynamic>?> fetchCurrentUser() async {
    try {
      final existing = await userRepo.getMe().timeout(bootstrapTimeout);
      if (existing != null) return existing;
    } catch (e) {
      if (!isTimeoutError(e)) {
        debugPrint('[userProvider] getMe before ensureCurrent failed: $e');
      }
    }

    await ensureCurrentBestEffort();

    try {
      return await userRepo.getMe().timeout(bootstrapTimeout);
    } catch (e) {
      if (!isTimeoutError(e)) {
        debugPrint('[userProvider] getMe after ensureCurrent failed: $e');
      }
      return null;
    }
  }

  Future<Map<String, dynamic>?> fetchCurrentUserWithRetry() async {
    await syncAuthToken();
    var userData = await fetchCurrentUser();
    if (userData != null) return userData;

    await Future.delayed(const Duration(seconds: 2));
    await syncAuthToken();
    userData = await fetchCurrentUser();
    return userData;
  }

  yield null;

  if (AuthService.instance.currentStatus == AuthStatus.authenticated) {
    try {
      final userData = await fetchCurrentUserWithRetry();
      yield userData;
    } catch (e) {
      debugPrint('[userProvider] Error fetching initial user data: $e');
      yield null;
    }
  }

  await for (final status in AuthService.instance.authStateChanges) {
    if (status == AuthStatus.authenticated) {
      try {
        final userData = await fetchCurrentUserWithRetry();
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

final userExamTargetProvider =
    FutureProvider<Map<String, dynamic>?>((ref) async {
  final user = ref.watch(userProvider).value;
  if (user == null) return null;
  final examRepo = ref.read(examRepositoryProvider);
  return await examRepo.getMyTarget();
});

final userExamTargetsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final user = ref.watch(userProvider).value;
  if (user == null) return const [];
  final examRepo = ref.read(examRepositoryProvider);
  return await examRepo.listMyTargets();
});

final examCatalogProvider =
    FutureProvider.family<List<Map<String, dynamic>>, Map<String, dynamic>>(
  (ref, filters) async {
    final examRepo = ref.read(examRepositoryProvider);
    final countryCode = filters['countryCode']?.toString();
    final examFamily = filters['examFamily']?.toString();
    final subject = filters['subject']?.toString();
    final query = filters['query']?.toString();
    final rawLimit = filters['limit'];
    final limit = rawLimit is num ? rawLimit.toInt() : 50;
    return await examRepo.listCatalog(
      countryCode: countryCode,
      examFamily: examFamily,
      subject: subject,
      query: query,
      limit: limit,
    );
  },
);

final examIntentMatchesProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
  (ref, query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];
    final examRepo = ref.read(examRepositoryProvider);
    return await examRepo.resolveIntent(trimmed, limit: 6);
  },
);

final examCatalogStatusProvider =
    FutureProvider<Map<String, dynamic>>((ref) async {
  final examRepo = ref.read(examRepositoryProvider);
  return await examRepo.getCatalogStatus();
});

final examCatalogAllProvider = FutureProvider<List<Map<String, dynamic>>>(
  (ref) async {
    final examRepo = ref.read(examRepositoryProvider);
    return await examRepo.listCatalog(
      countryCode: 'GB',
      examFamily: 'gcse',
      coreOnly: true,
      limit: 2000,
    );
  },
);

final userExamDashboardProvider =
    FutureProvider<Map<String, dynamic>>((ref) async {
  final user = ref.watch(userProvider).value;
  if (user == null) {
    return {
      'target': null,
      'currentGrade': null,
      'targetGrade': null,
      'projectedGrade': 0,
      'gradeGapToTarget': 0,
      'gradeStatus': 'no_target',
      'totalAttempts': 0,
      'completedAttempts': 0,
      'avgAccuracy': 0,
      'avgMarksPct': 0,
      'bestMarksPct': 0,
      'totalStudySeconds': 0,
      'lastAttemptedAt': 0,
      'trend7d': const <Map<String, dynamic>>[],
      'weakTopics': const <Map<String, dynamic>>[],
    };
  }
  final examRepo = ref.read(examRepositoryProvider);
  return await examRepo.getMyExamDashboard();
});

final userExamDashboardByTargetProvider =
    FutureProvider.family<Map<String, dynamic>, String?>((ref, targetId) async {
  final user = ref.watch(userProvider).value;
  if (user == null) {
    return {
      'target': null,
      'currentGrade': null,
      'targetGrade': null,
      'projectedGrade': 0,
      'gradeGapToTarget': 0,
      'gradeStatus': 'no_target',
      'totalAttempts': 0,
      'completedAttempts': 0,
      'avgAccuracy': 0,
      'avgMarksPct': 0,
      'bestMarksPct': 0,
      'totalStudySeconds': 0,
      'lastAttemptedAt': 0,
      'trend7d': const <Map<String, dynamic>>[],
      'weakTopics': const <Map<String, dynamic>>[],
    };
  }
  final examRepo = ref.read(examRepositoryProvider);
  return await examRepo.getMyExamDashboard(targetId: targetId);
});

final userExamProfileByTargetProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, targetId) async {
  final user = ref.watch(userProvider).value;
  if (user == null) {
    return {
      'target': null,
      'sourceCount': 0,
      'sections': const <Map<String, dynamic>>[],
      'papers': const <Map<String, dynamic>>[],
      'examTechniques': const <Map<String, dynamic>>[],
      'pitfalls': const <Map<String, dynamic>>[],
      'priorityPitfalls': const <Map<String, dynamic>>[],
      'weaknessTags': const <String>[],
    };
  }
  final examRepo = ref.read(examRepositoryProvider);
  return await examRepo.getMyExamProfile(targetId: targetId);
});

@immutable
class ExamSubjectReportArgs {
  final String targetId;
  final String period;

  const ExamSubjectReportArgs({
    required this.targetId,
    required this.period,
  });

  @override
  bool operator ==(Object other) {
    return other is ExamSubjectReportArgs &&
        other.targetId == targetId &&
        other.period == period;
  }

  @override
  int get hashCode => Object.hash(targetId, period);
}

final userExamSubjectReportProvider =
    FutureProvider.family<Map<String, dynamic>, ExamSubjectReportArgs>(
  (ref, args) async {
    final user = ref.watch(userProvider).value;
    if (user == null) {
      return {
        'target': null,
        'period': args.period,
        'windowStart': 0,
        'windowEnd': 0,
        'previousWindowStart': 0,
        'totalAttempts': 0,
        'completedAttempts': 0,
        'avgAccuracy': 0,
        'avgMarksPct': 0,
        'bestMarksPct': 0,
        'totalStudySeconds': 0,
        'marksDeltaPct': 0,
        'accuracyDeltaPct': 0,
        'consistency': {
          'activeDays': 0,
          'windowDays': 0,
          'consistencyPct': 0,
          'completionRate': 0,
          'sessionsPerActiveDay': 0,
          'dailyMinutes': 0,
          'cadenceDelta': 0,
        },
        'progression': {
          'trendSlopePct': 0,
          'volatilityPct': 0,
          'bestRunDays': 0,
          'momentumLabel': 'build_evidence',
        },
        'execution': {
          'avgSecondsPerAttempt': 0,
          'avgSecondsPerQuestion': 0,
          'speedAccuracySignal': 'insufficient_data',
          'questionsEstimated': 0,
        },
        'errorProfile': const <Map<String, dynamic>>[],
        'motivation': {
          'wins': const <String>[],
          'nextMilestone': '',
        },
        'insightActions': const <Map<String, dynamic>>[],
        'trend': const <Map<String, dynamic>>[],
        'topicBreakdown': const <Map<String, dynamic>>[],
      };
    }

    final targetId = args.targetId.trim();
    final period = args.period.trim().isEmpty ? 'weekly' : args.period.trim();
    if (targetId.isEmpty) {
      return {
        'target': null,
        'period': period,
        'windowStart': 0,
        'windowEnd': 0,
        'previousWindowStart': 0,
        'totalAttempts': 0,
        'completedAttempts': 0,
        'avgAccuracy': 0,
        'avgMarksPct': 0,
        'bestMarksPct': 0,
        'totalStudySeconds': 0,
        'marksDeltaPct': 0,
        'accuracyDeltaPct': 0,
        'consistency': {
          'activeDays': 0,
          'windowDays': 0,
          'consistencyPct': 0,
          'completionRate': 0,
          'sessionsPerActiveDay': 0,
          'dailyMinutes': 0,
          'cadenceDelta': 0,
        },
        'progression': {
          'trendSlopePct': 0,
          'volatilityPct': 0,
          'bestRunDays': 0,
          'momentumLabel': 'build_evidence',
        },
        'execution': {
          'avgSecondsPerAttempt': 0,
          'avgSecondsPerQuestion': 0,
          'speedAccuracySignal': 'insufficient_data',
          'questionsEstimated': 0,
        },
        'errorProfile': const <Map<String, dynamic>>[],
        'motivation': {
          'wins': const <String>[],
          'nextMilestone': '',
        },
        'insightActions': const <Map<String, dynamic>>[],
        'trend': const <Map<String, dynamic>>[],
        'topicBreakdown': const <Map<String, dynamic>>[],
      };
    }

    final examRepo = ref.read(examRepositoryProvider);
    return await examRepo.getMyExamSubjectReport(
      targetId: targetId,
      period: period,
    );
  },
);

const int _dayMs = 86400000;
const Set<String> _gcseCoreSubjects = <String>{
  'mathematics',
  'english language',
  'english literature',
  'biology',
  'chemistry',
  'physics',
};

int? _daysUntil(int? timestamp) {
  if (timestamp == null || timestamp <= 0) return null;
  final now = DateTime.now().millisecondsSinceEpoch;
  final diff = timestamp - now;
  return (diff / _dayMs).ceil();
}

const Map<String, String> _examReasonLabels = <String, String>{
  'weak_topic': 'Weak topic',
  'recency_gap': 'Not practiced recently',
  'exam_soon': 'Exam date approaching',
  'target_gap': 'Target grade gap',
  'baseline_needed': 'Build starting profile',
  'maintain_momentum': 'Keep momentum',
  'build_evidence': 'Needs more evidence',
  'incomplete_reasoning': 'Incomplete reasoning',
  'missing_keyword': 'Missing key term',
  'calculation_error': 'Calculation error',
  'misread_prompt': 'Misread question prompt',
  'no_working': 'No working shown',
};

String _formatReasonCodeLabel(String code) {
  final formatted = code.replaceAll(RegExp(r'[_-]+'), ' ').trim();
  if (formatted.isEmpty) return code;
  return formatted
      .split(' ')
      .map((part) =>
          part.isEmpty ? part : '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');
}

List<String> _reasonLabelsFromCodes(List<String> codes) {
  return codes
      .map((code) => _examReasonLabels[code] ?? _formatReasonCodeLabel(code))
      .where((label) => label.trim().isNotEmpty)
      .toSet()
      .toList(growable: false);
}

Map<String, dynamic> _buildExamSessionPreset({
  required String sessionType,
  required double recentMarks,
  int questionCount = 10,
  bool includeHints = false,
}) {
  final safeMarks = recentMarks.clamp(0.0, 1.0);
  final isBaseline = sessionType == 'baseline';
  final profile = isBaseline ? 'exam_baseline' : 'exam_standard';
  final difficulty = isBaseline
      ? 'Medium'
      : safeMarks < 0.45
          ? 'Easy'
          : safeMarks < 0.7
              ? 'Medium'
              : 'Hard';
  final effectiveCount = isBaseline ? 24 : questionCount.clamp(6, 20);
  final timePerQuestion = isBaseline ? 75 : 70;
  return {
    'questionCount': effectiveCount,
    'timePerQuestion': timePerQuestion,
    'totalTimeLimit': effectiveCount * timePerQuestion,
    'timedMode': true,
    'difficulty': difficulty,
    'includeCodeChallenges': false,
    'includeMcqs': true,
    'includeInput': true,
    'includeFillBlank': false,
    'includeHints': includeHints || isBaseline,
    'includeImageQuestions': false,
    'examModeProfile': profile,
    'autoStart': true,
  };
}

final gcseExamHomeProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final user = ref.watch(userProvider).value;
  if (user == null) {
    return {
      'targets': const <Map<String, dynamic>>[],
      'reviseToday': const <Map<String, dynamic>>[],
      'needsWork': const <Map<String, dynamic>>[],
      'subjectProgress': const <Map<String, dynamic>>[],
      'revisionIntelligence': {
        'subjectCount': 0,
        'mocksInDays': null,
        'gcsesInDays': null,
        'atRiskCount': 0,
        'onTrackCount': 0,
        'closeCount': 0,
        'missingDateCount': 0,
        'timetableMode': 'none',
        'dailyStudyMinutes': 45,
        'configuredDailyMinutes': 45,
        'adaptiveDailyMinutes': 45,
        'actualDailyMinutes14d': 0,
        'actualActiveDayMinutes14d': 0,
        'activeDays14d': 0,
        'actualDailySessions14d': 0,
        'weeklyStudyMinutes': 0,
        'weeklySessionsTarget': 0,
      },
      'todayMission': {
        'headline': 'Set up GCSE subjects to get your first plan.',
        'primaryCompletedToday': false,
        'dailyMinutesBudget': 45,
        'configuredDailyMinutes': 45,
        'actualDailyMinutes14d': 0,
        'actualActiveDayMinutes14d': 0,
        'budgetMode': 'configured',
        'plannedMinutes': 0,
        'plannedSessions': 0,
        'sessions': const <Map<String, dynamic>>[],
      },
    };
  }

  final examRepo = ref.read(examRepositoryProvider);
  try {
    final payload = await examRepo.getGcseExamHome();
    if (payload.isNotEmpty) {
      return payload;
    }
  } catch (_) {
    // Fallback to local assembly for compatibility while backend rolls out.
  }

  final allTargets = await examRepo.listMyTargets();
  final gcseTargets = allTargets.where((target) {
    if ((target['examFamily']?.toString().toLowerCase() ?? '') != 'gcse') {
      return false;
    }
    final subject = target['subject']?.toString().toLowerCase().trim() ?? '';
    return _gcseCoreSubjects.contains(subject);
  }).toList()
    ..sort((a, b) {
      final sa = a['subject']?.toString() ?? '';
      final sb = b['subject']?.toString() ?? '';
      return sa.compareTo(sb);
    });

  final reviseToday = <Map<String, dynamic>>[];
  final needsWork = <Map<String, dynamic>>[];
  final subjectProgress = <Map<String, dynamic>>[];
  final now = DateTime.now().millisecondsSinceEpoch;
  int? nearestMockInDays;
  int? nearestGcseInDays;
  int atRiskCount = 0;
  int closeCount = 0;
  int onTrackCount = 0;
  int missingDateCount = 0;
  String timetableMode = 'none';
  int weeklyStudyMinutes = 0;
  int weeklySessionsTarget = 0;

  for (final target in gcseTargets) {
    final targetId = target['_id']?.toString();
    if (targetId == null || targetId.trim().isEmpty) continue;

    final dashboard = await examRepo.getMyExamDashboard(targetId: targetId);
    final totalAttempts = convexInt(dashboard['totalAttempts']);
    final avgMarksPct = (dashboard['avgMarksPct'] as num?)?.toDouble() ?? 0.0;
    final lastAttemptedAt = convexInt(dashboard['lastAttemptedAt']);
    final gradeStatus = dashboard['gradeStatus']?.toString() ?? 'no_target';
    final gradeGapToTarget = convexInt(dashboard['gradeGapToTarget']);
    final daysSinceLast = lastAttemptedAt > 0
        ? ((now - lastAttemptedAt) ~/ _dayMs).clamp(0, 365)
        : 365;

    final mockDateAt = convexInt(target['mockDateAt']);
    final examDateAt = convexInt(target['examDateAt']);
    final mockInDays = _daysUntil(mockDateAt > 0 ? mockDateAt : null);
    final examInDays = _daysUntil(examDateAt > 0 ? examDateAt : null);
    final relevantDeadlines = [mockInDays, examInDays]
        .whereType<int>()
        .where((days) => days >= 0)
        .toList(growable: false);
    final nearestDeadlineInDays =
        relevantDeadlines.isEmpty ? null : relevantDeadlines.reduce(min);
    final examUrgencyScore = nearestDeadlineInDays == null
        ? 0.0
        : (1 - (nearestDeadlineInDays / 90)).clamp(0.0, 1.0);
    if (mockInDays == null && examInDays == null) {
      missingDateCount += 1;
    }
    if (mockInDays != null) {
      nearestMockInDays = nearestMockInDays == null
          ? mockInDays
          : (mockInDays < nearestMockInDays ? mockInDays : nearestMockInDays);
    }
    if (examInDays != null) {
      nearestGcseInDays = nearestGcseInDays == null
          ? examInDays
          : (examInDays < nearestGcseInDays ? examInDays : nearestGcseInDays);
    }

    if (gradeStatus == 'at_risk') {
      atRiskCount += 1;
    } else if (gradeStatus == 'close') {
      closeCount += 1;
    } else if (gradeStatus == 'on_track') {
      onTrackCount += 1;
    }

    final targetTimetableMode = target['timetableMode']?.toString().trim();
    if (targetTimetableMode != null && targetTimetableMode.isNotEmpty) {
      timetableMode = targetTimetableMode;
    }
    final targetWeeklyMinutes = convexInt(target['weeklyStudyMinutes']);
    if (targetWeeklyMinutes > 0) {
      weeklyStudyMinutes = targetWeeklyMinutes;
    }
    final targetWeeklySessions = convexInt(target['weeklySessionsTarget']);
    if (targetWeeklySessions > 0) {
      weeklySessionsTarget = targetWeeklySessions;
    }

    subjectProgress.add({
      'targetId': targetId,
      'subject': target['subject']?.toString() ?? 'Subject',
      'board': target['board']?.toString() ?? '',
      'totalAttempts': totalAttempts,
      'avgMarksPct': avgMarksPct,
      'lastAttemptedAt': lastAttemptedAt,
      'daysSinceLast': daysSinceLast,
      'gradeStatus': gradeStatus,
      'gradeGapToTarget': gradeGapToTarget,
      'mockDateAt': mockDateAt > 0 ? mockDateAt : null,
      'examDateAt': examDateAt > 0 ? examDateAt : null,
      'mockInDays': mockInDays,
      'examInDays': examInDays,
    });

    final weak = isConvexList(dashboard['weakTopics'])
        ? toMapList(dashboard['weakTopics'])
        : const <Map<String, dynamic>>[];

    if (weak.isEmpty) {
      if (totalAttempts == 0) {
        final reasonCodes = <String>['baseline_needed'];
        final reasonLabels = _reasonLabelsFromCodes(reasonCodes);
        reviseToday.add({
          'targetId': targetId,
          'subject': target['subject']?.toString() ?? 'Subject',
          'topic': 'Baseline diagnostic',
          'actionLabel': 'Build your baseline profile',
          'avgMarksPct': 0.0,
          'attempts': 0,
          'daysSinceLast': daysSinceLast,
          'dueScore': 0.58 + (examUrgencyScore * 0.18),
          'estimatedMinutes': 30,
          'effortLabel': '~24-34 min',
          'sessionType': 'baseline',
          'reasonCodes': reasonCodes,
          'reasonLabels': reasonLabels,
          'whyNow': reasonLabels.first,
          'expectedGain':
              'Pinpoint weak areas and calibrate your next sessions.',
          'learningMethods': const [
            'Retrieval practice',
            'Metacognitive calibration',
          ],
          'completedToday': false,
          'confidence': 0.95,
          'quizPreset': _buildExamSessionPreset(
            sessionType: 'baseline',
            recentMarks: 0,
            questionCount: 24,
            includeHints: true,
          ),
        });
      } else if (daysSinceLast >= 5) {
        final reasonCodes = <String>[
          if (daysSinceLast >= 5) 'recency_gap',
          'maintain_momentum',
          if (gradeGapToTarget > 0) 'target_gap',
          if (examUrgencyScore > 0.4) 'exam_soon',
        ];
        final reasonLabels = _reasonLabelsFromCodes(reasonCodes);
        reviseToday.add({
          'targetId': targetId,
          'subject': target['subject']?.toString() ?? 'Subject',
          'topic': 'Timed mixed practice',
          'actionLabel': 'Run mixed exam retrieval',
          'avgMarksPct': avgMarksPct,
          'attempts': totalAttempts,
          'daysSinceLast': daysSinceLast,
          'dueScore': 0.5 +
              ((daysSinceLast / 10).clamp(0, 1) * 0.25) +
              (examUrgencyScore * 0.15) +
              ((gradeGapToTarget / 3).clamp(0, 1) * 0.1),
          'estimatedMinutes': 25,
          'effortLabel': '~21-29 min',
          'sessionType': 'mixed_practice',
          'reasonCodes': reasonCodes,
          'reasonLabels': reasonLabels,
          'whyNow': reasonLabels.first,
          'expectedGain':
              'Stabilize exam performance across mixed question types.',
          'learningMethods': const ['Interleaving', 'Desirable difficulty'],
          'completedToday': false,
          'confidence': 0.72,
          'quizPreset': _buildExamSessionPreset(
            sessionType: 'mixed_practice',
            recentMarks: avgMarksPct,
            questionCount: 12,
            includeHints: avgMarksPct < 0.55,
          ),
        });
      }
    }

    if (totalAttempts > 0 && avgMarksPct < 0.65) {
      needsWork.add({
        'targetId': targetId,
        'subject': target['subject']?.toString() ?? 'Subject',
        'topic': 'Mixed paper questions',
        'avgMarksPct': avgMarksPct,
        'attempts': totalAttempts,
        'daysSinceLast': daysSinceLast,
        'dueScore': (1 - avgMarksPct).clamp(0.0, 1.0),
      });
    }

    for (final row in weak.take(5)) {
      final topic = row['topic']?.toString().trim() ?? '';
      if (topic.isEmpty) continue;
      final topicMarks =
          (row['avgMarksPct'] as num?)?.toDouble() ?? avgMarksPct;
      final topicAttempts = convexInt(row['attempts']);
      final weaknessScore = (1 - topicMarks).clamp(0.0, 1.0);
      final recencyScore = (daysSinceLast / 10).clamp(0, 1).toDouble();
      final targetGapScore = (gradeGapToTarget / 3).clamp(0, 1).toDouble();
      final dueScore = (weaknessScore * 0.56) +
          (recencyScore * 0.18) +
          (examUrgencyScore * 0.16) +
          (targetGapScore * 0.1) +
          (topicAttempts <= 1 ? 0.04 : 0);
      final reasonCodes = <String>[
        if (weaknessScore >= 0.35) 'weak_topic',
        if (recencyScore >= 0.45) 'recency_gap',
        if (examUrgencyScore >= 0.4) 'exam_soon',
        if (targetGapScore > 0) 'target_gap',
        if (topicAttempts <= 1) 'build_evidence',
      ];
      if (reasonCodes.isEmpty) {
        reasonCodes.add('maintain_momentum');
      }
      final estimatedMinutes =
          topicAttempts <= 2 ? 24 : (weaknessScore >= 0.5 ? 28 : 22);
      final reasonLabels = _reasonLabelsFromCodes(reasonCodes);

      final item = {
        'targetId': targetId,
        'subject': target['subject']?.toString() ?? 'Subject',
        'topic': topic,
        'actionLabel': 'Repair weakest performance in $topic',
        'avgMarksPct': topicMarks,
        'attempts': topicAttempts,
        'daysSinceLast': daysSinceLast,
        'dueScore': dueScore,
        'estimatedMinutes': estimatedMinutes,
        'effortLabel': estimatedMinutes >= 27 ? '~24-32 min' : '~19-26 min',
        'sessionType': 'weak_focus',
        'reasonCodes': reasonCodes,
        'reasonLabels': reasonLabels,
        'whyNow': reasonLabels.first,
        'expectedGain':
            'Improve marks in $topic with targeted retrieval and correction.',
        'learningMethods': const [
          'Retrieval practice',
          'Error-focused feedback'
        ],
        'completedToday': daysSinceLast == 0,
        'confidence': (0.6 + (min(topicAttempts, 4) * 0.08)).clamp(0.6, 0.92),
        'quizPreset': _buildExamSessionPreset(
          sessionType: 'weak_focus',
          recentMarks: topicMarks,
          questionCount: topicMarks < 0.45 ? 14 : 12,
          includeHints: topicMarks < 0.6,
        ),
      };
      reviseToday.add(item);
      needsWork.add(item);
    }
  }

  final dedupedReviseToday = <Map<String, dynamic>>[];
  final seenReviseKeys = <String>{};
  for (final item in reviseToday) {
    final targetId = item['targetId']?.toString() ?? '';
    final topic = item['topic']?.toString().toLowerCase().trim() ?? '';
    final key = '$targetId::$topic';
    if (seenReviseKeys.contains(key)) continue;
    seenReviseKeys.add(key);
    dedupedReviseToday.add(item);
  }

  final dedupedNeedsWork = <Map<String, dynamic>>[];
  final seenNeedsKeys = <String>{};
  for (final item in needsWork) {
    final targetId = item['targetId']?.toString() ?? '';
    final topic = item['topic']?.toString().toLowerCase().trim() ?? '';
    final key = '$targetId::$topic';
    if (seenNeedsKeys.contains(key)) continue;
    seenNeedsKeys.add(key);
    dedupedNeedsWork.add(item);
  }

  dedupedReviseToday.sort((a, b) {
    final scoreCmp = ((b['dueScore'] as num?)?.toDouble() ?? 0)
        .compareTo((a['dueScore'] as num?)?.toDouble() ?? 0);
    if (scoreCmp != 0) return scoreCmp;
    return ((a['avgMarksPct'] as num?)?.toDouble() ?? 1)
        .compareTo((b['avgMarksPct'] as num?)?.toDouble() ?? 1);
  });

  dedupedNeedsWork.sort((a, b) {
    final marksCmp = ((a['avgMarksPct'] as num?)?.toDouble() ?? 1)
        .compareTo((b['avgMarksPct'] as num?)?.toDouble() ?? 1);
    if (marksCmp != 0) return marksCmp;
    return (convexInt(b['attempts']) - convexInt(a['attempts']));
  });

  final configuredDailyMinutes =
      weeklyStudyMinutes > 0 ? (weeklyStudyMinutes / 7).round() : 45;
  final adaptiveDailyMinutes = configuredDailyMinutes;
  final actualDailyMinutes14d = 0.0;
  final actualActiveDayMinutes14d = 0.0;
  final activeDays14d = 0;
  final actualDailySessions14d = 0.0;
  final dailyStudyMinutes = adaptiveDailyMinutes;
  final dailySessionBudget =
      weeklySessionsTarget > 0 ? max(1, (weeklySessionsTarget / 7).ceil()) : 2;
  final missionSessions = <Map<String, dynamic>>[];
  var plannedMinutes = 0;
  for (final item in dedupedReviseToday) {
    final estimatedMinutes = max(10, convexInt(item['estimatedMinutes']));
    final nextSessionCount = missionSessions.length + 1;
    final nextMinutes = plannedMinutes + estimatedMinutes;
    final withinSessionBudget = nextSessionCount <= dailySessionBudget;
    final withinTimeBudget = nextMinutes <= max(dailyStudyMinutes, 25);
    if (withinSessionBudget && withinTimeBudget) {
      missionSessions.add(item);
      plannedMinutes = nextMinutes;
      continue;
    }
    if (missionSessions.isEmpty) {
      missionSessions.add(item);
      plannedMinutes = estimatedMinutes;
    }
    if (missionSessions.length >= dailySessionBudget) {
      break;
    }
  }

  final missionHeadline = missionSessions.isEmpty
      ? 'Complete one session to unlock a personalized mission.'
      : missionSessions.length == 1
          ? 'One high-impact session is ready.'
          : 'Start the primary mission, then run the backup if you still have energy.';
  final primaryCompletedToday = missionSessions.isNotEmpty &&
      missionSessions.first['completedToday'] == true;

  return {
    'targets': gcseTargets,
    'reviseToday': dedupedReviseToday.take(8).toList(),
    'needsWork': dedupedNeedsWork.take(8).toList(),
    'subjectProgress': subjectProgress,
    'todayMission': {
      'headline': missionHeadline,
      'primaryCompletedToday': primaryCompletedToday,
      'dailyMinutesBudget': dailyStudyMinutes,
      'configuredDailyMinutes': configuredDailyMinutes,
      'actualDailyMinutes14d': actualDailyMinutes14d,
      'actualActiveDayMinutes14d': actualActiveDayMinutes14d,
      'budgetMode': 'configured',
      'plannedMinutes': plannedMinutes,
      'plannedSessions': missionSessions.length,
      'sessions': missionSessions,
    },
    'revisionIntelligence': {
      'subjectCount': gcseTargets.length,
      'mocksInDays': nearestMockInDays,
      'gcsesInDays': nearestGcseInDays,
      'atRiskCount': atRiskCount,
      'closeCount': closeCount,
      'onTrackCount': onTrackCount,
      'missingDateCount': missingDateCount,
      'timetableMode': timetableMode,
      'dailyStudyMinutes': dailyStudyMinutes,
      'configuredDailyMinutes': configuredDailyMinutes,
      'adaptiveDailyMinutes': adaptiveDailyMinutes,
      'actualDailyMinutes14d': actualDailyMinutes14d,
      'actualActiveDayMinutes14d': actualActiveDayMinutes14d,
      'activeDays14d': activeDays14d,
      'actualDailySessions14d': actualDailySessions14d,
      'weeklyStudyMinutes': weeklyStudyMinutes,
      'weeklySessionsTarget': weeklySessionsTarget,
    },
  };
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
