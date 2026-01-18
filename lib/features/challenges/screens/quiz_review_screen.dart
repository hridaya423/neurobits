import 'package:flutter/material.dart';
import 'package:neurobits/services/ai_service.dart';

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
      final explanation =
          await AIService.explainAnswer(questionText, solution);
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
          final userAnswer = widget.selectedAnswers[i]?.toString() ?? '';
          String correctAnswer;
          if (q['solution'] is int && q['options'] != null) {
            final opts = List<dynamic>.from(q['options']);
            correctAnswer = opts[q['solution'] as int].toString();
          } else if (q['solution'] != null) {
            correctAnswer = q['solution'].toString();
          } else if (q['answer'] != null) {
            correctAnswer = q['answer'].toString();
          } else {
            correctAnswer = '';
          }
          final isCorrect = userAnswer.trim().toLowerCase() ==
              correctAnswer.trim().toLowerCase();
          return Card(
            elevation: 2,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Q${i + 1}: ${q['question'] ?? ''}',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('Your Answer: $userAnswer',
                      style: TextStyle(
                          color: isCorrect ? Colors.green : Colors.red,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  if (!isCorrect)
                    Text('Correct Answer: $correctAnswer',
                        style: const TextStyle(
                            color: Colors.green, fontWeight: FontWeight.w600)),
                  if (isCorrect)
                    const Text('Correct!',
                        style: TextStyle(
                            color: Colors.green, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    onPressed: _loading[i] ? null : () => _fetchExplanation(i),
                    icon: const Icon(Icons.lightbulb),
                    label: const Text('Explain'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey,
                        foregroundColor: Colors.white),
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
                          child: Text(_explanations[i]!,
                              style: const TextStyle(
                                  fontSize: 15, color: Colors.white)),
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
