import 'dart:async';

import 'package:neurobits/services/convex_client_service.dart';

class PathRepository {
  final ConvexClientService _client;
  static const Duration _heavyPathMutationTimeout = Duration(seconds: 180);
  static const Duration _pathReadTimeout = Duration(seconds: 35);

  PathRepository(this._client);

  Future<List<Map<String, dynamic>>> listSelectable() async {
    final result = await _client.query(name: 'paths:listSelectable');
    return toMapList(result);
  }

  Future<Map<String, dynamic>?> getActive() async {
    try {
      final result = await _client.query(
        name: 'paths:getActive',
        timeout: _pathReadTimeout,
      );
      return toMapOrNull(result);
    } on TimeoutException {
      final retry = await _client.query(name: 'paths:getActive');
      return toMapOrNull(retry);
    }
  }

  Future<List<Map<String, dynamic>>> listCompleted({int? limit}) async {
    final args = <String, dynamic>{};
    if (limit != null) args['limit'] = limit;

    final result = await _client.query(
      name: 'paths:listCompleted',
      args: args,
    );
    return toMapList(result);
  }

  Future<List<Map<String, dynamic>>> listChallengesForPath({
    required String userPathId,
  }) async {
    try {
      final result = await _client.query(
        name: 'paths:listChallengesForPath',
        args: {'userPathId': userPathId},
        timeout: _pathReadTimeout,
      );
      return toMapList(result);
    } on TimeoutException {
      final retry = await _client.query(
        name: 'paths:listChallengesForPath',
        args: {'userPathId': userPathId},
      );
      return toMapList(retry);
    }
  }

  Future<String> selectTemplatePath({required String pathId}) async {
    final result = await _client.mutation(
      name: 'paths:selectTemplatePath',
      args: {'pathId': pathId},
      timeout: _heavyPathMutationTimeout,
    );
    return result as String;
  }

  Future<void> selectFreeMode() async {
    await _client.mutation(name: 'paths:selectFreeMode');
  }
  
  Future<String> createCustomPathFromAi({
    required String topic,
    required String level,
    required int durationDays,
    required int dailyMinutes,
    required String aiPathJson,
    String? pathDescription,
  }) async {
    final result = await _client.mutation(
      name: 'paths:createCustomPathFromAi',
      args: {
        'topic': topic,
        'level': level,
        'durationDays': durationDays,
        'dailyMinutes': dailyMinutes,
        'aiPathJson': aiPathJson,
        if (pathDescription != null) 'pathDescription': pathDescription,
      },
      timeout: _heavyPathMutationTimeout,
    );
    return result as String;
  }

  Future<void> tweakActivePathFromAi({
    required int durationDays,
    required int dailyMinutes,
    required String aiPathJson,
    String? pathDescription,
  }) async {
    await _client.mutation(
      name: 'paths:tweakActivePathFromAi',
      args: {
        'durationDays': durationDays,
        'dailyMinutes': dailyMinutes,
        'aiPathJson': aiPathJson,
        if (pathDescription != null) 'pathDescription': pathDescription,
      },
      timeout: _heavyPathMutationTimeout,
    );
  }

  Future<List<Map<String, dynamic>>> listIncomplete({int? limit}) async {
    final args = <String, dynamic>{};
    if (limit != null) args['limit'] = limit;
    final result = await _client.query(
      name: 'paths:listIncomplete',
      args: args,
    );
    return toMapList(result);
  }

  Future<Map<String, dynamic>> checkAndAdvanceStep() async {
    final result = await _client.mutation(name: 'paths:checkAndAdvanceStep');
    return toMap(result);
  }

  Future<void> markPathChallengeComplete({
    required String challengeId,
    required double accuracy,
  }) async {
    await _client.mutation(
      name: 'paths:markPathChallengeComplete',
      args: {'challengeId': challengeId, 'accuracy': accuracy},
    );
  }

  Future<void> setActivePath({required String userPathId}) async {
    await _client.mutation(
      name: 'paths:setActivePath',
      args: {'userPathId': userPathId},
    );
  }
}
