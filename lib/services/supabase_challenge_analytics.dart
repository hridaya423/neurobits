import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
class ChallengeAnalyticsService {
  static final SupabaseClient client = Supabase.instance.client;
  static Future<Map<String, dynamic>?> getChallengeAnalytics({
    required String userId,
    required String challengeId,
  }) async {
    try {
      final results = await client
          .from('user_progress')
          .select('attempts, time_taken_seconds, accuracy')
          .eq('user_id', userId)
          .eq('challenge_id', challengeId);
      if (results == null || results.isEmpty) {
        return {
          'attempts': 0,
          'best_time': 0,
          'best_accuracy': 0.0,
        };
      }
      double bestAccuracy = 0.0;
      int attempts = 0;
      int bestTime = 0;
      for (final row in results) {
        attempts++;
        final acc = (row['accuracy'] as num?)?.toDouble() ?? 0.0;
        final time = (row['time_taken_seconds'] as num?)?.toInt() ?? 0;
        if (acc > bestAccuracy) {
          bestAccuracy = acc;
          bestTime = time;
        }
      }
      return {
        'attempts': attempts,
        'best_time': bestTime,
        'best_accuracy': bestAccuracy,
      };
    } catch (e) {
      debugPrint('Error fetching challenge analytics: $e');
      return {
        'attempts': 0,
        'best_time': 0,
        'best_accuracy': 0.0,
      };
    }
  }
}