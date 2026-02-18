import 'package:neurobits/services/convex_client_service.dart';

class UserRepository {
  final ConvexClientService _client;

  UserRepository(this._client);

  Future<Map<String, dynamic>?> getMe() async {
    final result = await _client.query(name: 'users:getMe');
    return toMapOrNull(result);
  }

  Future<String> ensureCurrent() async {
    final result = await _client.mutation(name: 'users:ensureCurrent');
    return result as String;
  }

  Future<void> updateProfile({
    String? username,
    int? streakGoal,
  }) async {
    final args = <String, dynamic>{};
    if (username != null) args['username'] = username;
    if (streakGoal != null) args['streakGoal'] = streakGoal;

    await _client.mutation(name: 'users:updateProfile', args: args);
  }

  Future<void> updateSettings({
    bool? adaptiveDifficultyEnabled,
    bool? remindersEnabled,
    bool? streakNotifications,
  }) async {
    final args = <String, dynamic>{};
    if (adaptiveDifficultyEnabled != null) {
      args['adaptiveDifficultyEnabled'] = adaptiveDifficultyEnabled;
    }
    if (remindersEnabled != null) args['remindersEnabled'] = remindersEnabled;
    if (streakNotifications != null) {
      args['streakNotifications'] = streakNotifications;
    }

    await _client.mutation(name: 'users:updateSettings', args: args);
  }

  Future<void> completeOnboarding() async {
    await _client.mutation(name: 'users:completeOnboarding');
  }
}
