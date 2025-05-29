import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import 'package:uuid/uuid.dart';
import 'dart:convert';
import 'package:neurobits/services/badge_service.dart';
import 'package:neurobits/services/content_moderation_service.dart';

class SupabaseService {
  static late final SupabaseClient client;
  static final RegExp _alphanumericWithSpaces = RegExp(r'^[a-zA-Z0-9\s-_]+$');
  static final RegExp _emailPattern =
      RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
  static String sanitizeInput(String input) {
    return input.trim().replaceAll(RegExp(r'[";{}()\[\]<>]'), '');
  }

  static bool isValidInput(String input, {bool isEmail = false}) {
    if (input.isEmpty) return false;
    if (isEmail) return _emailPattern.hasMatch(input);
    return _alphanumericWithSpaces.hasMatch(input);
  }

  static Future<String?> moderateContent(String input, {String? userId}) async {
    if (input.isEmpty) return input;

    final isAppropriate = await ContentModerationService.isAppropriateContent(
      input,
      userId: userId ?? client.auth.currentUser?.id,
    );

    if (!isAppropriate) {
      debugPrint('Content moderation blocked inappropriate content');
      return null;
    }

    return input;
  }

  static Future<void> init() async {
    await dotenv.load(fileName: '.env');
    await Supabase.initialize(
      url: dotenv.env['SUPABASE_URL']!,
      anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
      authFlowType: AuthFlowType.pkce,
    );
    client = Supabase.instance.client;
  }

  static Future<List<Map<String, dynamic>>> getChallenges() async {
    return await client.from('challenges').select('*').order('difficulty');
  }

  static Future<List<Map<String, dynamic>>> getUserChallenges() async {
    final user = client.auth.currentUser;
    if (user == null) return [];
    final result = await client
        .from('challenges')
        .select("*,user_progress: user_progress!inner(*)")
        .eq('user_progress.user_id', user.id)
        .order('difficulty');
    return result;
  }

  static Future<Map<String, dynamic>?> getUserProfile() async {
    final user = client.auth.currentUser;
    if (user == null) return null;
    try {
      final profile =
          await client.from('users').select('*').eq('id', user.id).single();
      return profile;
    } catch (e) {
      return null;
    }
  }

  static Future<void> signUp(String email, String password) async {
    if (!isValidInput(email, isEmail: true)) {
      throw Exception('Invalid email format');
    }
    try {
      final response = await client.auth.signUp(
        email: email,
        password: password,
      );
      final user = response.user;
      if (user != null) {
        await client.from('users').upsert({
          'id': user.id,
          'email': user.email,
          'points': 0,
        });
      }
    } catch (e) {
      rethrow;
    }
  }

  static Future<void> signIn(String email, String password) async {
    try {
      final response = await client.auth.signInWithPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      rethrow;
    }
  }

  static Future<void> signOut() async {
    try {
      await client.auth.signOut();
    } catch (e) {
      rethrow;
    }
  }

  static int xpNeededForLevel(int level) {
    return (100 * (1 + 0.1 * (level - 1))).round();
  }

  static Future<Map<String, dynamic>> getUserStats(String userId) async {
    try {
      final userExists = await client
          .from('users')
          .select('id, points, xp, level, current_streak, longest_streak')
          .eq('id', userId)
          .maybeSingle();
      if (userExists == null) {
        final defaultStats = {
          'points': 0,
          'level': 1,
          'xp': 0,
          'xp_needed': 100,
          'average_accuracy': 0.0,
          'completed_quizzes': 0,
          'challenges_attempted': 0,
          'challenges_solved': 0,
          'current_streak': 0,
          'longest_streak': 0,
        };
        return defaultStats;
      }
      final points = userExists['points'] as int? ?? 0;
      final xp = userExists['xp'] as int? ?? 0;
      final level = userExists['level'] as int? ?? 1;
      final currentStreak = userExists['current_streak'] as int? ?? 0;
      final longestStreak = userExists['longest_streak'] as int? ?? 0;
      final xpNeeded = xpNeededForLevel(level);
      final progressData = await client
          .from('user_progress')
          .select(
              'challenge_id, accuracy, completed, attempts, time_taken_seconds')
          .eq('user_id', userId);
      final attempted = progressData.length;
      final solved = progressData.where((p) => p['completed'] == true).length;
      final completedQuizzes = solved;
      double totalAccuracy = 0;
      int accuracyCount = 0;
      for (var progress in progressData) {
        if (progress['completed'] == true && progress['accuracy'] != null) {
          totalAccuracy += (progress['accuracy'] as num).toDouble();
          accuracyCount++;
        }
      }
      final averageAccuracy =
          accuracyCount > 0 ? totalAccuracy / accuracyCount : 0.0;
      final stats = {
        'points': points,
        'level': level,
        'xp': xp,
        'xp_needed': xpNeeded,
        'average_accuracy': averageAccuracy,
        'completed_quizzes': completedQuizzes,
        'challenges_attempted': attempted,
        'challenges_solved': solved,
        'current_streak': currentStreak,
        'longest_streak': longestStreak,
      };
      return stats;
    } catch (e) {
      return {
        'points': 0,
        'level': 1,
        'xp': 0,
        'xp_needed': 100,
        'average_accuracy': 0.0,
        'completed_quizzes': 0,
        'challenges_attempted': 0,
        'challenges_solved': 0,
      };
    }
  }

  static Future<void> saveProgress(
    String challengeId,
    bool success,
    int timeTakenSeconds,
    double accuracy, {
    List<Map<String, dynamic>>? aiQuestions,
  }) async {
    try {
      final user = client.auth.currentUser;
      if (user == null) return;
      challengeId = sanitizeInput(challengeId);
      if (!isValidInput(challengeId)) {
        throw Exception('Invalid challenge ID format');
      }
      final uuid = Uuid();
      final dbChallengeId =
          uuid.v5(Uuid.NAMESPACE_URL, 'neurobits:${user.id}:$challengeId');
      if (aiQuestions != null) {
        final safeQuestions = aiQuestions.map((q) {
          final newQ = Map<String, dynamic>.from(q);
          if (!newQ.containsKey('solution') || newQ['solution'] == null) {
            newQ['solution'] = newQ['answer'] ?? q['solution'] ?? '';
          }
          if (!newQ.containsKey('type') || newQ['type'] == null) {
            if (newQ.containsKey('options')) {
              newQ['type'] = 'mcq';
            } else if (newQ.containsKey('starter_code')) {
              newQ['type'] = 'code';
            } else {
              newQ['type'] = 'input';
            }
          }
          if (!newQ.containsKey('title') || newQ['title'] == null) {
            newQ['title'] = q['title'] ?? q['question'] ?? '';
          }
          if (!newQ.containsKey('estimated_time_seconds') ||
              newQ['estimated_time_seconds'] == null) {
            newQ['estimated_time_seconds'] = q['estimated_time_seconds'] ?? 30;
          }
          return newQ;
        }).toList();
        final existingChallenge = await client
            .from('challenges')
            .select('id')
            .eq('id', dbChallengeId)
            .maybeSingle();
        if (existingChallenge == null && challengeId.startsWith('ai_')) {
          final firstQuestion =
              safeQuestions.isNotEmpty ? safeQuestions[0] : {};
          final challengeData = {
            'id': dbChallengeId,
            'title': firstQuestion['question'] ?? 'AI Challenge',
            'quiz_name': firstQuestion['quizName'],
            'type': 'quiz',
            'difficulty': firstQuestion['difficulty'] ?? 'Medium',
            'solution': firstQuestion['solution'],
            'options': firstQuestion['options'] != null
                ? jsonEncode(firstQuestion['options'])
                : null,
            'questions': jsonEncode(safeQuestions),
            'question_count': safeQuestions.length,
            'created_at': DateTime.now().toIso8601String(),
          };
          await client.from('challenges').insert(challengeData);
          print(
              'Inserted new AI/custom challenge to challenges table: $dbChallengeId');
        } else if (existingChallenge != null) {
          await client.from('challenges').update({
            'questions': jsonEncode(safeQuestions),
            'question_count': safeQuestions.length,
          }).eq('id', dbChallengeId);
        }
      }
      await client.from('user_progress').upsert({
        'user_id': user.id,
        'challenge_id': dbChallengeId,
        'completed': success,
        'attempts': 1,
        'time_taken_seconds': timeTakenSeconds,
        'accuracy': accuracy,
        'original_id': dbChallengeId,
      });
      if (success) {
        await updateStreak(userId: user.id, activityDate: DateTime.now());
        await _checkAndAwardBadges(user.id,
            accuracy: accuracy, timeTakenSeconds: timeTakenSeconds);
      }
    } catch (e) {
      print('Failed to save progress: $e');
      rethrow;
    }
  }

  static Future<void> saveQuizProgress(
    String quizId,
    String quizName,
    List<Map<String, dynamic>> questions,
    bool success,
    int timeTakenSeconds,
    double accuracy, {
    required int correctCount,
    required int totalCount,
  }) async {
    final user = client.auth.currentUser;
    if (user == null) return;

    final moderatedQuizId = await moderateContent(quizId);
    final moderatedQuizName = await moderateContent(quizName);

    if (moderatedQuizId == null || moderatedQuizName == null) {
      throw Exception('Quiz contains inappropriate content');
    }

    quizId = moderatedQuizId;
    quizName = moderatedQuizName;

    if (!isValidInput(quizId) || !isValidInput(quizName)) {
      throw Exception('Invalid quiz ID or name format');
    }

    final uuid = Uuid();
    final dbQuizId = uuid.v5(Uuid.NAMESPACE_URL,
        'neurobits:${user.id}:${quizName.toLowerCase().trim()}');
    String? topicId;
    try {
      final topicData = await client
          .from('topics')
          .select('id')
          .ilike('name', quizName)
          .maybeSingle();
      if (topicData != null && topicData['id'] != null) {
        topicId = topicData['id'] as String?;
      }
    } catch (e) {
      debugPrint(
          "Error fetching topic ID for '$quizName': $e. Proceeding without topic ID.");
    }
    final existing = await client
        .from('challenges')
        .select('id')
        .eq('id', dbQuizId)
        .maybeSingle();
    Map<String, dynamic> safeQ(Map<String, dynamic> q) {
      final newQ = Map<String, dynamic>.from(q);
      if (!newQ.containsKey('solution') || newQ['solution'] == null) {
        newQ['solution'] = newQ['answer'] ?? q['solution'] ?? '';
      }
      if (!newQ.containsKey('type') || newQ['type'] == null) {
        if (newQ.containsKey('options')) {
          newQ['type'] = 'mcq';
        } else if (newQ.containsKey('starter_code')) {
          newQ['type'] = 'code';
        } else {
          newQ['type'] = 'input';
        }
      }
      if (!newQ.containsKey('title') || newQ['title'] == null) {
        newQ['title'] = q['title'] ?? q['question'] ?? '';
      }
      if (!newQ.containsKey('estimated_time_seconds') ||
          newQ['estimated_time_seconds'] == null) {
        newQ['estimated_time_seconds'] = q['estimated_time_seconds'] ?? 30;
      }
      return newQ;
    }

    final safeQuestions = questions.map(safeQ).toList();
    if (existing == null) {
      final challengeData = {
        'id': dbQuizId,
        'title': quizName,
        'quiz_name': quizName,
        'type': 'quiz',
        'created_at': DateTime.now().toIso8601String(),
        'question':
            safeQuestions.isNotEmpty ? safeQuestions[0]['question'] : null,
        'solution':
            safeQuestions.isNotEmpty ? safeQuestions[0]['solution'] : null,
        'options': safeQuestions.isNotEmpty
            ? jsonEncode(safeQuestions[0]['options'])
            : null,
        'questions': jsonEncode(safeQuestions),
        'question_count': safeQuestions.length,
      };
      await client.from('challenges').insert(challengeData);
    } else {
      await client.from('challenges').update({
        'questions': jsonEncode(safeQuestions),
        'question_count': safeQuestions.length,
      }).eq('id', dbQuizId);
    }
    await client.from('user_progress').upsert({
      'user_id': user.id,
      'challenge_id': dbQuizId,
      'completed': success,
      'attempts': 1,
      'time_taken_seconds': timeTakenSeconds,
      'accuracy': accuracy,
      'original_id': dbQuizId,
    });
    if (topicId != null) {
      await updateUserTopicStats(
        userId: user.id,
        topicId: topicId,
        correct: correctCount,
        total: totalCount,
      );
    } else {
      debugPrint(
          "Skipping user topic stats update because no matching topic ID was found for '$quizName'.");
    }
    if (success) {
      await updateStreak(userId: user.id, activityDate: DateTime.now());
      await _checkAndAwardBadges(user.id,
          accuracy: accuracy, timeTakenSeconds: timeTakenSeconds);
    }
  }

  static Future<void> updateStreak(
      {required String userId, required DateTime activityDate}) async {
    final profile = await client
        .from('users')
        .select('current_streak, longest_streak, last_activity_date')
        .eq('id', userId)
        .single();
    int currentStreak = profile['current_streak'] ?? 0;
    int longestStreak = profile['longest_streak'] ?? 0;
    DateTime? lastActivity = profile['last_activity_date'] != null
        ? DateTime.parse(profile['last_activity_date'])
        : null;
    final now = activityDate.toUtc();
    bool continued =
        lastActivity != null && now.difference(lastActivity).inDays == 1;
    bool reset =
        lastActivity != null && now.difference(lastActivity).inDays > 1;
    if (continued) {
      currentStreak += 1;
      if (currentStreak > longestStreak) longestStreak = currentStreak;
    } else if (reset) {
      currentStreak = 1;
    } else if (lastActivity == null ||
        now.difference(lastActivity).inDays == 0) {
      currentStreak = 1;
    }
    await client.from('users').update({
      'current_streak': currentStreak,
      'longest_streak': longestStreak,
      'last_activity_date': now.toIso8601String(),
    }).eq('id', userId);
  }

  static Future<void> setStreakGoal(
      {required String userId, required int streakGoal}) async {
    await client.from('users').update({
      'streak_goal': streakGoal,
    }).eq('id', userId);
  }

  static Future<void> _checkAndAwardBadges(String userId,
      {double? accuracy, int? timeTakenSeconds}) async {
    const firstChallengeBadgeId = 'first-challenge';
    const streak7BadgeId = 'streak-7';
    const streak30BadgeId = 'streak-30';
    const accuracy90BadgeId = 'accuracy-90';
    const speedsterBadgeId = 'speedster';
    const solved10BadgeId = 'solved-10';
    const solved50BadgeId = 'solved-50';
    const solved100BadgeId = 'solved-100';
    const perfectionistBadgeId = 'perfect-score';
    const comebackBadgeId = 'comeback';
    final profile = await getUserProfile();
    if (profile == null) return;
    final currentStreak = profile['current_streak'] ?? 0;
    final longestStreak = profile['longest_streak'] ?? 0;
    final stats = await getUserStats(userId);
    final solved = stats['challenges_solved'] ?? 0;
    if (currentStreak >= 7) {
      await BadgeService.awardBadgeToUser(
          userId: userId, badgeId: streak7BadgeId);
    }
    if (currentStreak >= 30 || longestStreak >= 30) {
      await BadgeService.awardBadgeToUser(
          userId: userId, badgeId: streak30BadgeId);
    }
    if (solved == 1) {
      await BadgeService.awardBadgeToUser(
          userId: userId, badgeId: firstChallengeBadgeId);
    }
    if (solved >= 10) {
      await BadgeService.awardBadgeToUser(
          userId: userId, badgeId: solved10BadgeId);
    }
    if (solved >= 50) {
      await BadgeService.awardBadgeToUser(
          userId: userId, badgeId: solved50BadgeId);
    }
    if (solved >= 100) {
      await BadgeService.awardBadgeToUser(
          userId: userId, badgeId: solved100BadgeId);
    }
    if ((accuracy ?? 0) == 1.0) {
      await BadgeService.awardBadgeToUser(
          userId: userId, badgeId: perfectionistBadgeId);
    }
    if ((accuracy ?? 0) >= 0.9) {
      await BadgeService.awardBadgeToUser(
          userId: userId, badgeId: accuracy90BadgeId);
    }
    if ((timeTakenSeconds ?? 9999) < 60) {
      await BadgeService.awardBadgeToUser(
          userId: userId, badgeId: speedsterBadgeId);
    }
    final userProgress = await client
        .from('user_progress')
        .select('completed')
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(2);
    if (userProgress.length == 2 &&
        userProgress[1]['completed'] == false &&
        userProgress[0]['completed'] == true) {
      await BadgeService.awardBadgeToUser(
          userId: userId, badgeId: comebackBadgeId);
    }
  }

  static Future<void> saveSessionAnalysis({
    required String userId,
    required String topic,
    required String quizName,
    required String analysis,
    required double accuracy,
    required int totalTime,
  }) async {
    await client.from('session_analysis').insert({
      'user_id': userId,
      'topic': topic,
      'quiz_name': quizName,
      'analysis': analysis,
      'accuracy': accuracy,
      'total_time': totalTime,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  static Future<void> updateUserTopicStats({
    required String userId,
    required String topicId,
    required int correct,
    required int total,
  }) async {
    final now = DateTime.now().toIso8601String();
    final existing = await client
        .from('user_topic_stats')
        .select('attempts, correct, total')
        .eq('user_id', userId)
        .eq('topic_id', topicId)
        .maybeSingle();
    int newAttempts = 1;
    int newCorrect = correct;
    int newTotal = total;
    if (existing != null) {
      newAttempts = (existing['attempts'] as int? ?? 0) + 1;
      newCorrect = (existing['correct'] as int? ?? 0) + correct;
      newTotal = (existing['total'] as int? ?? 0) + total;
    }
    final double avgAccuracy = newTotal > 0 ? newCorrect / newTotal : 0;
    await client.from('user_topic_stats').upsert({
      'user_id': userId,
      'topic_id': topicId,
      'attempts': newAttempts,
      'correct': newCorrect,
      'total': newTotal,
      'avg_accuracy': avgAccuracy,
      'last_attempted': now,
    }, onConflict: 'user_id,topic_id');
  }

  static Future<List<Map<String, dynamic>>> getTrendingTopics(
      {int limit = 5}) async {
    final result = await Supabase.instance.client
        .rpc('get_trending_topics', params: {'limit_param': limit});
    return List<Map<String, dynamic>>.from(result);
  }

  static Future<String> getAdaptiveDifficulty(
      {required String userId, required String topicId}) async {
    try {
      final stats = await client
          .from('user_topic_stats')
          .select('attempts, avg_accuracy, correct, total')
          .eq('user_id', userId)
          .eq('topic_id', topicId)
          .maybeSingle();
      if (stats == null) {
        debugPrint(
            '[getAdaptiveDifficulty] No stats found for user $userId and topic ID $topicId');
        return 'Medium';
      }
      final attempts = stats['attempts'] as int? ?? 0;
      final avgAccuracy = stats['avg_accuracy'] as double? ?? 0.0;
      final correct = stats['correct'] as int? ?? 0;
      final total = stats['total'] as int? ?? 0;
      debugPrint(
          '[getAdaptiveDifficulty] User $userId has $attempts attempts with $correct/$total correct (${(avgAccuracy * 100).toStringAsFixed(1)}% accuracy) for topic ID $topicId');
      if (attempts < 3) {
        return 'Easy';
      } else if (avgAccuracy >= 0.8) {
        return 'Hard';
      } else if (avgAccuracy >= 0.5) {
        return 'Medium';
      } else {
        return 'Easy';
      }
    } catch (e) {
      debugPrint('[getAdaptiveDifficulty] Error: $e');
      return 'Medium';
    }
  }

  static Future<void> setAdaptiveDifficultyPreference(
      {required String userId, required bool enabled}) async {
    await client
        .from('users')
        .update({'adaptive_difficulty_enabled': enabled}).eq('id', userId);
  }

  static Future<bool> getAdaptiveDifficultyPreference(
      {required String userId}) async {
    final profile = await client
        .from('users')
        .select('adaptive_difficulty_enabled')
        .eq('id', userId)
        .maybeSingle();
    if (profile == null || profile['adaptive_difficulty_enabled'] == null) {
      return true;
    }
    return profile['adaptive_difficulty_enabled'] as bool;
  }

  static Future<Map<String, dynamic>?> getUserById(String userId) async {
    final user = await client
        .from('users')
        .select('id, username, email, xp, level')
        .eq('id', userId)
        .maybeSingle();
    return user;
  }

  static Future<List<Map<String, dynamic>>> searchUsers(String query,
      {String? excludeUserId}) async {
    final result = await client
        .from('users')
        .select('id, username, email')
        .ilike('username', '%$query%')
        .neq('id', excludeUserId ?? '')
        .limit(10);
    return List<Map<String, dynamic>>.from(result);
  }

  static Future<bool> checkAndAdvancePathStep(String userId) async {
    try {
      final userPathRes = await client
          .from('user_learning_paths')
          .select(
              'id, path_id, current_step, learning_paths(id, name), ai_path_json')
          .eq('user_id', userId)
          .is_('completed_at', null)
          .maybeSingle();
      if (userPathRes == null) {
        debugPrint(
            '[checkAndAdvancePathStep] No active learning path found for user $userId');
        return false;
      }
      final userPathId = userPathRes['id'];
      final currentStep = userPathRes['current_step'] as int? ?? 1;
      double passThreshold = 0.75;
      final Map<String, dynamic>? meta =
          (userPathRes['ai_path_json'] as Map<String, dynamic>?);
      if (meta != null && meta['threshold'] != null) {
        passThreshold = (meta['threshold'] as num).toDouble();
      }
      if (passThreshold < 0.5) passThreshold = 0.5;
      final pathId = userPathRes['path_id'];
      final learningPathName =
          userPathRes['learning_paths']?['name'] ?? 'Unknown Path';
      debugPrint(
          '[checkAndAdvancePathStep] User $userId is on step $currentStep of path $userPathId ($learningPathName)');
      final currentStepTopic = await client
          .from('learning_path_topics')
          .select('topic')
          .eq('path_id', pathId)
          .eq('step_number', currentStep)
          .maybeSingle();
      if (currentStepTopic == null || currentStepTopic['topic'] == null) {
        debugPrint(
            '[checkAndAdvancePathStep] No topic found for step $currentStep in path $pathId');
        return false;
      }
      final String currentTopicName =
          currentStepTopic['topic'] as String? ?? 'Unknown Topic';
      final topicData = await client
          .from('topics')
          .select('id')
          .eq('name', currentTopicName)
          .maybeSingle();
      if (topicData == null || topicData['id'] == null) {
        debugPrint(
            '[checkAndAdvancePathStep] No topic data found for name $currentTopicName');
        return false;
      }
      final currentTopicId = topicData['id'] as String;
      final topicStats = await client
          .from('user_topic_stats')
          .select('attempts, correct, total')
          .eq('user_id', userId)
          .eq('topic_id', currentTopicId)
          .maybeSingle();
      final int correct = topicStats?['correct'] ?? 0;
      final int total = topicStats?['total'] ?? 0;
      final double accuracy = total > 0 ? correct / total : 0.0;
      debugPrint(
          '[checkAndAdvancePathStep] Topic stats for "$currentTopicName": correct=$correct, total=$total, accuracy=${accuracy.toStringAsFixed(2)}');
      final bool hasPassedCurrentTopic = accuracy >= passThreshold;
      if (hasPassedCurrentTopic) {
        debugPrint(
            '[checkAndAdvancePathStep] User $userId has passed the current topic "$currentTopicName" (Required accuracy: ${passThreshold.toStringAsFixed(2)}%). Advancing step...');
        await client
            .from('user_path_challenges')
            .update({'completed': true})
            .eq('user_path_id', userPathId)
            .eq('day', currentStep);
        final nextStep = currentStep + 1;
        final stepsCountResponse = await client
            .from('learning_path_topics')
            .select('*', const FetchOptions(count: CountOption.exact))
            .eq('path_id', pathId);
        final totalSteps = stepsCountResponse.count ?? 0;
        if (nextStep > totalSteps) {
          debugPrint(
              '[checkAndAdvancePathStep] User $userId completed the final step ($currentStep). Marking path $userPathId as complete.');
          await client.from('user_learning_paths').update({
            'current_step': currentStep,
            'is_complete': true,
            'completed_at': DateTime.now().toIso8601String()
          }).eq('id', userPathId);
        } else {
          await client
              .from('user_learning_paths')
              .update({'current_step': nextStep}).eq('id', userPathId);
          debugPrint(
              '[checkAndAdvancePathStep] Advanced user $userId to step $nextStep for path $userPathId.');
        }
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('[checkAndAdvancePathStep] Error: $e');
      return false;
    }
  }

  static Future<bool> updateUserProfile(
      Map<String, dynamic> profileData) async {
    final user = client.auth.currentUser;
    if (user == null) return false;

    final moderatedData =
        await ContentModerationService.moderateUserProfileData(
      profileData,
      userId: user.id,
    );
    if (moderatedData == null) {
      return false;
    }

    try {
      await client.from('users').update(moderatedData).eq('id', user.id);
      return true;
    } catch (e) {
      debugPrint('Failed to update user profile: $e');
      return false;
    }
  }
}
