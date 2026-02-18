import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:neurobits/services/ai_service.dart';
import 'package:neurobits/services/convex_client_service.dart';
import 'package:neurobits/core/providers.dart';

class ChallengeLoaderScreen extends ConsumerStatefulWidget {
  final dynamic challengeData;
  const ChallengeLoaderScreen({required this.challengeData, super.key});
  @override
  ConsumerState<ChallengeLoaderScreen> createState() =>
      _ChallengeLoaderScreenState();
}

class _ChallengeLoaderScreenState extends ConsumerState<ChallengeLoaderScreen> {
  Future<List<Map<String, dynamic>>>? _questionsFuture;
  Map<String, dynamic>? _parsedChallengeData;
  bool _errorLoading = false;
  String _errorMessage = '';
  bool _hasHandledNavigation = false;
  bool _hasNavigated = false;
  String _generateRouteId() {
    return DateTime.now().microsecondsSinceEpoch.toString();
  }

  List<String>? _normalizeOptions(dynamic options) {
    if (options is! List) return null;
    final normalized = options
        .map((e) => e is String
            ? e
            : (e is Map ? e['text']?.toString() : e?.toString()))
        .whereType<String>()
        .toList();
    return normalized;
  }

  Map<String, dynamic> _normalizeQuestion(Map<String, dynamic> q) {
    final normalized = Map<String, dynamic>.from(q);
    final optionsRaw = normalized['options'];
    final options = _normalizeOptions(optionsRaw);
    if (options != null && options.isNotEmpty) {
      normalized['options'] = options;
      final answer = normalized['answer'] ?? normalized['solution'];
      if (answer == null) {
        final correctAnswer = normalized['correctAnswer'];
        if (correctAnswer is int &&
            correctAnswer >= 0 &&
            correctAnswer < options.length) {
          normalized['answer'] = options[correctAnswer];
        }
        if (optionsRaw is List) {
          final correct = optionsRaw
              .whereType<Map>()
              .firstWhere((e) => e['isCorrect'] == true, orElse: () => {});
          if (correct.isNotEmpty && correct['text'] != null) {
            normalized['answer'] = correct['text'].toString();
          }
        }
      } else if (answer is int) {
        if (answer >= 0 && answer < options.length) {
          normalized['answer'] = options[answer];
        }
      }
    }
    return normalized;
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _hasNavigated = true;
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_hasHandledNavigation || _hasNavigated) return;
    final uri = GoRouterState.of(context).uri.toString();
    if (uri.endsWith('_loaded')) {
      _hasNavigated = true;
      return;
    }

    final data = widget.challengeData;
    if (data is Map<String, dynamic> &&
        isConvexList(data['questions']) &&
        toList(data['questions']).isNotEmpty) {
      _hasHandledNavigation = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final challengeId = data['_id'] ?? data['id'] ?? _generateRouteId();
        final extra = Map<String, dynamic>.from(data);
        final rawQuestions = data['questions'];
        if (isConvexList(rawQuestions)) {
          extra['questions'] = toList(rawQuestions)
              .map((e) => _normalizeQuestion(toMap(e)))
              .toList();
        }
        extra['userPathChallengeId'] ??=
            data['user_path_challenge_id']?.toString();
        if (_hasNavigated) return;
        _hasNavigated = true;
        context.go(
          '/challenge/$challengeId/_loaded',
          extra: extra,
        );
      });
      return;
    }
    _loadChallenge();
  }

  Future<void> _loadChallenge() async {
    try {
      if (widget.challengeData is String) {
        _parsedChallengeData = jsonDecode(widget.challengeData);
      } else if (widget.challengeData is Map<String, dynamic>) {
        _parsedChallengeData = widget.challengeData;
      }
      List<Map<String, dynamic>>? preloadedQuestions;
      if (_parsedChallengeData != null) {
        if (isConvexList(_parsedChallengeData!['questions'])) {
          preloadedQuestions = toList(_parsedChallengeData!['questions'])
              .map((e) => _normalizeQuestion(toMap(e)))
              .toList();
        }
        if (preloadedQuestions == null || preloadedQuestions.isEmpty) {
          final challengeId =
              _parsedChallengeData!['_id'] ?? _parsedChallengeData!['id'];
          if (challengeId != null) {
            final challengeRepo = ref.read(challengeRepositoryProvider);
            final challenge =
                await challengeRepo.getById(challengeId.toString());
            if (challenge != null) {
              if (challenge['questions'] != null) {
                try {
                  final questions = challenge['questions'] is String
                      ? jsonDecode(challenge['questions'])
                      : challenge['questions'];
                  if (isConvexList(questions)) {
                    preloadedQuestions = toList(questions)
                        .map((e) => _normalizeQuestion(toMap(e)))
                        .toList();
                  }
                } catch (e) {
                  debugPrint("Error parsing questions: $e");
                }
              }
              if (preloadedQuestions == null || preloadedQuestions.isEmpty) {
                if (challenge['options'] != null) {
                  try {
                    final options = challenge['options'] is String
                        ? jsonDecode(challenge['options'])
                        : challenge['options'];
                    if (isConvexList(options)) {
                      final normalizedOptions = _normalizeOptions(options);
                      final answerFromOptions = options
                          .whereType<Map>()
                          .firstWhere((e) => e['isCorrect'] == true,
                              orElse: () => {});
                      preloadedQuestions = [
                        {
                          'question': challenge['question'],
                          'solution': challenge['solution'],
                          'answer': answerFromOptions['text']?.toString(),
                          'options': normalizedOptions ?? options,
                          'topic': challenge['title'] ?? challenge['quizName'],
                          'difficulty': challenge['difficulty'] ?? 'Medium',
                          'type': 'mcq'
                        }
                      ];
                    }
                  } catch (e) {
                    debugPrint("Error parsing options: $e");
                    if (isConvexList(challenge['options'])) {
                      final normalizedOptions =
                          _normalizeOptions(toList(challenge['options']));
                      preloadedQuestions = [
                        {
                          'question': challenge['question'],
                          'solution': challenge['solution'],
                          'options':
                              normalizedOptions ?? toList(challenge['options']),
                          'topic': challenge['title'] ?? challenge['quizName'],
                          'difficulty': challenge['difficulty'] ?? 'Medium',
                          'type': 'mcq'
                        }
                      ];
                    }
                  }
                }
              }
              if (preloadedQuestions == null || preloadedQuestions.isEmpty) {
                final normalizedOptions = challenge['options'] != null
                    ? _normalizeOptions(isConvexList(challenge['options'])
                        ? toList(challenge['options'])
                        : jsonDecode(challenge['options']))
                    : null;
                preloadedQuestions = [
                  {
                    'question': challenge['question'],
                    'solution': challenge['solution'],
                    'options': normalizedOptions,
                    'topic': challenge['title'] ?? challenge['quizName'],
                    'difficulty': challenge['difficulty'] ?? 'Medium',
                    'type': challenge['options'] != null ? 'mcq' : 'input'
                  }
                ];
              }
            }
          }
        }
      }
      if (preloadedQuestions != null && preloadedQuestions.isNotEmpty) {
        preloadedQuestions =
            preloadedQuestions.map(_normalizeQuestion).toList();
        _hasHandledNavigation = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _navigateToChallenge(preloadedQuestions!);
        });
        return;
      }
      if (_parsedChallengeData != null) {
        String? topic;
        final topicId = _parsedChallengeData!['topicId'] ??
            _parsedChallengeData!['topic_id'];
        if (topicId != null) {
          topic = _parsedChallengeData!['topic']?.toString() ??
              _parsedChallengeData!['title']?.toString();
        } else {
          topic = _parsedChallengeData!['topic']?.toString() ??
              _parsedChallengeData!['title']?.toString();
        }
        if (topic != null && topic.isNotEmpty) {
          final difficulty =
              _parsedChallengeData!['difficulty']?.toString() ?? 'Medium';
          final count = _parsedChallengeData!['numQuestions'] is num
              ? (_parsedChallengeData!['numQuestions'] as num).toInt()
              : 5;
          setState(() {
            _questionsFuture = AIService.generateQuestions(
              topic!,
              difficulty,
              count: count,
            );
          });
        } else {
          _setError("Challenge data is missing a valid topic.");
        }
      } else {
        _setError("Failed to parse challenge data.");
      }
    } catch (e) {
      debugPrint("Error loading challenge: $e");
      _setError("An error occurred while loading the challenge.");
    }
  }

  void _navigateToChallenge(List<Map<String, dynamic>> questions) {
    if (!mounted || _hasNavigated) return;
    if (questions.isEmpty) {
      _setError("No valid questions found for this challenge.");
      return;
    }
    String topic = questions[0]['topic']?.toString() ?? '';
    if (topic.isEmpty && _parsedChallengeData != null) {
      topic = _parsedChallengeData!['topic']?.toString() ??
          _parsedChallengeData!['title']?.toString() ??
          '';
    }
    final currentRoute = GoRouterState.of(context).uri.toString();
    final challengeId = _parsedChallengeData?['_id'] ??
        _parsedChallengeData?['id'] ??
        _generateRouteId();
    final userPathChallengeId =
        _parsedChallengeData?['userPathChallengeId']?.toString() ??
            _parsedChallengeData?['user_path_challenge_id']?.toString();
    final loadedRoute = '/challenge/$challengeId/_loaded';
    if (currentRoute == loadedRoute) {
      _hasNavigated = true;
      return;
    }
    if (!loadedRoute.endsWith('_loaded')) {
      debugPrint(
          'ERROR: Attempted to navigate to non-loaded route: $loadedRoute');
      return;
    }
    _hasNavigated = true;
    context.go(
      '/challenge/$challengeId/_loaded',
      extra: {
        ...?_parsedChallengeData,
        'questions': questions,
        'topic': topic,
        'quiz_name': _parsedChallengeData?['quiz_name']?.toString() ??
            _parsedChallengeData?['quizName']?.toString() ??
            _parsedChallengeData?['title']?.toString() ??
            topic,
        'timedMode': _parsedChallengeData?['timedMode'] ?? true,
        'numQuestions': questions.length,
        'question_count': questions.length,
        'challengeId': _parsedChallengeData?['_id'],
        if (userPathChallengeId != null)
          'userPathChallengeId': userPathChallengeId,
      },
    );
  }

  void _setError(String message) {
    setState(() {
      _errorLoading = true;
      _errorMessage = message;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_errorLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text("Error")),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 50),
                const SizedBox(height: 16),
                Text("Failed to load challenge:",
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(_errorMessage, textAlign: TextAlign.center),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => context.pop(),
                  child: const Text("Go Back"),
                ),
              ],
            ),
          ),
        ),
      );
    }
    if (_questionsFuture != null) {
      return Scaffold(
        appBar: AppBar(title: const Text("Loading Challenge...")),
        body: FutureBuilder<List<Map<String, dynamic>>>(
          future: _questionsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text("Generating questions with AI..."),
                  ],
                ),
              );
            } else if (snapshot.hasError) {
              final errorMessage =
                  "Error generating questions: ${snapshot.error}";
              _setError(errorMessage);
              return const Center(child: CircularProgressIndicator());
            } else if (snapshot.hasData && snapshot.data!.isNotEmpty) {
              _navigateToChallenge(snapshot.data!);
              return const Center(child: CircularProgressIndicator());
            } else {
              _setError("AI did not return any questions.");
              return const Center(child: CircularProgressIndicator());
            }
          },
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text("Loading Challenge...")),
      body: const Center(child: CircularProgressIndicator()),
    );
  }
}
