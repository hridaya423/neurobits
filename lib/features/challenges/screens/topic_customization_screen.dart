import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:neurobits/core/providers.dart';
import 'package:neurobits/services/groq_service.dart';

class TopicCustomizationScreen extends ConsumerStatefulWidget {
  final String topic;
  const TopicCustomizationScreen({required this.topic, super.key});
  @override
  ConsumerState<TopicCustomizationScreen> createState() =>
      _TopicCustomizationScreenState();
}

class _TopicCustomizationScreenState
    extends ConsumerState<TopicCustomizationScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  bool _isLoading = false;
  late int _selectedQuestionCount;
  late int _selectedTimePerQuestion;
  int? _selectedTotalTimeLimit;
  late bool _timedMode;
  late String _selectedDifficulty;
  late bool _includeCodeChallenges;
  late bool _includeMcqs;
  late bool _includeInput;
  late bool _includeFillBlank;
  bool? _isCodingRelated;
  bool _initialPrefsLoaded = false;
  @override
  void initState() {
    super.initState();
    _selectedQuestionCount = 5;
    _selectedTimePerQuestion = 60;
    _timedMode = false;
    _selectedDifficulty = 'Medium';
    _includeCodeChallenges = false;
    _includeMcqs = true;
    _includeInput = true;
    _includeFillBlank = false;
    _selectedTotalTimeLimit = null;
    _isCodingRelated = null;
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    ));
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.2, 0.7, curve: Curves.easeOut),
    ));
    _animationController.forward();
    _checkTopicType();
  }

  Future<void> _checkTopicType() async {
    try {
      final isCoding = await GroqService.isCodingRelated(widget.topic);
      if (mounted) {
        setState(() {
          _isCodingRelated = isCoding;
          if (!_isCodingRelated!) {
            _includeCodeChallenges = false;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isCodingRelated = false;
          _includeCodeChallenges = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _generateQuiz() async {
    debugPrint(
        "[_generateQuiz] Starting quiz generation via customization screen...");
    if (!mounted) return;

    if (widget.topic.trim().length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Topic is too short. Please enter at least 2 characters.')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });
    try {
      final quizData = await GroqService.prepareQuizData(
        topic: widget.topic,
        questionCount: _selectedQuestionCount,
        timePerQuestion: _selectedTimePerQuestion,
        difficulty: _selectedDifficulty,
        includeCodeChallenges: _includeCodeChallenges,
        includeMcqs: _includeMcqs,
        includeInput: _includeInput,
        includeFillBlank: _includeFillBlank,
        timedMode: _timedMode,
        ref: ref,
        totalTimeLimit: _selectedTotalTimeLimit,
      );
      final String routeKey = quizData['routeKey'];
      final Map<String, dynamic> extraData = quizData['extraData'];
      if (!mounted) {
        debugPrint(
            "[_generateQuiz] Widget not mounted after preparation, aborting navigation.");
        return;
      }
      context.pushReplacement(
        '/challenge/$routeKey/_loaded',
        extra: extraData,
      );
      debugPrint("[_generateQuiz] Navigation completed successfully.");
    } catch (e, stackTrace) {
      debugPrint(
          "[_generateQuiz] Error during quiz generation: $e\n$stackTrace");
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Unable to create quiz. Please try again with different settings.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final preferencesAsync = ref.watch(userPreferencesProvider);
    final validTypeSelected = _includeCodeChallenges ||
        _includeMcqs ||
        _includeInput ||
        _includeFillBlank;
    return Scaffold(
      appBar: AppBar(
        title: Text('Customize Your ${widget.topic} Challenge'),
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Generating challenge...'),
                ],
              ),
            )
          : FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (preferencesAsync is AsyncData &&
                            preferencesAsync.value != null &&
                            !_initialPrefsLoaded) ...[
                          Builder(builder: (context) {
                            final prefsData = preferencesAsync.value!;
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (mounted) {
                                setState(() {
                                  _selectedQuestionCount =
                                      prefsData['default_num_questions']
                                              as int? ??
                                          5;
                                  _selectedTimePerQuestion =
                                      prefsData['default_time_per_question_sec']
                                              as int? ??
                                          60;
                                  _timedMode = prefsData['timed_mode_enabled']
                                          as bool? ??
                                      false;
                                  _selectedDifficulty =
                                      prefsData['default_difficulty']
                                              as String? ??
                                          'Medium';
                                  final List<String> allowedTypes =
                                      List<String>.from(
                                          prefsData['allowed_challenge_types']
                                                  as List<dynamic>? ??
                                              ['quiz']);
                                  _includeMcqs = allowedTypes.contains('quiz');
                                  _includeInput =
                                      allowedTypes.contains('input');
                                  _includeFillBlank =
                                      allowedTypes.contains('fill_blank');
                                  _includeCodeChallenges =
                                      (_isCodingRelated ?? false) &&
                                          allowedTypes.contains('code');
                                  _initialPrefsLoaded = true;
                                });
                              }
                            });
                            return const SizedBox.shrink();
                          })
                        ],
                        if (preferencesAsync is AsyncLoading &&
                            !_initialPrefsLoaded) ...[
                          const Center(
                              child: Padding(
                                  padding: EdgeInsets.all(16.0),
                                  child: CircularProgressIndicator())),
                        ],
                        if (preferencesAsync is AsyncError) ...[
                          Center(
                              child: Text(
                                  "Error loading defaults: ${preferencesAsync.error}")),
                        ],
                        Text('Number of Questions: $_selectedQuestionCount'),
                        Slider(
                          value: _selectedQuestionCount.toDouble(),
                          min: 3,
                          max: 50,
                          divisions: 47,
                          label: _selectedQuestionCount.toString(),
                          onChanged: (value) {
                            setState(() {
                              _selectedQuestionCount = value.round();
                            });
                          },
                        ),
                        const SizedBox(height: 16),
                        Text(
                            'Time per Question (seconds): $_selectedTimePerQuestion'),
                        Slider(
                          value: _selectedTimePerQuestion.toDouble(),
                          min: 10,
                          max: 240,
                          divisions: 23,
                          label: _selectedTimePerQuestion.toString(),
                          onChanged: (value) {
                            setState(() {
                              _selectedTimePerQuestion = value.round();
                            });
                          },
                        ),
                        const SizedBox(height: 16),
                        Text('Difficulty:'),
                        Row(
                          children: [
                            ChoiceChip(
                              label: const Text('Easy'),
                              selected: _selectedDifficulty == 'Easy',
                              onSelected: (selected) {
                                if (selected) {
                                  setState(() => _selectedDifficulty = 'Easy');
                                }
                              },
                            ),
                            const SizedBox(width: 8),
                            ChoiceChip(
                              label: const Text('Medium'),
                              selected: _selectedDifficulty == 'Medium',
                              onSelected: (selected) {
                                if (selected) {
                                  setState(
                                      () => _selectedDifficulty = 'Medium');
                                }
                              },
                            ),
                            const SizedBox(width: 8),
                            ChoiceChip(
                              label: const Text('Hard'),
                              selected: _selectedDifficulty == 'Hard',
                              onSelected: (selected) {
                                if (selected) {
                                  setState(() => _selectedDifficulty = 'Hard');
                                }
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 16,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            if (_isCodingRelated != null) ...[
                              Checkbox(
                                value: _includeCodeChallenges,
                                onChanged: _isCodingRelated!
                                    ? (value) {
                                        setState(() {
                                          _includeCodeChallenges =
                                              value ?? false;
                                        });
                                      }
                                    : null,
                              ),
                              Text('Code Challenges',
                                  style: TextStyle(
                                      color: _isCodingRelated!
                                          ? null
                                          : Colors.grey)),
                            ] else ...[
                              const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2)),
                              const Text('Code Challenges',
                                  style: TextStyle(color: Colors.grey)),
                            ],
                            const SizedBox(width: 16),
                            Checkbox(
                              value: _includeMcqs,
                              onChanged: (value) {
                                setState(() {
                                  _includeMcqs = value ?? false;
                                });
                              },
                            ),
                            const Text('Multiple Choice (MCQ)'),
                            const SizedBox(width: 16),
                            Checkbox(
                              value: _includeInput,
                              onChanged: (value) {
                                setState(() {
                                  _includeInput = value ?? false;
                                });
                              },
                            ),
                            const Text('Input Questions'),
                            const SizedBox(width: 16),
                            Checkbox(
                              value: _includeFillBlank,
                              onChanged: (value) {
                                setState(() {
                                  _includeFillBlank = value ?? false;
                                });
                              },
                            ),
                            const Text('Fill in the Blank'),
                          ],
                        ),
                        if (!validTypeSelected)
                          Padding(
                            padding:
                                const EdgeInsets.only(top: 8.0, bottom: 8.0),
                            child: Text(
                              'At least one question type must be selected.',
                              style: TextStyle(color: Colors.red[700]),
                            ),
                          ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Checkbox(
                              value: _selectedTotalTimeLimit != null,
                              onChanged: (checked) {
                                setState(() {
                                  _selectedTotalTimeLimit = checked == true
                                      ? _selectedTimePerQuestion *
                                          _selectedQuestionCount
                                      : null;
                                });
                              },
                            ),
                            const Text('Set total quiz time limit'),
                          ],
                        ),
                        if (_selectedTotalTimeLimit != null)
                          Row(
                            children: [
                              Expanded(
                                child: Slider(
                                  value: (_selectedTotalTimeLimit ??
                                          (_selectedTimePerQuestion *
                                              _selectedQuestionCount))
                                      .toDouble(),
                                  min: 30,
                                  max: max(
                                      3600,
                                      (_selectedTimePerQuestion *
                                                  _selectedQuestionCount)
                                              .toDouble() +
                                          600),
                                  divisions: max(
                                      1,
                                      (max(
                                                  3600,
                                                  (_selectedTimePerQuestion *
                                                              _selectedQuestionCount)
                                                          .toDouble() +
                                                      600) -
                                              30) ~/
                                          10),
                                  label: _selectedTotalTimeLimit != null
                                      ? '${(_selectedTotalTimeLimit! / 60).floor()}m ${(_selectedTotalTimeLimit! % 60)}s'
                                      : 'auto',
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedTotalTimeLimit = value.round();
                                    });
                                  },
                                ),
                              ),
                              Text(
                                  '${(_selectedTotalTimeLimit! / 60).floor()}m ${(_selectedTotalTimeLimit! % 60)}s'),
                            ],
                          ),
                        const SizedBox(height: 32),
                        Row(
                          children: [
                            Text(
                              'Timed mode (per question):',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const Spacer(),
                            Switch(
                              value: _timedMode,
                              onChanged: (value) {
                                setState(() {
                                  _timedMode = value;
                                });
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),
                        Center(
                          child: ElevatedButton(
                            onPressed: _isLoading || !validTypeSelected
                                ? null
                                : _generateQuiz,
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  Theme.of(context).colorScheme.primary,
                              foregroundColor:
                                  Theme.of(context).colorScheme.onPrimary,
                              padding: const EdgeInsets.symmetric(
                                  vertical: 20, horizontal: 24),
                            ),
                            child: const Text('Start Challenge'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}
