import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:neurobits/services/user_analytics_service.dart';

class RecommendationCacheService {
  static const String _cacheKey = 'personalized_recommendations_cache';
  static const String _cacheTimeKey = 'recommendations_cache_time';
  static const String _domainCacheKey = 'topic_domain_cache';
  static const Duration _cacheDuration = Duration(hours: 1);

  static Future<List<PersonalizedRecommendation>?> getCachedRecommendations(
      String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheTimeStr = prefs.getString('${_cacheTimeKey}_$userId');
      final cachedDataStr = prefs.getString('${_cacheKey}_$userId');

      if (cacheTimeStr == null || cachedDataStr == null) {
        return null;
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

  static Future<void> cacheRecommendations(
      String userId, List<PersonalizedRecommendation> recommendations) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now().toIso8601String();
      final jsonData = jsonEncode(
          recommendations.map((r) => _recommendationToJson(r)).toList());

      await prefs.setString('${_cacheTimeKey}_$userId', now);
      await prefs.setString('${_cacheKey}_$userId', jsonData);
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
      await prefs.remove('${_cacheTimeKey}_$userId');
    } catch (e) {
    }
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
