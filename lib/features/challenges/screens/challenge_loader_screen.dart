import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:neurobits/services/ai_service.dart';
import 'package:neurobits/services/supabase.dart';

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
    debugPrint(
        'ChallengeLoaderScreen.didChangeDependencies: route=$uri, challengeData=${widget.challengeData}');
    if (uri.endsWith('_loaded')) {
      debugPrint('Already on loaded route, not running loader logic.');
      _hasNavigated = true;
      return;
    }

    final data = widget.challengeData;
    if (data is Map<String, dynamic> &&
        data['questions'] is List &&
        (data['questions'] as List).isNotEmpty) {
      debugPrint(
          'Found questions in challenge data, navigating to loaded route.');
      _hasHandledNavigation = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final challengeId = data['id'] ?? UniqueKey().toString();
        if (_hasNavigated) return;
        _hasNavigated = true;
        context.go(
          '/challenge/$challengeId/_loaded',
          extra: data,
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
        if (_parsedChallengeData!['questions'] is List) {
          preloadedQuestions = List<Map<String, dynamic>>.from(
              _parsedChallengeData!['questions']);
        }
        if (preloadedQuestions == null || preloadedQuestions.isEmpty) {
          final challengeId = _parsedChallengeData!['id'];
          if (challengeId != null) {
            debugPrint(
                "Fetching questions from database for challenge: $challengeId");
            final challenge = await SupabaseService.client
                .from('challenges')
                .select('*')
                .eq('id', challengeId)
                .single();
            if (challenge != null) {
              if (challenge['questions'] != null) {
                try {
                  final questions = jsonDecode(challenge['questions']);
                  if (questions is List) {
                    preloadedQuestions =
                        List<Map<String, dynamic>>.from(questions);
                  }
                } catch (e) {
                  debugPrint("Error parsing questions: $e");
                }
              }
              if (preloadedQuestions == null || preloadedQuestions.isEmpty) {
                if (challenge['options'] != null) {
                  try {
                    final options = jsonDecode(challenge['options']);
                    if (options is List) {
                      preloadedQuestions = [
                        {
                          'question': challenge['question'],
                          'solution': challenge['solution'],
                          'options': options,
                          'topic': challenge['title'] ?? challenge['quiz_name'],
                          'difficulty': challenge['difficulty'] ?? 'Medium',
                          'type': 'mcq'
                        }
                      ];
                    }
                  } catch (e) {
                    debugPrint("Error parsing options: $e");
                    if (challenge['options'] is List) {
                      preloadedQuestions = [
                        {
                          'question': challenge['question'],
                          'solution': challenge['solution'],
                          'options': challenge['options'],
                          'topic': challenge['title'] ?? challenge['quiz_name'],
                          'difficulty': challenge['difficulty'] ?? 'Medium',
                          'type': 'mcq'
                        }
                      ];
                    }
                  }
                }
              }
              if (preloadedQuestions == null || preloadedQuestions.isEmpty) {
                preloadedQuestions = [
                  {
                    'question': challenge['question'],
                    'solution': challenge['solution'],
                    'options': challenge['options'] != null
                        ? (challenge['options'] is List
                            ? challenge['options']
                            : jsonDecode(challenge['options']))
                        : null,
                    'topic': challenge['title'] ?? challenge['quiz_name'],
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
        debugPrint("Using preloaded questions for challenge.");
        _hasHandledNavigation = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _navigateToChallenge(preloadedQuestions!);
        });
        return;
      }
      if (_parsedChallengeData != null) {
        String? topic;
        if (_parsedChallengeData!['topic_id'] != null) {
          final topicData = await SupabaseService.client
              .from('topics')
              .select('name')
              .eq('id', _parsedChallengeData!['topic_id'])
              .maybeSingle();
          topic = topicData?['name'];
        } else {
          topic = _parsedChallengeData!['topic']?.toString() ??
              _parsedChallengeData!['title']?.toString();
        }
        if (topic != null && topic.isNotEmpty) {
          final difficulty =
              _parsedChallengeData!['difficulty']?.toString() ?? 'Medium';
          final count = _parsedChallengeData!['numQuestions'] as int? ?? 5;
          debugPrint("Generating questions for topic: $topic");
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
    final challengeId = _parsedChallengeData?['id'] ?? UniqueKey().toString();
    final loadedRoute = '/challenge/$challengeId/_loaded';
    if (currentRoute == loadedRoute) {
      debugPrint('Already on loaded route $loadedRoute, not navigating again.');
      _hasNavigated = true;
      return;
    }
    if (!loadedRoute.endsWith('_loaded')) {
      debugPrint(
          'ERROR: Attempted to navigate to non-loaded route: $loadedRoute');
      return;
    }
    debugPrint(
        'Navigating from $currentRoute to $loadedRoute with questions: ${questions.length}');
    _hasNavigated = true;
    context.go(
      '/challenge/$challengeId/_loaded',
      extra: {
        ...?_parsedChallengeData,
        'questions': questions,
        'topic': topic,
        'quiz_name': _parsedChallengeData?['quiz_name']?.toString() ??
            _parsedChallengeData?['title']?.toString() ??
            topic,
        'timedMode': _parsedChallengeData?['timedMode'] ?? true,
        'numQuestions': questions.length,
        'question_count': questions.length,
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
              final errorMessage = "Error generating questions: ${snapshot.error}";
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
