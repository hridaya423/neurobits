import 'package:neurobits/services/convex_client_service.dart';

class ProgressRepository {
  final ConvexClientService _client;

  ProgressRepository(this._client);

  Future<Map<String, dynamic>> recordQuizCompletion({
    required String challengeId,
    required bool completed,
    required int attempts,
    required int timeTakenSeconds,
    double? accuracy,
    List<Map<String, dynamic>>? answers,
  }) async {
    final args = <String, dynamic>{
      'challengeId': challengeId,
      'completed': completed,
      'attempts': attempts,
      'timeTakenSeconds': timeTakenSeconds,
      'timezoneOffsetMinutes': -DateTime.now().timeZoneOffset.inMinutes,
    };
    if (accuracy != null) args['accuracy'] = accuracy;
    if (answers != null) args['answers'] = answers;

    final result = await _client.mutation(
      name: 'progress:recordQuizCompletion',
      args: args,
    );
    return toMap(result);
  }

  Future<Map<String, dynamic>> getMyStats() async {
    final result = await _client.query(name: 'progress:getMyStats');
    return toMap(result);
  }

  Future<Map<String, dynamic>> getChallengeAnalytics({
    required String challengeId,
  }) async {
    final result = await _client.query(
      name: 'progress:getChallengeAnalytics',
      args: {'challengeId': challengeId},
    );
    return toMap(result);
  }

  Future<Map<String, dynamic>> getTopicAnalytics({
    required String topic,
  }) async {
    final result = await _client.query(
      name: 'progress:getTopicAnalytics',
      args: {'topic': topic},
    );
    return toMap(result);
  }
}
