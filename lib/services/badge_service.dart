import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';

class BadgeService {
  static final SupabaseClient client = Supabase.instance.client;
  static Future<void> awardBadgeToUser({
    required String userId,
    required String badgeId,
  }) async {
    final existing = await client
        .from('user_badges')
        .select('badge_id')
        .eq('user_id', userId)
        .eq('badge_id', badgeId)
        .maybeSingle();
    if (existing == null) {
      await client.from('user_badges').insert({
        'user_id': userId,
        'badge_id': badgeId,
      });
    }
  }

  static Future<List<Map<String, dynamic>>> getUserBadges(String userId) async {
    final result = await client
        .from('user_badges')
        .select('*, badge:badges(*)')
        .eq('user_id', userId);
    return List<Map<String, dynamic>>.from(result);
  }

  static Future<List<Map<String, dynamic>>> getAllBadges() async {
    final result = await client.from('badges').select('*');
    return List<Map<String, dynamic>>.from(result);
  }
}
