import 'package:neurobits/services/convex_client_service.dart';

class ChallengeRepository {
  final ConvexClientService _client;

  ChallengeRepository(this._client);

  Future<Map<String, dynamic>?> getById(String challengeId) async {
    final result = await _client.query(
      name: 'challenges:getById',
      args: {'challengeId': challengeId},
    );
    return toMapOrNull(result);
  }

  Future<List<Map<String, dynamic>>> listRecent({int? limit}) async {
    final args = <String, dynamic>{};
    if (limit != null) args['limit'] = limit;

    final result =
        await _client.query(name: 'challenges:listRecent', args: args);
    return toMapList(result);
  }

  Future<List<Map<String, dynamic>>> listMostSolved({int? limit}) async {
    final args = <String, dynamic>{};
    if (limit != null) args['limit'] = limit;

    final result =
        await _client.query(name: 'challenges:listMostSolved', args: args);
    return toMapList(result);
  }

  Future<List<Map<String, dynamic>>> listByCategory({
    required String categoryId,
    String? difficulty,
    int? limit,
  }) async {
    final args = <String, dynamic>{'categoryId': categoryId};
    if (difficulty != null) args['difficulty'] = difficulty;
    if (limit != null) args['limit'] = limit;

    final result =
        await _client.query(name: 'challenges:listByCategory', args: args);
    return toMapList(result);
  }

  Future<List<Map<String, dynamic>>> listByTopic({
    required String topicId,
    int? limit,
  }) async {
    final args = <String, dynamic>{'topicId': topicId};
    if (limit != null) args['limit'] = limit;

    final result =
        await _client.query(name: 'challenges:listByTopic', args: args);
    return toMapList(result);
  }

  Future<String> createAdHoc({
    required String topic,
    String? difficulty,
    int? questionCount,
    String? quizName,
  }) async {
    final args = <String, dynamic>{'topic': topic};
    if (difficulty != null) args['difficulty'] = difficulty;
    if (questionCount != null) args['questionCount'] = questionCount;
    if (quizName != null) args['quizName'] = quizName;

    final result = await _client.mutation(
      name: 'challenges:createAdHoc',
      args: args,
    );
    return result.toString();
  }
}
