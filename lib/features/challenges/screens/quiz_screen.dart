import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:neurobits/services/supabase.dart';
import 'package:neurobits/services/supabase_challenge_analytics.dart';
import 'package:neurobits/services/badge_service.dart';
import '../widgets/quiz_challenge.dart';
import '../widgets/coding_challenge.dart';
import '../widgets/input_challenge.dart';
import 'package:neurobits/features/challenges/screens/session_summary_screen.dart';
import 'package:neurobits/core/learning_path_providers.dart';

class AnalyticsBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final dynamic value;
  final Color color;
  const AnalyticsBadge(
      {required this.icon,
      required this.label,
      required this.value,
      required this.color});
  @override
  Widget build(BuildContext context) {
    return Card(
      color: color.withOpacity(0.10),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 4),
            Text('$value',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600)),
            Text(label,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.grey[700])),
          ],
        ),
      ),
    );
  }
}

class QuizReview extends StatelessWidget {
  final List<Map<String, dynamic>> questions;
  final List<dynamic> selectedAnswers;
  const QuizReview({required this.questions, required this.selectedAnswers});
  static bool isAnswerCorrect(Map<String, dynamic> q, dynamic userAnswer) {
    if (userAnswer == null) return false;
    final type = q['type']?.toString().toLowerCase() ??
        (q['options'] != null
            ? 'mcq'
            : (q['solution'] != null ? 'code' : 'input'));
    final correctAnswer = q['solution'] ?? q['answer'];
    if (correctAnswer == null) {
      debugPrint(
          "Warning: Question missing 'solution' or 'answer' field: ${q['question']}");
      return false;
    }
    switch (type) {
      case 'mcq':
        final options = q['options'] as List<dynamic>?;
        if (options != null) {
          if (correctAnswer is int &&
              correctAnswer >= 0 &&
              correctAnswer < options.length) {
            return userAnswer == options[correctAnswer];
          } else {
            return userAnswer.toString().trim().toLowerCase() ==
                correctAnswer.toString().trim().toLowerCase();
          }
        } else {
          return userAnswer.toString().trim().toLowerCase() ==
              correctAnswer.toString().trim().toLowerCase();
        }
      case 'input':
      case 'fill_blank':
      case 'code':
        return userAnswer.toString().trim().toLowerCase() ==
            correctAnswer.toString().trim().toLowerCase();
      default:
        debugPrint(
            "Warning: Unknown question type '$type' for correctness check: ${q['question']}");
        return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    int correctCount = 0;
    for (int i = 0; i < questions.length; i++) {
      if (isAnswerCorrect(questions[i], selectedAnswers[i])) correctCount++;
    }
    return Padding(
      padding: const EdgeInsets.all(24),
      child: ListView(
        shrinkWrap: true,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Quiz Review',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold)),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const Divider(height: 24),
          Text('Correct: $correctCount / ${questions.length}',
              style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...List.generate(questions.length, (i) {
            final q = questions[i];
            final selected = selectedAnswers[i];
            final type = q['type'] ?? (q['options'] != null ? 'mcq' : 'code');
            final isCorrect = isAnswerCorrect(q, selected);
            if (type == 'code') {
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 10),
                elevation: 2,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Q${i + 1} (Code Challenge)',
                          style: Theme.of(context)
                              .textTheme
                              .labelLarge
                              ?.copyWith(color: Colors.deepPurple)),
                      const SizedBox(height: 6),
                      Text(q['question'] ?? '',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600)),
                      if (q['starter_code'] != null &&
                          q['starter_code'].toString().isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text('Starter Code:',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: Colors.grey[700])),
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(q['starter_code'],
                              style: const TextStyle(
                                  fontFamily: 'monospace', fontSize: 14)),
                        ),
                      ],
                      const SizedBox(height: 10),
                      Text('Your Answer:',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: Colors.deepPurple)),
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.deepPurple.withOpacity(0.07),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(selected ?? '',
                            style: const TextStyle(
                                fontFamily: 'monospace', fontSize: 14)),
                      ),
                      const SizedBox(height: 10),
                      Text('Reference Solution:',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: Colors.green[900])),
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.07),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(q['solution'] ?? '',
                            style: const TextStyle(
                                fontFamily: 'monospace', fontSize: 14)),
                      ),
                      const SizedBox(height: 10),
                      if (isCorrect)
                        const Chip(
                            label: Text('Correct',
                                style: TextStyle(color: Colors.white)),
                            backgroundColor: Colors.green)
                      else
                        const Chip(
                            label: Text('Incorrect',
                                style: TextStyle(color: Colors.white)),
                            backgroundColor: Colors.red),
                    ],
                  ),
                ),
              );
            } else if (type == 'input' || type == 'fill_blank') {
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 10),
                elevation: 2,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          'Q${i + 1} (${type == 'input' ? 'Input' : 'Fill-in-the-Blank'} Challenge)',
                          style: Theme.of(context)
                              .textTheme
                              .labelLarge
                              ?.copyWith(color: Colors.deepPurple)),
                      const SizedBox(height: 6),
                      Text(q['question'] ?? '',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 12),
                      Text('Your Answer:',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: Colors.deepPurple)),
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.deepPurple.withOpacity(0.07),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(selected ?? '',
                            style: const TextStyle(fontSize: 14)),
                      ),
                      const SizedBox(height: 10),
                      Text('Reference Solution:',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: Colors.green[900])),
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.07),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(q['solution'] ?? '',
                            style: const TextStyle(fontSize: 14)),
                      ),
                      const SizedBox(height: 10),
                      if (isCorrect)
                        const Chip(
                            label: Text('Correct',
                                style: TextStyle(color: Colors.white)),
                            backgroundColor: Colors.green)
                      else
                        const Chip(
                            label: Text('Incorrect',
                                style: TextStyle(color: Colors.white)),
                            backgroundColor: Colors.red),
                    ],
                  ),
                ),
              );
            } else if (type == 'mcq') {
              final options = List<String>.from(q['options'] ?? []);
              final correctIdx = q['answer'] is int
                  ? q['answer']
                  : options.indexWhere((opt) =>
                      opt.toString().trim().toLowerCase() ==
                      (q['answer'] ?? '').toString().trim().toLowerCase());
              final selectedIdx = selected is int
                  ? selected
                  : options.indexWhere((opt) =>
                      opt.toString().trim().toLowerCase() ==
                      (selected ?? '').toString().trim().toLowerCase());
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 10),
                elevation: 2,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Q${i + 1}',
                          style: Theme.of(context)
                              .textTheme
                              .labelLarge
                              ?.copyWith(color: Colors.deepPurple)),
                      const SizedBox(height: 6),
                      Text(q['question'] ?? '',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 12),
                      ...List.generate(options.length, (j) {
                        final isCorrectOpt = j == correctIdx;
                        final isSelected = j == selectedIdx;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.symmetric(
                              vertical: 8, horizontal: 12),
                          decoration: BoxDecoration(
                            color: isCorrectOpt
                                ? Colors.green.withOpacity(0.15)
                                : isSelected
                                    ? Colors.deepPurple.withOpacity(0.13)
                                    : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isCorrectOpt
                                  ? Colors.green
                                  : isSelected
                                      ? Colors.deepPurple
                                      : Colors.grey[300]!,
                              width: 1.2,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isCorrectOpt
                                    ? Icons.check_circle
                                    : isSelected
                                        ? Icons.radio_button_checked
                                        : Icons.radio_button_unchecked,
                                color: isCorrectOpt
                                    ? Colors.green
                                    : isSelected
                                        ? Colors.deepPurple
                                        : Colors.grey,
                                size: 22,
                              ),
                              const SizedBox(width: 10),
                              Flexible(
                                child: Text(
                                  options[j],
                                  style: TextStyle(
                                    fontWeight: isCorrectOpt
                                        ? FontWeight.bold
                                        : isSelected
                                            ? FontWeight.w600
                                            : FontWeight.normal,
                                    color: isCorrectOpt
                                        ? Colors.green[900]
                                        : isSelected
                                            ? Colors.deepPurple
                                            : Colors.black,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                      const SizedBox(height: 8),
                      if (isCorrect)
                        const Chip(
                            label: Text('Correct',
                                style: TextStyle(color: Colors.white)),
                            backgroundColor: Colors.green)
                      else
                        const Chip(
                            label: Text('Incorrect',
                                style: TextStyle(color: Colors.white)),
                            backgroundColor: Colors.red),
                    ],
                  ),
                ),
              );
            } else {
              return const SizedBox.shrink();
            }
          }),
        ],
      ),
    );
  }
}

class AIChallengeScreen extends ConsumerStatefulWidget {
  final String topic;
  final String? quizName;
  final List<Map<String, dynamic>> questions;
  final bool timedMode;
  const AIChallengeScreen({
    required this.topic,
    required this.questions,
    this.quizName,
    this.timedMode = true,
    super.key,
  });
  @override
  ConsumerState<AIChallengeScreen> createState() => _AIChallengeScreenState();
}

class _AIChallengeScreenState extends ConsumerState<AIChallengeScreen> {
  late int _secondsRemaining;
  bool _completed = false;
  int _currentQuestionIndex = 0;
  bool _disposed = false;
  List<dynamic> _selectedAnswers = [];
  Timer? _timer;
  late DateTime _startTime;
  int? _perQuestionTime;
  int _finalCorrectCount = 0;
  int _finalAnsweredCount = 0;
  double _finalAccuracy = 0.0;
  int _finalTimeTaken = 0;
  Future<void> _showBadgePopup(List<Map<String, dynamic>> newBadges) async {
    if (newBadges.isEmpty) return;
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Achievement Unlocked!'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ...newBadges.map((badge) => Row(
                    children: [
                      Text(badge['badge']['icon'] ?? '🏅',
                          style: const TextStyle(fontSize: 28)),
                      const SizedBox(width: 10),
                      Expanded(
                          child: Text(badge['badge']['name'] ?? '',
                              style: Theme.of(context).textTheme.titleMedium)),
                    ],
                  )),
              const SizedBox(height: 10),
              Text('Check your profile to see all badges!'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _checkAndShowNewBadges(
      String userId, List<String> oldBadgeIds) async {
    final userBadges = await BadgeService.getUserBadges(userId);
    final newBadges =
        userBadges.where((b) => !oldBadgeIds.contains(b['badge_id'])).toList();
    if (newBadges.isNotEmpty) {
      await _showBadgePopup(newBadges);
    }
  }

  void _onChallengeCompleted(
      bool success, int timeTaken, double accuracy) async {
    final user = SupabaseService.client.auth.currentUser;
    if (user == null) return;
    final oldBadges = await BadgeService.getUserBadges(user.id);
    final oldBadgeIds = oldBadges.map((b) => b['badge_id'].toString()).toList();
    int correctCount = 0;
    int answeredCount = 0;
    for (int i = 0; i < widget.questions.length; i++) {
      if (_selectedAnswers[i] != null) answeredCount++;
      if (_selectedAnswers[i] != null &&
          QuizReview.isAnswerCorrect(widget.questions[i], _selectedAnswers[i]))
        correctCount++;
    }
    final safeAccuracy = answeredCount > 0 ? correctCount / answeredCount : 0.0;
    await SupabaseService.saveProgress(
      widget.quizName ?? widget.topic,
      success,
      timeTaken,
      safeAccuracy,
      aiQuestions: widget.questions,
    );
    await _checkAndShowNewBadges(user.id, oldBadgeIds);
  }

  @override
  void initState() {
    super.initState();
    _currentQuestionIndex = 0;
    _completed = false;
    _selectedAnswers = List<dynamic>.filled(widget.questions.length, null);
    _startTime = DateTime.now();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_perQuestionTime == null) {
      int? timeFromExtra;
      final goRouterState = GoRouterState.of(context);
      if (goRouterState.extra != null &&
          goRouterState.extra is Map &&
          goRouterState.extra is Map<String, dynamic>) {
        final extra = goRouterState.extra as Map<String, dynamic>;
        if (extra['timePerQuestion'] != null) {
          timeFromExtra = extra['timePerQuestion'] as int?;
        }
      }
      int? timeFromArgs;
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map && args['timePerQuestion'] != null) {
        timeFromArgs = args['timePerQuestion'] as int?;
      }
      _perQuestionTime =
          timeFromExtra ?? timeFromArgs ?? (widget.timedMode ? 30 : 0);
      _secondsRemaining = _perQuestionTime!;
      if (widget.timedMode) {
        WidgetsBinding.instance.addPostFrameCallback(
            (_) => setState(() => _secondsRemaining = _perQuestionTime!));
        _startTimer();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    if (_disposed) return;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_disposed) {
        timer.cancel();
        return;
      }
      if (_secondsRemaining > 0 && !_completed && mounted) {
        setState(() => _secondsRemaining--);
      } else if (!_completed && mounted) {
        timer.cancel();
        setState(() => _secondsRemaining = 0);
        _nextQuestion(false);
      } else {
        timer.cancel();
      }
    });
  }

  void _nextQuestion(bool success, [dynamic answer]) async {
    if (_currentQuestionIndex < widget.questions.length) {
      _selectedAnswers[_currentQuestionIndex] = answer;
    }
    if (_currentQuestionIndex < widget.questions.length - 1) {
      if (mounted) {
        setState(() {
          _currentQuestionIndex++;
          _secondsRemaining = _perQuestionTime!;
        });
        if (widget.timedMode) {
          _startTimer();
        }
      }
    } else {
      if (mounted) {
        _timer?.cancel();
        final user = SupabaseService.client.auth.currentUser;
        int correctCount = 0;
        int answeredCount = 0;
        for (int i = 0; i < widget.questions.length; i++) {
          if (_selectedAnswers[i] != null) answeredCount++;
          if (_selectedAnswers[i] != null &&
              QuizReview.isAnswerCorrect(
                  widget.questions[i], _selectedAnswers[i])) correctCount++;
        }
        final safeAccuracy =
            answeredCount > 0 ? (correctCount / answeredCount) : 0.0;
        final timeTaken = DateTime.now().difference(_startTime).inSeconds;
        setState(() {
          _completed = true;
          _finalCorrectCount = correctCount;
          _finalAnsweredCount = answeredCount;
          _finalAccuracy = safeAccuracy;
          _finalTimeTaken = timeTaken;
        });
        if (user != null) {
          try {
            await SupabaseService.saveQuizProgress(
              widget.quizName ?? widget.topic,
              widget.quizName ?? widget.topic,
              widget.questions,
              _finalCorrectCount >= (widget.questions.length / 2),
              _finalTimeTaken,
              _finalAccuracy,
              correctCount: _finalCorrectCount,
              totalCount: widget.questions.length,
            );
            try {
              final bool advanced =
                  await SupabaseService.checkAndAdvancePathStep(user.id);
              if (advanced && mounted) {
                debugPrint("Quiz completion triggered path advancement!");
                ref.invalidate(userPathProvider);
                ref.invalidate(activeLearningPathProvider(user.id));
                ref.invalidate(userPathChallengesProvider);
              }
            } catch (e) {
              debugPrint("Error checking for path advancement after quiz: $e");
            }
          } catch (error) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text('Oops! Failed to save progress: $error')),
              );
            }
          }
        } else {
          debugPrint(
              "User not logged in, skipping progress save and path check.");
        }
        if (_selectedAnswers.isEmpty || widget.questions.isEmpty) {
          debugPrint(
              'WARNING: selectedAnswers or questions are empty at quiz end!');
        }
      }
    }
  }

  Widget _buildChallenge() {
    final currentQuestion = widget.questions[_currentQuestionIndex];
    final type = currentQuestion['type']?.toString().toLowerCase() ??
        (currentQuestion['options'] != null
            ? 'mcq'
            : (currentQuestion['solution'] != null ? 'code' : 'input'));
    return Column(
      children: [
        LinearProgressIndicator(
          value: (_currentQuestionIndex + 1) / widget.questions.length,
          backgroundColor: Colors.grey[300],
          valueColor: AlwaysStoppedAnimation<Color>(
              Theme.of(context).colorScheme.primary),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            'Question ${_currentQuestionIndex + 1}/${widget.questions.length}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        Expanded(
          child: Builder(
            builder: (context) {
              switch (type) {
                case 'mcq':
                  return QuizChallenge(
                    key: ValueKey(_currentQuestionIndex),
                    question: currentQuestion['question'],
                    options: List<String>.from(currentQuestion['options']),
                    onSubmitted: (answer) {
                      _selectedAnswers[_currentQuestionIndex] = answer;
                      _nextQuestion(
                        QuizReview.isAnswerCorrect(currentQuestion, answer),
                        answer,
                      );
                    },
                  );
                case 'input':
                case 'fill_blank':
                  return InputChallenge(
                    key: ValueKey(_currentQuestionIndex),
                    question: currentQuestion['question'],
                    solution: currentQuestion['solution'] ??
                        currentQuestion['answer'] ??
                        '',
                    onSubmitted: (answer) {
                      _selectedAnswers[_currentQuestionIndex] = answer;
                      _nextQuestion(
                        QuizReview.isAnswerCorrect(currentQuestion, answer),
                        answer,
                      );
                    },
                  );
                case 'code':
                  return CodingChallenge(
                    key: ValueKey(_currentQuestionIndex),
                    question: currentQuestion['question'],
                    solution: currentQuestion['solution'] ?? '',
                    starterCode: currentQuestion['starter_code'] ?? '',
                    onSubmitted: (answer) {
                      _selectedAnswers[_currentQuestionIndex] = answer;
                      _nextQuestion(
                        QuizReview.isAnswerCorrect(currentQuestion, answer),
                        answer,
                      );
                    },
                  );
                default:
                  debugPrint('Warning: Unknown question type: $type');
                  return const Center(child: Text('Unknown question type'));
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildResult() {
    return Builder(
      builder: (context) {
        final String? challengeId = widget.questions.isNotEmpty
            ? widget.questions[0]['id']?.toString()
            : null;
        return FutureBuilder<Map<String, dynamic>?>(
          future: (SupabaseService.client.auth.currentUser != null &&
                  challengeId != null)
              ? ChallengeAnalyticsService.getChallengeAnalytics(
                  userId: SupabaseService.client.auth.currentUser!.id,
                  challengeId: challengeId,
                )
              : Future.value(null),
          builder: (context, snapshot) {
            final analytics = snapshot.data ?? {};
            final bestTime = analytics['best_time'] ?? 0;
            final bestAccuracy = analytics['best_accuracy'] ?? 0.0;
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(
                  _finalCorrectCount > (widget.questions.length / 2)
                      ? Icons.emoji_events
                      : Icons.sentiment_satisfied,
                  color: _finalCorrectCount > (widget.questions.length / 2)
                      ? Colors.amber
                      : Colors.grey,
                  size: 64,
                ),
                const SizedBox(height: 18),
                Text(
                  _finalCorrectCount > (widget.questions.length / 2)
                      ? 'Congratulations!'
                      : 'Good Try!',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Text(
                  _finalCorrectCount > (widget.questions.length / 2)
                      ? 'You completed the challenge.'
                      : 'You can always try again to improve your score.',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 26),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnalyticsBadge(
                      icon: Icons.check_circle,
                      label: 'Correct',
                      value: '$_finalCorrectCount/$_finalAnsweredCount',
                      color: Colors.green,
                    ),
                    const SizedBox(width: 14),
                    AnalyticsBadge(
                      icon: Icons.timer,
                      label: 'Time',
                      value: widget.timedMode ? '$_finalTimeTaken s' : '-',
                      color: Colors.blue,
                    ),
                    const SizedBox(width: 14),
                    AnalyticsBadge(
                      icon: Icons.bar_chart,
                      label: 'Accuracy',
                      value: '${(_finalAccuracy * 100).toStringAsFixed(1)}%',
                      color: Colors.teal,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnalyticsBadge(
                      icon: Icons.repeat,
                      label: 'Attempts',
                      value: analytics['attempts'] ?? '-',
                      color: Colors.deepPurple,
                    ),
                    const SizedBox(width: 14),
                    AnalyticsBadge(
                      icon: Icons.timer,
                      label: 'Best Time',
                      value: bestTime != 0 ? '${bestTime}s' : '-',
                      color: Colors.blue,
                    ),
                    const SizedBox(width: 14),
                    AnalyticsBadge(
                      icon: Icons.bar_chart,
                      label: 'Best Accuracy',
                      value: '${(bestAccuracy * 100).toStringAsFixed(1)}%',
                      color: Colors.teal,
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => SessionSummaryScreen(
                          questions: widget.questions,
                          selectedAnswers: _selectedAnswers,
                          totalTime: _finalTimeTaken,
                          accuracy: _finalAccuracy,
                          topic: widget.topic,
                          quizName: widget.quizName,
                          userId: SupabaseService.client.auth.currentUser?.id,
                        ),
                      ),
                    );
                  },
                  child: const Text('View Summary'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    _onChallengeCompleted(
                        _finalCorrectCount > (widget.questions.length / 2),
                        _finalTimeTaken,
                        _finalAccuracy);
                    context.pop();
                  },
                  child: Text('Back to Dashboard'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    backgroundColor:
                        _finalCorrectCount > (widget.questions.length / 2)
                            ? Colors.green
                            : null,
                    foregroundColor:
                        _finalCorrectCount > (widget.questions.length / 2)
                            ? Colors.white
                            : null,
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.quizName ?? widget.topic + ' Error'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 50),
                const SizedBox(height: 16),
                Text("Failed to load questions for this challenge.",
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Text("Please go back and try again.",
                    textAlign: TextAlign.center),
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
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.quizName ?? widget.topic + ' Challenge'),
        actions: [
          if (widget.timedMode && !_completed)
            Chip(label: Text('$_secondsRemaining')),
        ],
      ),
      body: _completed ? _buildResult() : _buildChallenge(),
    );
  }
}

class ChallengeScreen extends AIChallengeScreen {
  const ChallengeScreen({
    required String topic,
    required List<Map<String, dynamic>> questions,
    String? quizName,
    bool timedMode = true,
    Key? key,
  }) : super(
          topic: topic,
          questions: questions,
          quizName: quizName,
          timedMode: timedMode,
          key: key,
        );
}
