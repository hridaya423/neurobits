import 'package:flutter/material.dart';
import 'package:neurobits/core/widgets/latex_text.dart';
import 'package:neurobits/services/ai_service.dart';
import 'package:neurobits/features/challenges/screens/quiz_screen.dart';

class QuizReviewScreen extends StatefulWidget {
  final List<Map<String, dynamic>> questions;
  final List<dynamic> selectedAnswers;
  final String? quizName;
  final String? topic;
  const QuizReviewScreen({
    super.key,
    required this.questions,
    required this.selectedAnswers,
    this.quizName,
    this.topic,
  });
  @override
  State<QuizReviewScreen> createState() => _QuizReviewScreenState();
}

class _QuizReviewScreenState extends State<QuizReviewScreen> {
  List<String?> _explanations = [];
  List<bool> _loading = [];
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
          final isCorrect = QuizReview.isAnswerCorrect(q, rawAnswer);
          return Card(
            elevation: 2,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Q${i + 1}:',
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
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _loading[i] ? null : () => _fetchExplanation(i),
                    icon: const Icon(Icons.lightbulb_outline),
                    label: const Text('Explain'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.colorScheme.primary,
                      side: BorderSide(
                          color: theme.colorScheme.primary.withOpacity(0.4)),
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
