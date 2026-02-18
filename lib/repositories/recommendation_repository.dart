import 'package:neurobits/services/convex_client_service.dart';

class RecommendationRepository {
  final ConvexClientService _client;

  RecommendationRepository(this._client);

  Future<Map<String, dynamic>?> getCached() async {
    final result = await _client.query(name: 'recommendations:getCached');
    return toMapOrNull(result);
  }

  Future<void> upsertCached({
    List<Map<String, dynamic>>? practiceRecs,
    List<Map<String, dynamic>>? suggestedTopics,
    int? basedOnLastAttemptAt,
    int? basedOnPreferencesUpdatedAt,
    String? source,
  }) async {
    final args = <String, dynamic>{};
    if (practiceRecs != null) {
      args['practiceRecs'] = practiceRecs
          .map((rec) => _sanitizePracticeRec(rec))
          .where((rec) => rec.isNotEmpty)
          .toList();
    }
    if (suggestedTopics != null) {
      args['suggestedTopics'] = suggestedTopics
          .map((topic) => _sanitizeSuggestedTopic(topic))
          .where((topic) => topic.isNotEmpty)
          .toList();
    }
    if (basedOnLastAttemptAt != null) {
      args['basedOnLastAttemptAt'] = basedOnLastAttemptAt;
    }
    if (basedOnPreferencesUpdatedAt != null) {
      args['basedOnPreferencesUpdatedAt'] = basedOnPreferencesUpdatedAt;
    }
    if (source != null) args['source'] = source;

    await _client.mutation(name: 'recommendations:upsert', args: args);
  }

  Map<String, dynamic> _sanitizePracticeRec(Map<String, dynamic> rec) {
    final topicName = rec['topicName']?.toString() ?? '';
    if (topicName.isEmpty) return {};
    final cleaned = <String, dynamic>{'topicName': topicName};

    final accuracy = rec['accuracy'];
    if (accuracy is num) cleaned['accuracy'] = accuracy.toDouble();

    final attempts = rec['attempts'];
    if (attempts is num) cleaned['attempts'] = attempts.toDouble();

    final lastAttemptedAt = rec['lastAttemptedAt'];
    if (lastAttemptedAt is num) {
      cleaned['lastAttemptedAt'] = lastAttemptedAt.toDouble();
    }

    final reason = rec['reason']?.toString();
    if (reason != null && reason.isNotEmpty) cleaned['reason'] = reason;

    final isSuggested = rec['isSuggested'];
    if (isSuggested is bool) cleaned['isSuggested'] = isSuggested;

    return cleaned;
  }

  Map<String, dynamic> _sanitizeSuggestedTopic(Map<String, dynamic> topic) {
    final name = topic['name']?.toString() ?? '';
    if (name.isEmpty) return {};
    final cleaned = <String, dynamic>{'name': name};

    final reason = topic['reason']?.toString();
    if (reason != null && reason.isNotEmpty) cleaned['reason'] = reason;

    final related = topic['relatedTopics'];
    if (related is List) {
      cleaned['relatedTopics'] = related.map((t) => t.toString()).toList();
    } else {
      cleaned['relatedTopics'] = <String>[];
    }

    return cleaned;
  }
}
