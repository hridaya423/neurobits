import 'package:neurobits/services/convex_client_service.dart';

class PreferenceRepository {
  final ConvexClientService _client;

  PreferenceRepository(this._client);

  Future<Map<String, dynamic>?> getMine() async {
    final result = await _client.query(name: 'preferences:getMine');
    return toMapOrNull(result);
  }

  Future<void> upsertMine({
    int? defaultNumQuestions,
    String? defaultDifficulty,
    int? defaultTimePerQuestionSec,
    bool? timedModeEnabled,
    bool? quickStartEnabled,
    bool? hintsEnabled,
    bool? imageQuestionsEnabled,
    List<String>? allowedChallengeTypes,
    String? learningGoal,
    String? experienceLevel,
    String? learningStyle,
    int? timeCommitmentMinutes,
    List<String>? interestedTopics,
    List<String>? preferredQuestionTypes,
  }) async {
    final args = <String, dynamic>{};
    if (defaultNumQuestions != null) {
      args['defaultNumQuestions'] = defaultNumQuestions;
    }
    if (defaultDifficulty != null) {
      args['defaultDifficulty'] = defaultDifficulty;
    }
    if (defaultTimePerQuestionSec != null) {
      args['defaultTimePerQuestionSec'] = defaultTimePerQuestionSec;
    }
    if (timedModeEnabled != null) args['timedModeEnabled'] = timedModeEnabled;
    if (quickStartEnabled != null) {
      args['quickStartEnabled'] = quickStartEnabled;
    }
    if (hintsEnabled != null) {
      args['hintsEnabled'] = hintsEnabled;
    }
    if (imageQuestionsEnabled != null) {
      args['imageQuestionsEnabled'] = imageQuestionsEnabled;
    }
    if (allowedChallengeTypes != null) {
      args['allowedChallengeTypes'] = allowedChallengeTypes;
    }
    if (learningGoal != null) args['learningGoal'] = learningGoal;
    if (experienceLevel != null) args['experienceLevel'] = experienceLevel;
    if (learningStyle != null) args['learningStyle'] = learningStyle;
    if (timeCommitmentMinutes != null) {
      args['timeCommitmentMinutes'] = timeCommitmentMinutes;
    }
    if (interestedTopics != null) args['interestedTopics'] = interestedTopics;
    if (preferredQuestionTypes != null) {
      args['preferredQuestionTypes'] = preferredQuestionTypes;
    }

    await _client.mutation(name: 'preferences:upsertMine', args: args);
  }
}
