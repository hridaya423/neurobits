import 'dart:convert';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:neurobits/services/user_analytics_service.dart';

class RecommendationCacheService {
  static const String _cacheKey = 'personalized_recommendations_cache';
  static const String _cacheTimeKey = 'recommendations_cache_time';
  static const String _domainCacheKey = 'topic_domain_cache';
  static const Duration _cacheDuration = Duration(hours: 1);

  static Future<List<PersonalizedRecommendation>?> getCachedRecommendations(
    String userId, {
    Map<String, dynamic>? userPreferences,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheTimeStr = prefs.getString('${_cacheTimeKey}_$userId');
      final cachedDataStr = prefs.getString('${_cacheKey}_$userId');

      if (cacheTimeStr == null || cachedDataStr == null) {
        return null;
      }

      if (userPreferences != null) {
        final prefsStr = prefs.getString('${_cacheKey}_prefs_$userId');
        if (prefsStr == null) {
          return null;
        }
        final Map<String, dynamic> cachedPrefs =
            jsonDecode(prefsStr) as Map<String, dynamic>;
        if (!_matchesPreferences(userPreferences, cachedPrefs)) {
          return null;
        }
      }

      final cacheTime = DateTime.parse(cacheTimeStr);
      final now = DateTime.now();

      if (now.difference(cacheTime) > _cacheDuration) {
        return null;
      }

      final List<dynamic> cachedData = jsonDecode(cachedDataStr);
      return cachedData.map((json) => _recommendationFromJson(json)).toList();
    } catch (e) {
      return null;
    }
  }

  static Future<void> cacheRecommendations(String userId,
      List<PersonalizedRecommendation> recommendations,
      {Map<String, dynamic>? userPreferences}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now().toIso8601String();
      final jsonData = jsonEncode(
          recommendations.map((r) => _recommendationToJson(r)).toList());

      await prefs.setString('${_cacheTimeKey}_$userId', now);
      await prefs.setString('${_cacheKey}_$userId', jsonData);
      if (userPreferences != null) {
        await prefs.setString(
            '${_cacheKey}_prefs_$userId', jsonEncode(userPreferences));
      }
    } catch (e) {
    }
  }

  static Future<String?> getCachedTopicDomain(String topicName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheData = prefs.getString(_domainCacheKey);
      if (cacheData == null) return null;

      final Map<String, dynamic> cache = jsonDecode(cacheData);
      return cache[topicName] as String?;
    } catch (e) {
      return null;
    }
  }

  static Future<void> cacheTopicDomain(String topicName, String domain) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheData = prefs.getString(_domainCacheKey) ?? '{}';
      final Map<String, dynamic> cache = jsonDecode(cacheData);

      cache[topicName] = domain;

      await prefs.setString(_domainCacheKey, jsonEncode(cache));
    } catch (e) {
    }
  }

  static Future<void> clearCache(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('${_cacheKey}_$userId');
      await prefs.remove('${_cacheKey}_prefs_$userId');
      await prefs.remove('${_cacheTimeKey}_$userId');
    } catch (e) {
    }
  }

  static bool _matchesPreferences(
    Map<String, dynamic> current,
    Map<String, dynamic> cached,
  ) {
    final currentGoal = current['learning_goal']?.toString();
    final cachedGoal = cached['learning_goal']?.toString();
    final currentLevel = current['experience_level']?.toString();
    final cachedLevel = cached['experience_level']?.toString();
    final currentStyle = current['learning_style']?.toString();
    final cachedStyle = cached['learning_style']?.toString();
    final currentTime = current['time_commitment_minutes'] ??
        current['time_commitment'] ??
        0;
    final cachedTime = cached['time_commitment_minutes'] ??
        cached['time_commitment'] ??
        0;
    final currentTopics =
        List<String>.from(current['interested_topics'] ?? const []);
    final cachedTopics =
        List<String>.from(cached['interested_topics'] ?? const []);

    if (currentGoal != cachedGoal ||
        currentLevel != cachedLevel ||
        currentStyle != cachedStyle ||
        currentTime.toString() != cachedTime.toString()) {
      return false;
    }

    if (currentTopics.length != cachedTopics.length) {
      return false;
    }

    final currentSet = currentTopics.map((e) => e.toLowerCase()).toSet();
    final cachedSet = cachedTopics.map((e) => e.toLowerCase()).toSet();
    return currentSet.containsAll(cachedSet);
  }

  static Map<String, dynamic> _recommendationToJson(
      PersonalizedRecommendation rec) {
    return {
      'topicId': rec.topicId,
      'topicName': rec.topicName,
      'topicDescription': rec.topicDescription,
      'category': rec.category,
      'contentType': rec.contentType,
      'reason': rec.reason,
      'score': rec.score,
      'difficulty': rec.difficulty,
      'estimatedTime': rec.estimatedTime,
      'semanticRelevance': rec.semanticRelevance,
      'challengeOptimality': rec.challengeOptimality,
      'motivationAlignment': rec.motivationAlignment,
      'learningPsychology': rec.learningPsychology,
      'behavioralInsight': rec.behavioralInsight,
      'skillTransferPotential': rec.skillTransferPotential,
      'engagementPrediction': rec.engagementPrediction,
    };
  }

  static PersonalizedRecommendation _recommendationFromJson(
      Map<String, dynamic> json) {
    return PersonalizedRecommendation(
      topicId: json['topicId'] as String,
      topicName: json['topicName'] as String,
      topicDescription: json['topicDescription'] as String?,
      category: json['category'] as String,
      contentType: json['contentType'] as String?,
      reason: json['reason'] as String,
      score: (json['score'] as num).toDouble(),
      difficulty: json['difficulty'] as String,
      estimatedTime: json['estimatedTime'] as int,
      semanticRelevance: (json['semanticRelevance'] as num?)?.toDouble(),
      challengeOptimality: (json['challengeOptimality'] as num?)?.toDouble(),
      motivationAlignment: (json['motivationAlignment'] as num?)?.toDouble(),
      learningPsychology: json['learningPsychology'] as String?,
      behavioralInsight: json['behavioralInsight'] as String?,
      skillTransferPotential:
          (json['skillTransferPotential'] as num?)?.toDouble(),
      engagementPrediction: (json['engagementPrediction'] as num?)?.toDouble(),
    );
  }
}
