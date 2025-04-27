import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/supabase.dart';
import '../../../services/groq_service.dart';
class ChallengeQuizScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> challenge;
  final Map<String, dynamic> quizData;
  final String userId;
  const ChallengeQuizScreen(
      {Key? key,
      required this.challenge,
      required this.quizData,
      required this.userId})
      : super(key: key);
  @override
  ConsumerState<ChallengeQuizScreen> createState() =>
      _ChallengeQuizScreenState();
}
class _ChallengeQuizScreenState extends ConsumerState<ChallengeQuizScreen> {
  late Future<List<Map<String, dynamic>>> _questionsFuture;
  int _currentIndex = 0;
  List<Map<String, dynamic>> _answers = [];
  int _score = 0;
  bool _submitted = false;
  List<Map<String, dynamic>> _questions = [];
  bool _loading = true;
  String? _resultText;
  List<Map<String, dynamic>>? _allProgress;
  String? _analysis;
  bool _analyzing = false;
  @override
  void initState() {
    super.initState();
    final difficulty = widget.quizData['difficulty'] ?? 'Medium';
    final numQuestions = widget.quizData['numQuestions'] ?? 5;
    _questionsFuture = _fetchQuestions(difficulty, numQuestions);
  }
  Future<List<Map<String, dynamic>>> _fetchQuestions(
      String difficulty, int count) async {
    final topic = widget.quizData['topic'] ?? 'General Knowledge';
    final questions =
        await GroqService.generateQuestions(topic, difficulty, count: count);
    return questions;
  }
  void _submitQuiz() async {
    setState(() {
      _loading = true;
    });
    await SupabaseService.submitFriendChallengeProgress(
      challengeId: widget.challenge['id'],
      userId: widget.userId,
      answers: _answers,
      score: _score,
    );
    final progress =
        await SupabaseService.getChallengeProgress(widget.challenge['id']);
    setState(() {
      _submitted = true;
      _loading = false;
      _allProgress = progress;
      _resultText = _getResultText(progress);
    });
    if (progress.length >= 2 && _analysis == null) {
      _runAnalysis(progress);
    }
  }
  Future<void> _runAnalysis(List<Map<String, dynamic>> progress) async {
    setState(() {
      _analyzing = true;
    });
    final myProgress =
        progress.firstWhere((p) => p['user_id'] == widget.userId);
    final myAnswers = myProgress['answers'] as List<dynamic>? ?? [];
    final score = myProgress['score'] as int? ?? 0;
    final accuracy = _questions.isEmpty ? 0.0 : score / _questions.length;
    final buffer = StringBuffer();
    buffer.writeln('Quiz Topic: ${widget.quizData['topic']}');
    buffer.writeln('Accuracy: ${(accuracy * 100).toStringAsFixed(1)}%');
    for (int i = 0; i < _questions.length; i++) {
      final q = _questions[i];
      buffer.writeln('Q${i + 1}: ${q['question'] ?? ''}');
      buffer.writeln(
          'Your Answer: ${myAnswers.length > i ? myAnswers[i]['selected'] ?? '' : ''}');
      buffer.writeln('Correct Answer: ${q['answer'] ?? ''}');
      buffer.writeln('---');
    }
    buffer.writeln(
        "Please provide a concise analysis of my strengths and weaknesses in this quiz, and suggest what topics or question types I should focus on to improve.");
    try {
      final String analysisResult =
          await GroqService.analyzeQuizPerformance(buffer.toString());
      setState(() {
        _analysis = analysisResult;
        _analyzing = false;
      });
      await SupabaseService.saveSessionAnalysis(
        userId: widget.userId,
        topic: widget.quizData['topic'] ?? '',
        quizName: widget.quizData['topic'] ?? '',
        analysis: _analysis!,
        accuracy: accuracy,
        totalTime: 0,
      );
    } catch (e) {
      setState(() {
        _analysis = 'Could not analyze performance.';
        _analyzing = false;
      });
    }
  }
  String _getResultText(List<Map<String, dynamic>> progress) {
    if (progress.length < 2) return 'Waiting for your friend to finish...';
    progress.sort((a, b) => (b['score'] as int).compareTo(a['score'] as int));
    final winner = progress[0];
    final isDraw = progress[0]['score'] == progress[1]['score'];
    if (isDraw) return 'It\'s a draw! Both scored ${progress[0]['score']}.';
    if (winner['user_id'] == widget.userId) {
      return 'You win! (${winner['score']} vs ${progress[1]['score']})';
    } else {
      return 'You lose! (${progress[1]['score']} vs ${winner['score']})';
    }
  }
  Widget _buildDetailedResults() {
    if (_allProgress == null || _allProgress!.isEmpty) return const SizedBox();
    final myProgress =
        _allProgress!.firstWhere((p) => p['user_id'] == widget.userId);
    Map<String, dynamic>? otherProgress;
    try {
      otherProgress =
          _allProgress!.firstWhere((p) => p['user_id'] != widget.userId);
    } catch (_) {
      otherProgress = null;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text('Your Answers:',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        ...List.generate(_questions.length, (i) {
          final q = _questions[i];
          final myAns = myProgress['answers']?[i]?['selected'] ?? '-';
          final correct = q['answer'];
          final isCorrect = myAns == correct;
          return ListTile(
            title: Text(q['question'] ?? ''),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Your answer: $myAns',
                    style: TextStyle(
                        color: isCorrect ? Colors.green : Colors.red)),
                if (!isCorrect)
                  Text('Correct answer: $correct',
                      style: const TextStyle(color: Colors.green)),
              ],
            ),
          );
        }),
        if (otherProgress != null) ...[
          const Divider(),
          Text('Friend\'s Answers:',
              style: const TextStyle(fontWeight: FontWeight.bold)),
          ...List.generate(_questions.length, (i) {
            final q = _questions[i];
            final theirAns = otherProgress!['answers']?[i]?['selected'] ?? '-';
            final correct = q['answer'];
            final isCorrect = theirAns == correct;
            return ListTile(
              title: Text(q['question'] ?? ''),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Their answer: $theirAns',
                      style: TextStyle(
                          color: isCorrect ? Colors.green : Colors.red)),
                  if (!isCorrect)
                    Text('Correct answer: $correct',
                        style: const TextStyle(color: Colors.green)),
                ],
              ),
            );
          }),
        ],
        if (_analysis != null) ...[
          const Divider(),
          Text('Your Personalized Analysis:',
              style: const TextStyle(fontWeight: FontWeight.bold)),
          _analyzing
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.0),
                  child: LinearProgressIndicator(),
                )
              : Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Text(_analysis!, style: const TextStyle(fontSize: 16)),
                ),
        ],
      ],
    );
  }
  @override
  Widget build(BuildContext context) {
    if (_submitted) {
      if (_loading) return const Center(child: CircularProgressIndicator());
      return Scaffold(
        appBar: AppBar(title: const Text('Results')),
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_resultText ?? '',
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.bold)),
                _buildDetailedResults(),
                const SizedBox(height: 24),
                Center(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Back'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _questionsFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        _questions = snapshot.data!;
        final q = _questions[_currentIndex];
        return Scaffold(
          appBar: AppBar(title: const Text('Challenge Quiz')),
          body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Question ${_currentIndex + 1} of ${_questions.length}',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Text(q['question'], style: const TextStyle(fontSize: 18)),
                const SizedBox(height: 18),
                ...List.generate(q['options'].length, (i) {
                  final opt = q['options'][i];
                  return RadioListTile<String>(
                    value: opt,
                    groupValue: _answers.length > _currentIndex
                        ? _answers[_currentIndex]['selected']
                        : null,
                    title: Text(opt),
                    onChanged: (val) {
                      if (_answers.length > _currentIndex) {
                        _answers[_currentIndex]['selected'] = val;
                      } else {
                        _answers.add({'selected': val});
                      }
                      setState(() {});
                    },
                  );
                }),
                const Spacer(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (_currentIndex > 0)
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _currentIndex--;
                          });
                        },
                        child: const Text('Back'),
                      ),
                    if (_currentIndex < _questions.length - 1)
                      ElevatedButton(
                        onPressed: _answers.length > _currentIndex &&
                                _answers[_currentIndex]['selected'] != null
                            ? () {
                                setState(() {
                                  _currentIndex++;
                                });
                              }
                            : null,
                        child: const Text('Next'),
                      ),
                    if (_currentIndex == _questions.length - 1)
                      ElevatedButton(
                        onPressed: _answers.length > _currentIndex &&
                                _answers[_currentIndex]['selected'] != null
                            ? () {
                                _score = 0;
                                for (var i = 0; i < _questions.length; i++) {
                                  if (_answers[i]['selected'] ==
                                      _questions[i]['answer']) _score++;
                                }
                                _submitQuiz();
                              }
                            : null,
                        child: const Text('Submit'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}