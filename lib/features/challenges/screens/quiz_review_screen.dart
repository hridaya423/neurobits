import 'package:flutter/material.dart';
import 'package:neurobits/core/widgets/latex_text.dart';
import 'package:neurobits/services/ai_service.dart';
import 'package:neurobits/features/challenges/screens/quiz_screen.dart';

class QuizReviewScreen extends StatefulWidget {
  final List<Map<String, dynamic>> questions;
  final List<dynamic> selectedAnswers;
  final String? quizName;
  final String? topic;
  final bool examMode;
  const QuizReviewScreen({
    super.key,
    required this.questions,
    required this.selectedAnswers,
    this.quizName,
    this.topic,
    this.examMode = false,
  });
  @override
  State<QuizReviewScreen> createState() => _QuizReviewScreenState();
}

class _QuizReviewScreenState extends State<QuizReviewScreen> {
  List<String?> _explanations = [];
  List<bool> _loading = [];

  static const Set<String> _genericFallbackReasons = {
    'the response did not match the expected answer.',
    'answer did not match the expected answer.',
    'the response did not satisfy all expected criteria.',
    'answer did not satisfy the mark-scheme criteria.',
  };
  @override
  void initState() {
    super.initState();
    _explanations = List<String?>.filled(widget.questions.length, null);
    _loading = List<bool>.filled(widget.questions.length, false);
  }

  String _optionText(dynamic option) {
    if (option is Map && option['text'] != null) {
      return option['text'].toString();
    }
    return option?.toString() ?? '';
  }

  String _formatAnswer(Map<String, dynamic> q, dynamic rawAnswer) {
    if (rawAnswer == null) return '';
    final type = q['type']?.toString().toLowerCase() ?? '';
    final isOrdering = type == 'ordering';

    if (rawAnswer is List) {
      final options = q['options'];
      final values = rawAnswer
          .map((entry) {
            if (entry is num && options is List) {
              final index = entry.toInt();
              if (index >= 0 && index < options.length) {
                return _optionText(options[index]);
              }
              return null;
            }
            if (entry is Map && entry['text'] != null) {
              return entry['text'].toString();
            }
            return entry?.toString();
          })
          .whereType<String>()
          .toList();
      if (values.isEmpty) return '';
      return isOrdering ? values.join(' → ') : values.join(', ');
    }
    if (rawAnswer is String) return rawAnswer;
    final options = q['options'];
    if (rawAnswer is num && options is List) {
      final index = rawAnswer.toInt();
      if (index >= 0 && index < options.length) {
        return _optionText(options[index]);
      }
    }
    if (rawAnswer is Map && rawAnswer['text'] != null) {
      return rawAnswer['text'].toString();
    }
    return rawAnswer.toString();
  }

  dynamic _resolveUserAnswer(Map<String, dynamic> q, int index) {
    dynamic answer = index < widget.selectedAnswers.length
        ? widget.selectedAnswers[index]
        : null;
    if ((answer == null || (answer is String && answer.trim().isEmpty)) &&
        q['userAnswer'] != null) {
      answer = q['userAnswer'];
    }
    return answer;
  }

  String _formatCorrectAnswer(Map<String, dynamic> q) {
    final type = q['type']?.toString().toLowerCase() ?? '';
    final isOrdering = type == 'ordering';

    final answerList = q['answer'] ?? q['solution'];
    if (answerList is List) {
      final options = q['options'];
      final values = answerList
          .map((entry) {
            if (entry is num && options is List) {
              final index = entry.toInt();
              if (index >= 0 && index < options.length) {
                return _optionText(options[index]);
              }
              return null;
            }
            if (entry is Map && entry['text'] != null) {
              return entry['text'].toString();
            }
            return entry?.toString();
          })
          .whereType<String>()
          .toList();
      if (values.isNotEmpty) {
        return isOrdering ? values.join(' → ') : values.join(', ');
      }
    }

    final options = q['options'];
    if (q['solution'] is num && options is List) {
      final index = (q['solution'] as num).toInt();
      if (index >= 0 && index < options.length) {
        return _optionText(options[index]);
      }
    }
    if (q['solution'] != null) {
      return _optionText(q['solution']);
    }
    if (q['answer'] != null) {
      return _optionText(q['answer']);
    }
    return '';
  }

  Future<void> _fetchExplanation(int i) async {
    setState(() => _loading[i] = true);
    try {
      final question = widget.questions[i];
      final questionText = question['question'] ?? '';
      final rawSolution = question['solution'] ?? question['answer'] ?? '';
      final solution =
          (question['solution'] is int && question['options'] != null)
              ? (question['options'][question['solution']] as String)
              : rawSolution.toString();
      if (questionText.isEmpty || solution.toString().isEmpty) {
        setState(() {
          _explanations[i] = 'Missing question or solution data.';
          _loading[i] = false;
        });
        return;
      }
      final explanation = await AIService.explainAnswer(questionText, solution);
      if (explanation.trim().isEmpty ||
          explanation.toLowerCase().contains('error')) {
        setState(() {
          _explanations[i] =
              'Could not fetch explanation. (AI returned empty or error)';
          _loading[i] = false;
        });
      } else {
        setState(() {
          _explanations[i] = explanation;
          _loading[i] = false;
        });
      }
    } catch (e) {
      final errMsg = e.toString().contains('OPENROUTER_API_KEY')
          ? 'AI API key not set. Please check configuration.'
          : 'Could not fetch explanation. (${e.toString()})';
      setState(() {
        _explanations[i] = errMsg;
        _loading[i] = false;
      });
    }
  }

  Widget _buildExplanationText(BuildContext context, String text) {
    final theme = Theme.of(context);
    final lines = text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    if (lines.isEmpty) {
      return LaTeXText(text, style: theme.textTheme.bodyMedium);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: lines.map((line) {
        final parts = line.split(':');
        if (parts.length < 2) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: LaTeXText(line, style: theme.textTheme.bodyMedium),
          );
        }
        final label = parts.first.trim();
        final body = parts.skip(1).join(':').trim();
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$label:',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 2),
              LaTeXText(body, style: theme.textTheme.bodyMedium),
            ],
          ),
        );
      }).toList(),
    );
  }

  Map<String, dynamic>? _extractMarkScheme(Map<String, dynamic> question) {
    final raw = question['markScheme'] ?? question['mark_scheme'];
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) {
      return Map<String, dynamic>.from(
        raw.map((key, value) => MapEntry(key.toString(), value)),
      );
    }
    return null;
  }

  List<String> _normalizedStringList(dynamic raw) {
    if (raw is! List) return const <String>[];
    return raw
        .map((item) => item?.toString().trim())
        .whereType<String>()
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList();
  }

  List<String> _criterionAcceptableAnswers(Map<String, dynamic> criterion) {
    return _normalizedStringList(
      criterion['acceptable_answers'] ?? criterion['acceptableAnswers'],
    );
  }

  List<String> _markSchemeAcceptableAnswers(Map<String, dynamic> markScheme) {
    return _normalizedStringList(
      markScheme['acceptable_answers'] ?? markScheme['acceptableAnswers'],
    );
  }

  Widget _buildMarkSchemeCard(
      BuildContext context, Map<String, dynamic> markScheme) {
    final theme = Theme.of(context);
    final totalMarksRaw = markScheme['total_marks'] ?? markScheme['totalMarks'];
    final totalMarks = totalMarksRaw is num ? totalMarksRaw.toInt() : null;
    final criteriaRaw = markScheme['criteria'];
    final criteria = criteriaRaw is List
        ? criteriaRaw
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(
                item.map((k, v) => MapEntry('$k', v))))
            .toList()
        : const <Map<String, dynamic>>[];
    final acceptableAnswers = _markSchemeAcceptableAnswers(markScheme);

    if (totalMarks == null && criteria.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(top: 10, bottom: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color:
            theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            totalMarks == null
                ? 'Mark Scheme'
                : 'Mark Scheme ($totalMarks marks)',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          if (acceptableAnswers.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Acceptable answers',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: acceptableAnswers
                  .take(4)
                  .map((answer) => Chip(label: Text(answer)))
                  .toList(),
            ),
          ],
          if (criteria.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...criteria.take(6).map((criterion) {
              final label = criterion['label']?.toString().trim() ?? 'Criteria';
              final marksRaw = criterion['marks'];
              final marks = marksRaw is num ? marksRaw.toInt() : null;
              final description =
                  criterion['description']?.toString().trim() ?? '';
              final criterionAcceptable =
                  _criterionAcceptableAnswers(criterion);
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: theme.colorScheme.outline.withValues(alpha: 0.18),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        marks == null ? label : '$label ($marks)',
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (description.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(description, style: theme.textTheme.bodySmall),
                      ],
                      if (criterionAcceptable.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Also accept:',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          criterionAcceptable.take(3).join(' • '),
                          style: theme.textTheme.labelSmall,
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  double _questionMarksAvailable(Map<String, dynamic> question) {
    if (!widget.examMode) return 0.0;
    final markScheme = _extractMarkScheme(question);
    if (markScheme == null) return 0.0;
    final totalRaw = markScheme['total_marks'] ?? markScheme['totalMarks'];
    if (totalRaw is num && totalRaw > 0) return totalRaw.toDouble();
    return 0.0;
  }

  double _questionMarksAwarded(Map<String, dynamic> question, bool isCorrect) {
    final stored = question['marksAwarded'];
    if (stored is num && stored >= 0) {
      return stored.toDouble();
    }
    if (!isCorrect) return 0.0;
    return _questionMarksAvailable(question);
  }

  bool _isGenericFallbackReason(String text) {
    final normalized = text.trim().toLowerCase();
    if (normalized.isEmpty) return false;
    if (_genericFallbackReasons.contains(normalized)) return true;
    return normalized.contains('did not match the expected answer') ||
        normalized.contains('did not satisfy all expected criteria');
  }

  String _feedbackReason(Map<String, dynamic> question) {
    final storedReason = question['markReasonDetail']?.toString().trim() ?? '';
    if (storedReason.isNotEmpty) {
      if (!widget.examMode && _isGenericFallbackReason(storedReason)) {
        return '';
      }
      return storedReason;
    }
    final markScheme = _extractMarkScheme(question);
    if (!widget.examMode || markScheme == null) {
      return '';
    }
    final criteriaRaw = markScheme['criteria'];
    if (criteriaRaw is List) {
      final insights = criteriaRaw
          .whereType<Map>()
          .take(2)
          .map((criterion) {
            final label = criterion['label']?.toString().trim() ?? '';
            final desc = criterion['description']?.toString().trim() ?? '';
            if (label.isNotEmpty && desc.isNotEmpty) {
              return '$label: $desc';
            }
            return label.isNotEmpty ? label : desc;
          })
          .where((line) => line.trim().isNotEmpty)
          .toList();
      if (insights.isNotEmpty) {
        return insights.join(' | ');
      }
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('Quiz Review'),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(20),
        itemCount: widget.questions.length,
        separatorBuilder: (_, __) => const SizedBox(height: 18),
        itemBuilder: (context, i) {
          final q = widget.questions[i];
          final rawAnswer = _resolveUserAnswer(q, i);
          final userAnswer = _formatAnswer(q, rawAnswer);
          final displayUserAnswer =
              userAnswer.trim().isEmpty ? 'No answer' : userAnswer;
          final correctAnswer = _formatCorrectAnswer(q);
          final markScheme = _extractMarkScheme(q);
          final isCorrect = QuizReview.isAnswerCorrect(q, rawAnswer);
          final marksAvailable = _questionMarksAvailable(q);
          final marksAwarded = _questionMarksAwarded(q, isCorrect);
          final feedbackReason = _feedbackReason(q);
          return Card(
            elevation: 2,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(() {
                    final marksLabel = marksAvailable > 0
                        ? ' (${marksAvailable.toStringAsFixed(marksAvailable % 1 == 0 ? 0 : 1)})'
                        : '';
                    return 'Q${i + 1}$marksLabel:';
                  }(),
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  LaTeXText(
                    q['question']?.toString() ?? '',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your Answer:',
                    style: TextStyle(
                        color: isCorrect ? Colors.green : Colors.red,
                        fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  LaTeXText(
                    displayUserAnswer,
                    style: TextStyle(
                        color: isCorrect ? Colors.green : Colors.red,
                        fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  if (!isCorrect)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Correct Answer:',
                            style: TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        LaTeXText(
                          correctAnswer,
                          style: const TextStyle(
                              color: Colors.green, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  if (isCorrect)
                    const Text('Correct!',
                        style: TextStyle(
                            color: Colors.green, fontWeight: FontWeight.bold)),
                  if (!isCorrect && marksAvailable > 0 && marksAwarded > 0)
                    const Text('Partial credit awarded.',
                        style: TextStyle(
                            color: Colors.orange, fontWeight: FontWeight.bold)),
                  if (marksAvailable > 0) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Marks: ${marksAwarded.toStringAsFixed(1)}/${marksAvailable.toStringAsFixed(1)}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                  if (!isCorrect &&
                      marksAvailable <= 0 &&
                      feedbackReason.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      feedbackReason,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  if (widget.examMode &&
                      markScheme != null &&
                      marksAvailable > 0)
                    _buildMarkSchemeCard(context, markScheme),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _loading[i] ? null : () => _fetchExplanation(i),
                    icon: const Icon(Icons.lightbulb_outline),
                    label: const Text('Explain'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.colorScheme.primary,
                      side: BorderSide(
                          color:
                              theme.colorScheme.primary.withValues(alpha: 0.4)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                    ),
                  ),
                  if (_loading[i])
                    const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: LinearProgressIndicator(),
                    ),
                  if (_explanations[i] != null)
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Card(
                        color: Colors.grey[900],
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: _buildExplanationText(
                            context,
                            _explanations[i]!,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
