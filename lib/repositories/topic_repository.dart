import 'package:neurobits/services/convex_client_service.dart';

class TopicRepository {
  final ConvexClientService _client;

  TopicRepository(this._client);

  Future<List<Map<String, dynamic>>> listAll() async {
    final result = await _client.query(name: 'topics:listAll');
    return toMapList(result);
  }

  Future<List<Map<String, dynamic>>> searchRelated({
    required String topic,
    int? limit,
  }) async {
    final args = <String, dynamic>{'topic': topic};
    if (limit != null) args['limit'] = limit;

    final result =
        await _client.query(name: 'topics:searchRelated', args: args);
    return toMapList(result);
  }

  Future<List<Map<String, dynamic>>> getTrending({int? limit}) async {
    final args = <String, dynamic>{};
    if (limit != null) args['limit'] = limit;

    final result = await _client.query(name: 'topics:getTrending', args: args);
    return toMapList(result);
  }

  Future<Map<String, dynamic>> getAdaptiveDifficultyForTopic({
    required String topicId,
  }) async {
    final result = await _client.query(
      name: 'topics:getAdaptiveDifficultyForTopic',
      args: {'topicId': topicId},
    );
    return toMap(result);
  }
}
