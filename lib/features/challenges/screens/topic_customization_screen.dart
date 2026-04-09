import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:neurobits/core/providers.dart';
import 'package:neurobits/services/ai_service.dart';
import 'package:neurobits/services/convex_client_service.dart';

class TopicCustomizationScreen extends ConsumerStatefulWidget {
  final String topic;
  final String? userPathChallengeId;
  final String? examTargetId;
  final Map<String, dynamic>? quizPreset;
  const TopicCustomizationScreen({
    required this.topic,
    this.userPathChallengeId,
    this.examTargetId,
    this.quizPreset,
    super.key,
  });
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
  late bool _hintsEnabled;
  late bool _imageQuestionsEnabled;
  bool? _isCodingRelated;
  bool _initialPrefsLoaded = false;
  bool _quickStartEnabled = true;
  bool _autoStartTriggered = false;

  bool get _hasAutoStartPreset => widget.quizPreset?['autoStart'] == true;

  bool get _isExamModeSession =>
      widget.examTargetId != null && widget.examTargetId!.trim().isNotEmpty;

  bool get _isBaselineDiagnosticTopic {
    final normalized = widget.topic.toLowerCase().trim();
    return normalized == 'baseline diagnostic' ||
        normalized.contains('baseline diagnostic');
  }

  String get _examModeProfile {
    final fromPreset =
        widget.quizPreset?['examModeProfile']?.toString().trim().toLowerCase();
    if (fromPreset != null && fromPreset.isNotEmpty) {
      return fromPreset;
    }
    if (_isExamModeSession && _isBaselineDiagnosticTopic) {
      return 'exam_baseline';
    }
    if (_isExamModeSession) {
      return 'exam_standard';
    }
    return 'general';
  }

  int _clampInt(dynamic value, int fallback, int min, int max) {
    if (value is! num) return fallback;
    return value.toInt().clamp(min, max);
  }

  void _applyQuizPresetIfAny() {
    final preset = widget.quizPreset;
    if (preset == null) {
      _enforceExamModeRules();
      return;
    }

    _selectedQuestionCount =
        _clampInt(preset['questionCount'], _selectedQuestionCount, 3, 50);
    _selectedTimePerQuestion = _clampInt(
      preset['timePerQuestion'],
      _selectedTimePerQuestion,
      10,
      240,
    );

    if (preset['timedMode'] is bool) {
      _timedMode = preset['timedMode'] as bool;
    }

    final difficulty = preset['difficulty']?.toString();
    if (difficulty == 'Easy' ||
        difficulty == 'Medium' ||
        difficulty == 'Hard') {
      _selectedDifficulty = difficulty!;
    }

    if (preset['includeCodeChallenges'] is bool) {
      _includeCodeChallenges = preset['includeCodeChallenges'] as bool;
    }
    if (preset['includeMcqs'] is bool) {
      _includeMcqs = preset['includeMcqs'] as bool;
    }
    if (preset['includeInput'] is bool) {
      _includeInput = preset['includeInput'] as bool;
    }
    if (preset['includeFillBlank'] is bool) {
      _includeFillBlank = preset['includeFillBlank'] as bool;
    }
    if (preset['includeHints'] is bool) {
      _hintsEnabled = preset['includeHints'] as bool;
    }
    if (preset['includeImageQuestions'] is bool) {
      _imageQuestionsEnabled = preset['includeImageQuestions'] as bool;
    }

    final computedTotalTime = _selectedQuestionCount * _selectedTimePerQuestion;
    final presetTotal = preset['totalTimeLimit'];
    if (presetTotal == null) {
      _selectedTotalTimeLimit = null;
    } else {
      _selectedTotalTimeLimit =
          _clampInt(presetTotal, computedTotalTime, 30, 7200);
    }

    if (_hasAutoStartPreset) {
      _quickStartEnabled = true;
    }

    _enforceExamModeRules();
  }

  void _enforceExamModeRules() {
    if (!_isExamModeSession) {
      return;
    }

    _includeCodeChallenges = false;
    _includeFillBlank = false;
    _includeMcqs = true;
    _includeInput = true;

    if (_isBaselineDiagnosticTopic) {
      _selectedQuestionCount = 24;
      _timedMode = true;
      _selectedDifficulty = 'Medium';
      if (_selectedTimePerQuestion < 30 || _selectedTimePerQuestion > 180) {
        _selectedTimePerQuestion = 75;
      }
      _selectedTotalTimeLimit =
          _selectedQuestionCount * _selectedTimePerQuestion;
      _hintsEnabled = true;
    }
  }

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
    _hintsEnabled = false;
    _imageQuestionsEnabled = false;
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
      final isCoding = await AIService.isCodingRelated(widget.topic);
      if (mounted) {
        setState(() {
          _isCodingRelated = isCoding;
          if (!_isCodingRelated!) {
            _includeCodeChallenges = false;
          }
          _enforceExamModeRules();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isCodingRelated = false;
          _includeCodeChallenges = false;
          _enforceExamModeRules();
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
      final quizData = await AIService.prepareQuizData(
        topic: widget.topic,
        questionCount: _selectedQuestionCount,
        timePerQuestion: _selectedTimePerQuestion,
        difficulty: _selectedDifficulty,
        includeCodeChallenges: _includeCodeChallenges,
        includeMcqs: _includeMcqs,
        includeInput: _includeInput,
        includeFillBlank: _includeFillBlank,
        includeHints: _hintsEnabled,
        includeImageQuestions: _imageQuestionsEnabled,
        timedMode: _timedMode,
        ref: ref,
        totalTimeLimit: _selectedTotalTimeLimit,
        userPathChallengeId: widget.userPathChallengeId,
        examTargetOverrideId: widget.examTargetId,
        examModeProfile: _examModeProfile,
        examFocusContext: widget.quizPreset?['examFocusContext']?.toString(),
      );
      final String routeKey = quizData['routeKey'];
      final Map<String, dynamic> extraData = quizData['extraData'];
      if (!mounted) {
        return;
      }
      context.pushReplacement(
        '/challenge/$routeKey/_loaded',
        extra: extraData,
      );
    } catch (e) {
      debugPrint("[_generateQuiz] Error during quiz generation: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
          _autoStartTriggered = false;
        });

        String errorMessage =
            'Unable to create quiz. Please try again with different settings.';
        if (e.toString().contains('OPENROUTER_API_KEY')) {
          errorMessage = 'API configuration error. Please contact support.';
        } else if (e.toString().contains('Invalid question count')) {
          errorMessage =
              'Invalid number of questions. Please select between 3-50 questions.';
        } else if (e.toString().contains('No valid JSON array found')) {
          errorMessage = 'AI service returned invalid data. Please try again.';
        } else if (e.toString().contains('couldn\'t create questions')) {
          errorMessage = e.toString().replaceAll('Exception: ', '');
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final preferencesAsync = ref.watch(userPreferencesProvider);
    final validTypeSelected = _isExamModeSession
        ? (_includeMcqs || _includeInput)
        : (_includeCodeChallenges ||
            _includeMcqs ||
            _includeInput ||
            _includeFillBlank);
    final showLoading =
        _isLoading || (_quickStartEnabled && _autoStartTriggered);
    final showQuickStartTitle = _quickStartEnabled && _initialPrefsLoaded;
    final shouldAutoStart = (_quickStartEnabled || _hasAutoStartPreset) &&
        _initialPrefsLoaded &&
        !_autoStartTriggered;
    if (shouldAutoStart) {
      _autoStartTriggered = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_isLoading) {
          _generateQuiz();
        }
      });
    }
    return Scaffold(
        appBar: AppBar(
          title: Text(showQuickStartTitle
              ? 'Starting ${widget.topic} quiz...'
              : 'Customize Your ${widget.topic} Challenge'),
        ),
        body: showLoading
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(showQuickStartTitle
                        ? 'Starting your quiz...'
                        : 'Generating challenge...'),
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
                                        prefsData['defaultNumQuestions'] is num
                                            ? (prefsData['defaultNumQuestions']
                                                    as num)
                                                .toInt()
                                            : 5;
                                    _selectedTimePerQuestion = prefsData[
                                            'defaultTimePerQuestionSec'] is num
                                        ? (prefsData[
                                                    'defaultTimePerQuestionSec']
                                                as num)
                                            .toInt()
                                        : 60;
                                    _timedMode = prefsData['timedModeEnabled']
                                            as bool? ??
                                        false;
                                    _selectedDifficulty =
                                        prefsData['defaultDifficulty']
                                                as String? ??
                                            'Medium';
                                    _quickStartEnabled =
                                        prefsData['quickStartEnabled']
                                                as bool? ??
                                            true;
                                    _hintsEnabled =
                                        prefsData['hintsEnabled'] as bool? ??
                                            false;
                                    _imageQuestionsEnabled =
                                        prefsData['imageQuestionsEnabled']
                                                as bool? ??
                                            false;
                                    final List<String> allowedTypes =
                                        convexStringList(
                                            prefsData['allowedChallengeTypes'],
                                            ['quiz']);
                                    _includeMcqs =
                                        allowedTypes.contains('quiz');
                                    _includeInput =
                                        allowedTypes.contains('input');
                                    _includeFillBlank =
                                        allowedTypes.contains('fill_blank');
                                    _includeCodeChallenges =
                                        (_isCodingRelated ?? false) &&
                                            allowedTypes.contains('code');
                                    _applyQuizPresetIfAny();
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
                            if (!_initialPrefsLoaded)
                              Builder(builder: (context) {
                                WidgetsBinding.instance
                                    .addPostFrameCallback((_) {
                                  if (mounted) {
                                    setState(() {
                                      _applyQuizPresetIfAny();
                                      _initialPrefsLoaded = true;
                                    });
                                  }
                                });
                                return const SizedBox.shrink();
                              }),
                            Center(
                                child: Text(
                                    "Error loading defaults: ${preferencesAsync.error}")),
                          ],
                          if (widget.quizPreset != null) ...[
                            Container(
                              width: double.infinity,
                              margin: const EdgeInsets.only(bottom: 16),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .tertiary
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .tertiary
                                      .withValues(alpha: 0.35),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.timer_outlined,
                                    color:
                                        Theme.of(context).colorScheme.tertiary,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'Paper simulation preset applied',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          if (widget.examTargetId != null &&
                              widget.examTargetId!.trim().isNotEmpty)
                            Container(
                              width: double.infinity,
                              margin: const EdgeInsets.only(bottom: 16),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .primary
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .primary
                                      .withValues(alpha: 0.35),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.menu_book_rounded,
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      _isBaselineDiagnosticTopic
                                          ? 'Exam mode baseline diagnostic'
                                          : 'Exam mode session',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (_isExamModeSession && _isBaselineDiagnosticTopic)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Text(
                                'Baseline diagnostics use 24 timed exam-style questions for a reliable starting profile.',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                          Text('Number of Questions: $_selectedQuestionCount'),
                          Slider(
                            value: _selectedQuestionCount.toDouble(),
                            min: 3,
                            max: 50,
                            divisions: 47,
                            label: _selectedQuestionCount.toString(),
                            onChanged: _isExamModeSession &&
                                    _isBaselineDiagnosticTopic
                                ? null
                                : (value) {
                                    setState(() {
                                      _selectedQuestionCount = value.round();
                                    });
                                  },
                          ),
                          if (_isExamModeSession && _isBaselineDiagnosticTopic)
                            Text(
                              'Locked for baseline consistency.',
                              style: Theme.of(context).textTheme.bodySmall,
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
                            onChanged: _isExamModeSession &&
                                    _isBaselineDiagnosticTopic
                                ? null
                                : (value) {
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
                                onSelected: (_isExamModeSession &&
                                        _isBaselineDiagnosticTopic)
                                    ? null
                                    : (selected) {
                                        if (selected) {
                                          setState(() =>
                                              _selectedDifficulty = 'Easy');
                                        }
                                      },
                              ),
                              const SizedBox(width: 8),
                              ChoiceChip(
                                label: const Text('Medium'),
                                selected: _selectedDifficulty == 'Medium',
                                onSelected: (_isExamModeSession &&
                                        _isBaselineDiagnosticTopic)
                                    ? null
                                    : (selected) {
                                        if (selected) {
                                          setState(() =>
                                              _selectedDifficulty = 'Medium');
                                        }
                                      },
                              ),
                              const SizedBox(width: 8),
                              ChoiceChip(
                                label: const Text('Hard'),
                                selected: _selectedDifficulty == 'Hard',
                                onSelected: (_isExamModeSession &&
                                        _isBaselineDiagnosticTopic)
                                    ? null
                                    : (selected) {
                                        if (selected) {
                                          setState(() =>
                                              _selectedDifficulty = 'Hard');
                                        }
                                      },
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          if (_isExamModeSession)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Question Types'),
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: const [
                                    Chip(label: Text('Multiple Choice (MCQ)')),
                                    Chip(
                                        label:
                                            Text('Explain / Short Response')),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Exam mode uses GCSE-style formats only (MCQ + explain responses).',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            )
                          else
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Question Types'),
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 16,
                                  runSpacing: 0,
                                  children: [
                                    if (_isCodingRelated == true)
                                      SizedBox(
                                        width: 160,
                                        child: CheckboxListTile(
                                          contentPadding: EdgeInsets.zero,
                                          dense: true,
                                          title: const Text('Code'),
                                          value: _includeCodeChallenges,
                                          onChanged: (value) {
                                            setState(() {
                                              _includeCodeChallenges =
                                                  value ?? false;
                                            });
                                          },
                                        ),
                                      ),
                                    SizedBox(
                                      width: 160,
                                      child: CheckboxListTile(
                                        contentPadding: EdgeInsets.zero,
                                        dense: true,
                                        title: const Text('Multiple Choice'),
                                        value: _includeMcqs,
                                        onChanged: (value) {
                                          setState(() {
                                            _includeMcqs = value ?? false;
                                          });
                                        },
                                      ),
                                    ),
                                    SizedBox(
                                      width: 160,
                                      child: CheckboxListTile(
                                        contentPadding: EdgeInsets.zero,
                                        dense: true,
                                        title: const Text('Input'),
                                        value: _includeInput,
                                        onChanged: (value) {
                                          setState(() {
                                            _includeInput = value ?? false;
                                          });
                                        },
                                      ),
                                    ),
                                    SizedBox(
                                      width: 160,
                                      child: CheckboxListTile(
                                        contentPadding: EdgeInsets.zero,
                                        dense: true,
                                        title: const Text('Fill in Blank'),
                                        value: _includeFillBlank,
                                        onChanged: (value) {
                                          setState(() {
                                            _includeFillBlank = value ?? false;
                                          });
                                        },
                                      ),
                                    ),
                                  ],
                                ),
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
                                  if (_isExamModeSession &&
                                      _isBaselineDiagnosticTopic) {
                                    return;
                                  }
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
                                    onChanged: _isExamModeSession &&
                                            _isBaselineDiagnosticTopic
                                        ? null
                                        : (value) {
                                            setState(() {
                                              _selectedTotalTimeLimit =
                                                  value.round();
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
                              const Text('Timed Mode'),
                              const Spacer(),
                              Switch(
                                value: _timedMode,
                                onChanged: (_isExamModeSession &&
                                        _isBaselineDiagnosticTopic)
                                    ? null
                                    : (value) {
                                        setState(() {
                                          _timedMode = value;
                                        });
                                      },
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Hints for Most Questions'),
                                    SizedBox(height: 4),
                                    Text(
                                      'If enabled, most questions will include a short hint.',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                              Switch(
                                value: _hintsEnabled,
                                onChanged: (value) {
                                  setState(() {
                                    _hintsEnabled = value;
                                  });
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Visual Questions (Images + Charts)'),
                                    SizedBox(height: 4),
                                    Text(
                                      'Generate creative diagrams, maps, and charts when useful.',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                              Switch(
                                value: _imageQuestionsEnabled,
                                onChanged: (value) {
                                  setState(() {
                                    _imageQuestionsEnabled = value;
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
              ));
  }
}
