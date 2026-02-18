import 'package:neurobits/services/convex_client_service.dart';

class SessionAnalysisRepository {
  final ConvexClientService _client;
  static const Duration _saveTimeout = Duration(seconds: 12);

  SessionAnalysisRepository(this._client);

  Future<String> save({
    String? topic,
    String? quizName,
    required String analysis,
    double? accuracy,
    double? totalTime,
  }) async {
    final args = <String, dynamic>{
      'analysis': analysis,
    };
    if (topic != null) args['topic'] = topic;
    if (quizName != null) args['quizName'] = quizName;
    if (accuracy != null) args['accuracy'] = accuracy;
    if (totalTime != null) args['totalTime'] = totalTime;

    final result = await _client.mutation(
      name: 'sessionAnalysis:save',
      args: args,
      timeout: _saveTimeout,
    );
    return result as String;
  }

  Future<List<Map<String, dynamic>>> listMine({int? limit}) async {
    final args = <String, dynamic>{};
    if (limit != null) args['limit'] = limit;

    final result = await _client.query(
      name: 'sessionAnalysis:listMine',
      args: args,
    );
    return toMapList(result);
  }
}
