import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:neurobits/core/providers.dart';
import 'package:neurobits/core/learning_path_providers.dart';
import 'package:neurobits/services/convex_client_service.dart';
import '../widgets/quiz_challenge.dart';
import '../widgets/coding_challenge.dart';
import '../widgets/input_challenge.dart';
import '../widgets/multi_select_challenge.dart';
import '../widgets/ordering_challenge.dart';
import 'package:neurobits/features/challenges/screens/session_summary_screen.dart';

class AnalyticsBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final dynamic value;
  final String? secondaryLabel;
  final String? secondaryValue;
  final Color color;
  const AnalyticsBadge(
      {super.key,
      required this.icon,
      required this.label,
      required this.value,
      required this.color,
      this.secondaryLabel,
      this.secondaryValue});
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasSecondary = secondaryValue != null && secondaryValue!.isNotEmpty;
    return Card(
      color: colorScheme.surfaceContainerHighest.withOpacity(0.22),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 112),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const Spacer(),
                  Icon(icon, color: color, size: 18),
                ],
              ),
              const SizedBox(height: 8),
              Text('$value',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Visibility(
                visible: hasSecondary,
                maintainState: true,
                maintainAnimation: true,
                maintainSize: true,
                child: Text(
                  hasSecondary
                      ? '${secondaryLabel ?? 'Avg'} $secondaryValue'
                      : ' ',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class QuizReview extends StatelessWidget {
  final List<Map<String, dynamic>> questions;
  final List<dynamic> selectedAnswers;
  const QuizReview(
      {super.key, required this.questions, required this.selectedAnswers});

  static String _normalizeText(dynamic value) {
    return value?.toString().trim().toLowerCase() ?? '';
  }

  static List<String> _extractOptions(Map<String, dynamic> q) {
    final raw = q['options'] ?? q['items'];
    if (raw is! List) return const <String>[];
    return raw
        .map((e) => e is String
            ? e
            : (e is Map ? e['text']?.toString() : e?.toString()))
        .whereType<String>()
        .toList();
  }

  static List<String> _answerAsStringList(dynamic value,
      {required List<String> options}) {
    if (value is List) {
      return value
          .map((e) {
            if (e is num) {
              final idx = e.toInt();
              if (idx >= 0 && idx < options.length) {
                return options[idx];
              }
              return null;
            }
            if (e is Map && e['text'] != null) return e['text'].toString();
            return e?.toString();
          })
          .whereType<String>()
          .toList();
    }
    if (value is num) {
      final idx = value.toInt();
      if (idx >= 0 && idx < options.length) {
        return [options[idx]];
      }
      return const <String>[];
    }
    if (value is String && value.trim().isNotEmpty) {
      return [value];
    }
    return const <String>[];
  }

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
        final options = q['options'] != null ? toList(q['options']) : null;
        if (options != null && options.isNotEmpty) {
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
      case 'multi_select':
        final options = _extractOptions(q);
        final expected = _answerAsStringList(correctAnswer, options: options)
            .map(_normalizeText)
            .where((value) => value.isNotEmpty)
            .toSet();
        final actual = _answerAsStringList(userAnswer, options: options)
            .map(_normalizeText)
            .where((value) => value.isNotEmpty)
            .toSet();
        return expected.isNotEmpty &&
            expected.length == actual.length &&
            expected.containsAll(actual);
      case 'ordering':
        final options = _extractOptions(q);
        final expected = _answerAsStringList(correctAnswer, options: options)
            .map(_normalizeText)
            .where((value) => value.isNotEmpty)
            .toList();
        final actual = _answerAsStringList(userAnswer, options: options)
            .map(_normalizeText)
            .where((value) => value.isNotEmpty)
            .toList();
        if (expected.isEmpty || expected.length != actual.length) return false;
        for (int i = 0; i < expected.length; i++) {
          if (expected[i] != actual[i]) return false;
        }
        return true;
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
  final bool hintsEnabled;

  final String? challengeId;

  final String? userPathChallengeId;
  const AIChallengeScreen({
    required this.topic,
    required this.questions,
    this.quizName,
    this.timedMode = true,
    this.hintsEnabled = false,
    this.challengeId,
    this.userPathChallengeId,
    super.key,
  });
  @override
  ConsumerState<AIChallengeScreen> createState() => _AIChallengeScreenState();
}

class _AIChallengeScreenState extends ConsumerState<AIChallengeScreen> {
  late List<Map<String, dynamic>> _questions;
  late int _secondsRemaining;
  bool _completed = false;
  int _currentQuestionIndex = 0;
  bool _disposed = false;
  bool _isSubmitting = false;
  List<dynamic> _selectedAnswers = [];
  Timer? _timer;
  late DateTime _startTime;
  int? _perQuestionTime;
  int _finalCorrectCount = 0;
  int _finalAnsweredCount = 0;
  double _finalAccuracy = 0.0;
  int _finalTimeTaken = 0;

  String _currentQuestionHint(Map<String, dynamic> question) {
    final hint = question['hint']?.toString().trim() ?? '';
    return hint;
  }

  IconData _badgeIcon(String? iconKey) {
    final key = (iconKey ?? '').toLowerCase().trim();
    switch (key) {
      case 'star':
        return Icons.star;
      case 'trophy':
        return Icons.emoji_events;
      case 'medal':
        return Icons.military_tech;
      case 'crown':
        return Icons.workspace_premium;
      case 'fire':
      case 'flame':
        return Icons.local_fire_department;
      case 'check':
      case 'check-circle':
        return Icons.check_circle;
      case 'zap':
      case 'bolt':
        return Icons.bolt;
      default:
        return Icons.emoji_events;
    }
  }

  Future<void> _showBadgePopup(List<Map<String, dynamic>> newBadges) async {
    if (newBadges.isEmpty || !mounted) return;
    await showDialog(
      context: context,
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: colorScheme.primary.withOpacity(0.18),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child:
                          Icon(Icons.emoji_events, color: colorScheme.primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Achievement unlocked',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'You just earned ${newBadges.length} badge${newBadges.length == 1 ? '' : 's'}.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: newBadges.map((badge) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest
                            .withOpacity(0.35),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: colorScheme.outline.withOpacity(0.2),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_badgeIcon(badge['icon']), size: 16),
                          const SizedBox(width: 6),
                          Text(
                            badge['name']?.toString() ?? 'New badge',
                            style: Theme.of(context)
                                .textTheme
                                .labelMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
                Text(
                  'Check your profile to see all badges.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('OK'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  int _resolveSelectedOptionIndex(int questionIndex) {
    final selected = _selectedAnswers[questionIndex];
    if (selected is int) return selected;
    if (selected is List && selected.isNotEmpty) {
      final first = selected.first;
      if (first is int) return first;
      if (first is String) {
        final optionsRaw = _questions[questionIndex]['options'];
        if (optionsRaw is List) {
          final options = optionsRaw
              .map((e) => e is String
                  ? e
                  : (e is Map ? e['text']?.toString() : e?.toString()))
              .whereType<String>()
              .toList();
          final idx = options.indexOf(first);
          if (idx >= 0) return idx;
        }
      }
    }
    if (selected is String) {
      final optionsRaw = _questions[questionIndex]['options'];
      if (optionsRaw is List) {
        final options = optionsRaw
            .map((e) => e is String
                ? e
                : (e is Map ? e['text']?.toString() : e?.toString()))
            .whereType<String>()
            .toList();
        final idx = options.indexOf(selected);
        if (idx >= 0) return idx;
      }
    }
    return 0;
  }

  Future<void> _recordProgress() async {
    try {
      final challengeId = widget.challengeId;
      final hasChallengeId = challengeId != null && challengeId.isNotEmpty;
      final badgeRepo = ref.read(badgeRepositoryProvider);
      Set<String?> oldBadgeIds = {};
      if (hasChallengeId) {
        final oldBadges = await badgeRepo.listMine();
        oldBadgeIds = oldBadges.map((b) {
          final badge = b['badge'] as Map<String, dynamic>?;
          return badge?['_id']?.toString();
        }).toSet();
      }

      final answers = <Map<String, dynamic>>[];
      final perQuestionSeconds = _questions.isEmpty
          ? 0
          : (_finalTimeTaken / _questions.length).round();
      for (int i = 0; i < _questions.length; i++) {
        final isCorrect =
            QuizReview.isAnswerCorrect(_questions[i], _selectedAnswers[i]);
        answers.add({
          'questionIndex': i,
          'selectedOption': _resolveSelectedOptionIndex(i),
          'isCorrect': isCorrect,
          'timeSpentSeconds': perQuestionSeconds,
        });
      }

      if (hasChallengeId) {
        final progressRepo = ref.read(progressRepositoryProvider);
        await progressRepo.recordQuizCompletion(
          challengeId: challengeId,
          completed: _finalAccuracy >= 0.75,
          attempts: 1,
          timeTakenSeconds: _finalTimeTaken,
          accuracy: _finalAccuracy,
          answers: answers,
        );
      }

      final userPathChallengeId = widget.userPathChallengeId;
      if (userPathChallengeId != null && userPathChallengeId.isNotEmpty) {
        try {
          final pathRepo = ref.read(pathRepositoryProvider);
          await pathRepo.markPathChallengeComplete(
            challengeId: userPathChallengeId,
            accuracy: _finalAccuracy,
          );
          final userPath = ref.read(userPathProvider);
          final userPathId = userPath?['user_path_id']?.toString() ??
              userPath?['_id']?.toString();
          if (userPathId != null) {
            ref.invalidate(userPathChallengesProvider(userPathId));
          }
        } catch (e) {
          debugPrint('Error marking path challenge complete: $e');
          final message = e.toString();
          if (mounted && message.contains('Path challenge not found')) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                    'That path challenge no longer exists. Refreshing your path.'),
              ),
            );
            ref.invalidate(userPathProvider);
            ref.invalidate(activeLearningPathProvider);
            final userPath = ref.read(userPathProvider);
            final userPathId = userPath?['user_path_id']?.toString() ??
                userPath?['_id']?.toString();
            if (userPathId != null) {
              try {
                final pathRepo = ref.read(pathRepositoryProvider);
                final challenges = await pathRepo.listChallengesForPath(
                    userPathId: userPathId);
                final topic = widget.topic.toLowerCase().trim();
                final fallback = challenges.firstWhere(
                  (c) {
                    final chTopic =
                        c['topic']?.toString().toLowerCase().trim() ?? '';
                    return chTopic == topic && c['completed'] != true;
                  },
                  orElse: () => <String, dynamic>{},
                );
                if (fallback.isNotEmpty && fallback['_id'] != null) {
                  await pathRepo.markPathChallengeComplete(
                    challengeId: fallback['_id']?.toString() ?? '',
                    accuracy: _finalAccuracy,
                  );
                  ref.invalidate(userPathChallengesProvider(userPathId));
                }
              } catch (fallbackError) {
                debugPrint('Fallback path completion failed: $fallbackError');
              }
            }
          }
        }
      }

      final newBadges = await badgeRepo.listMine();
      final newlyEarned = newBadges.where((b) {
        final badge = b['badge'] as Map<String, dynamic>?;
        final id = badge?['_id']?.toString();
        return id != null && !oldBadgeIds.contains(id);
      }).toList();

      if (hasChallengeId && newlyEarned.isNotEmpty && mounted) {
        final badgeInfoList = newlyEarned.map((b) {
          final badge = b['badge'] as Map<String, dynamic>? ?? {};
          return badge;
        }).toList();
        await _showBadgePopup(badgeInfoList);
      }

      try {
        final userPathChallengeId = widget.userPathChallengeId;
        if (userPathChallengeId != null && userPathChallengeId.isNotEmpty) {
          ref.invalidate(userPathProvider);
          ref.invalidate(activeLearningPathProvider);
          final userPath = ref.read(userPathProvider);
          final userPathId = userPath?['user_path_id']?.toString() ??
              userPath?['_id']?.toString();
          if (userPathId != null) {
            ref.invalidate(userPathChallengesProvider(userPathId));
          }
        }
      } catch (e) {
        debugPrint('Error refreshing path state after quiz: $e');
      }

      ref.invalidate(userStatsProvider);

      try {
        final isPathQuiz = widget.userPathChallengeId != null &&
            widget.userPathChallengeId!.isNotEmpty;
        final activePath = await ref.read(activeLearningPathProvider.future);
        if (!isPathQuiz && activePath == null) {
          ref.read(pendingRecommendationsRefreshProvider.notifier).state = true;
        }
      } catch (e) {
        debugPrint('Error checking active path for rec refresh: $e');
      }
    } catch (e) {
      debugPrint('Error recording progress: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save progress: $e')),
        );
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _questions = widget.questions
        .map((q) => Map<String, dynamic>.from(q))
        .toList(growable: false);
    _currentQuestionIndex = 0;
    _completed = false;
    _selectedAnswers = List<dynamic>.filled(_questions.length, null);
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
          timeFromExtra = extra['timePerQuestion'] is num
              ? (extra['timePerQuestion'] as num).toInt()
              : null;
        }
      }
      int? timeFromArgs;
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map && args['timePerQuestion'] != null) {
        timeFromArgs = args['timePerQuestion'] is num
            ? (args['timePerQuestion'] as num).toInt()
            : null;
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
    if (_disposed || _completed) return;
    if (_currentQuestionIndex < _questions.length) {
      _selectedAnswers[_currentQuestionIndex] = answer;
      _questions[_currentQuestionIndex]['userAnswer'] = answer;
    }
    if (_currentQuestionIndex < _questions.length - 1) {
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
      if (_isSubmitting) return;
      _isSubmitting = true;
      _timer?.cancel();
      int correctCount = 0;
      int answeredCount = 0;
      for (int i = 0; i < _questions.length; i++) {
        if (_selectedAnswers[i] != null) answeredCount++;
        if (_selectedAnswers[i] != null &&
            QuizReview.isAnswerCorrect(_questions[i], _selectedAnswers[i])) {
          correctCount++;
        }
      }
      final safeAccuracy =
          answeredCount > 0 ? (correctCount / answeredCount) : 0.0;
      final timeTaken = DateTime.now().difference(_startTime).inSeconds;
      if (mounted) {
        setState(() {
          _completed = true;
          _finalCorrectCount = correctCount;
          _finalAnsweredCount = answeredCount;
          _finalAccuracy = safeAccuracy;
          _finalTimeTaken = timeTaken;
        });
      }

      await _recordProgress();
      if (mounted) {
        setState(() {});
      }

      if (_selectedAnswers.isEmpty || _questions.isEmpty) {
        debugPrint(
            'WARNING: selectedAnswers or questions are empty at quiz end!');
      }
      _isSubmitting = false;
    }
  }

  Widget _buildChallenge() {
    final currentQuestion = _questions[_currentQuestionIndex];
    final type = currentQuestion['type']?.toString().toLowerCase() ??
        (currentQuestion['options'] != null
            ? 'mcq'
            : (currentQuestion['solution'] != null ? 'code' : 'input'));
    final hint = _currentQuestionHint(currentQuestion);
    final effectiveHint =
        (widget.hintsEnabled && hint.isNotEmpty) ? hint : null;
    final imageUrl = currentQuestion['imageUrl']?.toString().trim() ?? '';
    final effectiveImageUrl = imageUrl.isNotEmpty ? imageUrl : null;
    final rawChartSpec =
        currentQuestion['chartSpec'] ?? currentQuestion['chart_spec'];
    final effectiveChartSpec =
        rawChartSpec is Map ? Map<String, dynamic>.from(rawChartSpec) : null;
    return Stack(
      children: [
        Column(
          children: [
            LinearProgressIndicator(
              value: (_currentQuestionIndex + 1) / _questions.length,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(
                  Theme.of(context).colorScheme.primary),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                'Question ${_currentQuestionIndex + 1}/${_questions.length}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Expanded(
              child: Builder(
                builder: (context) {
                  switch (type) {
                    case 'mcq':
                      final optionsRaw = currentQuestion['options'];
                      final options = optionsRaw is List
                          ? optionsRaw
                              .map((e) => e is String
                                  ? e
                                  : (e is Map
                                      ? e['text']?.toString()
                                      : e?.toString()))
                              .whereType<String>()
                              .toList()
                          : <String>[];
                      if (options.isEmpty) {
                        return const Center(
                            child: Text('Invalid multiple-choice options'));
                      }
                      return QuizChallenge(
                        key: ValueKey(_currentQuestionIndex),
                        question: currentQuestion['question'],
                        hint: effectiveHint,
                        imageUrl: effectiveImageUrl,
                        chartSpec: effectiveChartSpec,
                        options: options,
                        isDisabled: _isSubmitting,
                        onSubmitted: (answer) {
                          if (_isSubmitting) return;
                          _selectedAnswers[_currentQuestionIndex] = answer;
                          _nextQuestion(
                            QuizReview.isAnswerCorrect(currentQuestion, answer),
                            answer,
                          );
                        },
                      );
                    case 'multi_select':
                      final optionsRaw = currentQuestion['options'];
                      final options = optionsRaw is List
                          ? optionsRaw
                              .map((e) => e is String
                                  ? e
                                  : (e is Map
                                      ? e['text']?.toString()
                                      : e?.toString()))
                              .whereType<String>()
                              .toList()
                          : <String>[];
                      if (options.length < 2) {
                        return const Center(
                          child: Text('Invalid multi-select options'),
                        );
                      }
                      return MultiSelectChallenge(
                        key: ValueKey(_currentQuestionIndex),
                        question: currentQuestion['question']?.toString() ?? '',
                        hint: effectiveHint,
                        imageUrl: effectiveImageUrl,
                        chartSpec: effectiveChartSpec,
                        options: options,
                        isDisabled: _isSubmitting,
                        onSubmitted: (answers) {
                          if (_isSubmitting) return;
                          _selectedAnswers[_currentQuestionIndex] = answers;
                          _nextQuestion(
                            QuizReview.isAnswerCorrect(
                                currentQuestion, answers),
                            answers,
                          );
                        },
                      );
                    case 'ordering':
                      final optionsRaw = currentQuestion['options'] ??
                          currentQuestion['items'];
                      final options = optionsRaw is List
                          ? optionsRaw
                              .map((e) => e is String
                                  ? e
                                  : (e is Map
                                      ? e['text']?.toString()
                                      : e?.toString()))
                              .whereType<String>()
                              .toList()
                          : <String>[];
                      if (options.length < 2) {
                        return const Center(
                          child: Text('Invalid ordering items'),
                        );
                      }
                      return OrderingChallenge(
                        key: ValueKey(_currentQuestionIndex),
                        question: currentQuestion['question']?.toString() ?? '',
                        hint: effectiveHint,
                        imageUrl: effectiveImageUrl,
                        chartSpec: effectiveChartSpec,
                        items: options,
                        isDisabled: _isSubmitting,
                        onSubmitted: (orderedItems) {
                          if (_isSubmitting) return;
                          _selectedAnswers[_currentQuestionIndex] =
                              orderedItems;
                          _nextQuestion(
                            QuizReview.isAnswerCorrect(
                                currentQuestion, orderedItems),
                            orderedItems,
                          );
                        },
                      );
                    case 'input':
                    case 'fill_blank':
                      return InputChallenge(
                        key: ValueKey(_currentQuestionIndex),
                        question: currentQuestion['question'],
                        hint: effectiveHint,
                        imageUrl: effectiveImageUrl,
                        chartSpec: effectiveChartSpec,
                        solution: currentQuestion['solution'] ??
                            currentQuestion['answer'] ??
                            '',
                        isDisabled: _isSubmitting,
                        onSubmitted: (answer) {
                          if (_isSubmitting) return;
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
                        hint: effectiveHint,
                        imageUrl: effectiveImageUrl,
                        chartSpec: effectiveChartSpec,
                        solution: currentQuestion['solution'] ?? '',
                        starterCode: currentQuestion['starter_code'] ?? '',
                        isDisabled: _isSubmitting,
                        onSubmitted: (answer) {
                          if (_isSubmitting) return;
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
        ),
        if (_isSubmitting && !_completed)
          Positioned.fill(
            child: ColoredBox(
              color: Colors.black.withOpacity(0.1),
              child: const Center(child: CircularProgressIndicator()),
            ),
          ),
      ],
    );
  }

  Widget _buildResult() {
    final String? challengeId = widget.challengeId;
    final String topicName = widget.topic.trim();

    return Builder(
      builder: (context) {
        if (topicName.isNotEmpty) {
          return FutureBuilder<Map<String, dynamic>>(
            future: ref
                .read(progressRepositoryProvider)
                .getTopicAnalytics(topic: topicName),
            builder: (context, snapshot) {
              final analytics = snapshot.data ?? {};
              return _buildResultContent(analytics);
            },
          );
        }
        if (challengeId != null && challengeId.isNotEmpty) {
          return FutureBuilder<Map<String, dynamic>>(
            future: ref
                .read(progressRepositoryProvider)
                .getChallengeAnalytics(challengeId: challengeId),
            builder: (context, snapshot) {
              final analytics = snapshot.data ?? {};
              return _buildResultContent(analytics);
            },
          );
        }
        return _buildResultContent({});
      },
    );
  }

  Widget _buildResultContent(Map<String, dynamic> analytics) {
    final avgTimeSeconds = analytics['avgTimeSeconds'] ?? 0;
    final avgAccuracy = analytics['avgAccuracy'] ?? 0.0;
    final bestAccuracy = analytics['bestAccuracy'] ?? 0.0;
    final bestTimeSeconds = analytics['bestTimeSeconds'] ?? 0;
    final lastAttemptedAt = analytics['lastAttemptedAt'] ?? 0;
    final totalAttempts = analytics['totalAttempts'] is num
        ? (analytics['totalAttempts'] as num).toInt()
        : 0;
    String? lastAttemptText;
    if (lastAttemptedAt is num && lastAttemptedAt > 0) {
      final last = DateTime.fromMillisecondsSinceEpoch(lastAttemptedAt.toInt());
      final diff = DateTime.now().difference(last);
      if (diff.inMinutes < 60) {
        lastAttemptText = '${diff.inMinutes}m ago';
      } else if (diff.inHours < 24) {
        lastAttemptText = '${diff.inHours}h ago';
      } else {
        lastAttemptText = '${diff.inDays}d ago';
      }
    }

    final bestAccuracyText = bestAccuracy is num && totalAttempts > 0
        ? '${(bestAccuracy * 100).toStringAsFixed(1)}%'
        : null;
    final bestTimeText = bestTimeSeconds is num && bestTimeSeconds > 0
        ? '${bestTimeSeconds.toStringAsFixed(0)}s'
        : null;
    final avgTimeText = totalAttempts > 0
        ? '${(avgTimeSeconds as num).toStringAsFixed(0)}s'
        : null;
    final avgAccuracyText = totalAttempts > 0
        ? '${((avgAccuracy as num) * 100).toStringAsFixed(1)}%'
        : null;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(
          _finalCorrectCount > (_questions.length / 2)
              ? Icons.emoji_events
              : Icons.sentiment_satisfied,
          color: _finalCorrectCount > (_questions.length / 2)
              ? Colors.amber
              : Colors.grey,
          size: 64,
        ),
        const SizedBox(height: 18),
        Text(
          _finalCorrectCount > (_questions.length / 2)
              ? 'Congratulations!'
              : 'Good Try!',
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        Text(
          _finalCorrectCount > (_questions.length / 2)
              ? 'You completed the challenge.'
              : 'You can always try again to improve your score.',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 26),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: AnalyticsBadge(
                  icon: Icons.check_circle,
                  label: 'Correct',
                  value: '$_finalCorrectCount/$_finalAnsweredCount',
                  secondaryLabel: 'Best',
                  secondaryValue: bestAccuracyText,
                  color: Colors.green,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AnalyticsBadge(
                  icon: Icons.timer,
                  label: 'Time',
                  value: widget.timedMode ? '$_finalTimeTaken s' : '-',
                  secondaryLabel: 'Avg',
                  secondaryValue: avgTimeText,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AnalyticsBadge(
                  icon: Icons.bar_chart,
                  label: 'Accuracy',
                  value: '${(_finalAccuracy * 100).toStringAsFixed(1)}%',
                  secondaryLabel: 'Avg',
                  secondaryValue: avgAccuracyText,
                  color: Colors.teal,
                ),
              ),
            ],
          ),
        ),
        if (totalAttempts > 0) ...[
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Card(
              color: Theme.of(context)
                  .colorScheme
                  .surfaceContainerHighest
                  .withOpacity(0.22),
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    Icon(Icons.repeat, color: Colors.deepPurple, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Attempts',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '$totalAttempts',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const Spacer(),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Best acc ${bestAccuracyText ?? '--'}',
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                        ),
                        Text(
                          'Best time ${bestTimeText ?? '--'}',
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                        ),
                        Text(
                          'Last ${lastAttemptText ?? '--'}',
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 32),
        ElevatedButton(
          onPressed: () async {
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => SessionSummaryScreen(
                  questions: _questions,
                  selectedAnswers: _selectedAnswers,
                  totalTime: _finalTimeTaken,
                  accuracy: _finalAccuracy,
                  topic: widget.topic,
                  quizName: widget.quizName,
                ),
              ),
            );
          },
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            backgroundColor: Colors.deepPurple,
            foregroundColor: Colors.white,
          ),
          child: const Text('View Summary'),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: () {
            context.pop();
          },
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            backgroundColor: _finalCorrectCount > (_questions.length / 2)
                ? Colors.green
                : null,
            foregroundColor: _finalCorrectCount > (_questions.length / 2)
                ? Colors.white
                : null,
          ),
          child: Text('Back to Dashboard'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.quizName ?? '${widget.topic} Error'),
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
        title: Text(widget.quizName ?? '${widget.topic} Challenge'),
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
    required super.topic,
    required super.questions,
    super.quizName,
    super.timedMode,
    super.hintsEnabled,
    super.challengeId,
    super.userPathChallengeId,
    super.key,
  });
}
