import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neurobits/services/supabase.dart';
import 'package:neurobits/services/groq_service.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:neurobits/features/challenges/screens/quiz_screen.dart';
import 'quiz_review_screen.dart';

class SessionSummaryScreen extends ConsumerStatefulWidget {
  final List<Map<String, dynamic>> questions;
  final List<dynamic> selectedAnswers;
  final int totalTime;
  final double accuracy;
  final String topic;
  final String? quizName;
  final String? userId;
  const SessionSummaryScreen({
    required this.questions,
    required this.selectedAnswers,
    required this.totalTime,
    required this.accuracy,
    required this.topic,
    this.quizName,
    this.userId,
    super.key,
  });
  @override
  ConsumerState<SessionSummaryScreen> createState() =>
      _SessionSummaryScreenState();
}

class _SessionSummaryScreenState extends ConsumerState<SessionSummaryScreen> {
  bool _loading = true;
  String? aiAnalysis;
  @override
  void initState() {
    super.initState();
    _analyzePerformance();
  }

  Future<void> _analyzePerformance() async {
    final summary = _buildAISummary();
    setState(() {
      _loading = true;
      aiAnalysis = null;
    });
    try {
      final String analysis = await GroqService.analyzeQuizPerformance(summary);
      if (widget.userId != null) {
        await SupabaseService.saveSessionAnalysis(
          userId: widget.userId!,
          topic: widget.topic,
          quizName: widget.quizName ?? widget.topic,
          analysis: analysis,
          accuracy: widget.accuracy,
          totalTime: widget.totalTime,
        );
      }
      if (analysis.trim().isNotEmpty) {
        setState(() {
          aiAnalysis = analysis;
          _loading = false;
        });
      } else {
        setState(() {
          aiAnalysis = 'Could not analyze performance. (No analysis returned)';
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        aiAnalysis = 'Could not analyze performance. (${e.toString()})';
        _loading = false;
      });
    }
  }

  int _countCorrect() {
    int correct = 0;
    for (int i = 0; i < widget.questions.length; i++) {
      final q = widget.questions[i];
      final userAns = widget.selectedAnswers[i];
      if (QuizReview.isAnswerCorrect(q, userAns)) correct++;
    }
    return correct;
  }

  String _buildAISummary() {
    final buffer = StringBuffer();
    buffer.writeln('Quiz Topic: ${widget.topic}');
    buffer.writeln('Accuracy: ${(widget.accuracy * 100).toStringAsFixed(1)}%');
    buffer.writeln('Total Time: ${widget.totalTime}s');
    for (int i = 0; i < widget.questions.length; i++) {
      final q = widget.questions[i];
      buffer.writeln('Q${i + 1}: ${q['question'] ?? ''}');
      buffer.writeln('User Answer: ${widget.selectedAnswers[i] ?? ''}');
      buffer.writeln(
          'Correct Answer: ${q['solution'] ?? q['answer'] ?? q['options']?[q['solution']] ?? ''}');
      buffer.writeln('---');
    }
    buffer.writeln(
        'Please provide a concise analysis of the user\'s strengths and weaknesses in this quiz, and suggest what topics or question types they should focus on to improve.');
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Session Summary'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(24.0),
              child: ListView(
                children: [
                  Text('Quiz: ${widget.quizName ?? widget.topic}',
                      style: theme.textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _summaryBadge(
                            Icons.check_circle,
                            'Accuracy',
                            '${(widget.accuracy * 100).toStringAsFixed(1)}%',
                            Colors.green),
                        _summaryBadge(Icons.timer, 'Total Time',
                            '${widget.totalTime}s', Colors.blue),
                        _summaryBadge(Icons.question_answer, 'Questions',
                            '${widget.questions.length}', Colors.deepPurple),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text('AI Analysis',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(aiAnalysis ?? '',
                          style: theme.textTheme.bodyLarge),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => QuizReviewScreen(
                            questions: widget.questions,
                            selectedAnswers: widget.selectedAnswers,
                            quizName: widget.quizName,
                            topic: widget.topic,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.rate_review),
                    label: const Text('Review Quiz'),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () async {
                      final shareText = _buildProfessionalShareText();
                      final bytes =
                          await rootBundle.load('assets/share_congrats.png');
                      final tempDir = await Directory.systemTemp.createTemp();
                      final file =
                          await File('${tempDir.path}/share_congrats.png')
                              .writeAsBytes(bytes.buffer.asUint8List());
                      await SharePlus.instance.share(
                        ShareParams(
                          text: shareText,
                          files: [XFile(file.path)],
                          subject: 'Celebrate my Neurobits Achievement!',
                        ),
                      );
                    },
                    icon: const Icon(Icons.share),
                    label: const Text('Share Results'),
                  ),
                ],
              ),
            ),
    );
  }

  String _buildProfessionalShareText() {
    return '''🎉 I just completed a Neurobits quiz on "${widget.topic}"!\n\n'''
        'Results:\n'
        '• Score: ${(widget.accuracy * 100).toStringAsFixed(1)}%\n'
        '• Time: ${widget.totalTime}s\n'
        '\nNeurobits is an adaptive learning platform for brain training and knowledge mastery.\n'
        'Think you can do better? Try the app and challenge yourself!';
  }

  Widget _summaryBadge(IconData icon, String label, String value, Color color) {
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
            Text(value,
                style: TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 16, color: color)),
            Text(label, style: const TextStyle(color: Colors.black54)),
          ],
        ),
      ),
    );
  }
}
