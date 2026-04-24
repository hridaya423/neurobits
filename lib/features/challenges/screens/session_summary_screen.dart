import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neurobits/core/providers.dart';
import 'package:neurobits/services/ai_service.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:neurobits/features/challenges/screens/quiz_screen.dart';
import 'quiz_review_screen.dart';
import 'package:go_router/go_router.dart';

class SessionSummaryScreen extends ConsumerStatefulWidget {
  final List<Map<String, dynamic>> questions;
  final List<dynamic> selectedAnswers;
  final int totalTime;
  final double accuracy;
  final double marksAwarded;
  final double marksAvailable;
  final bool examMode;
  final String topic;
  final String? quizName;
  const SessionSummaryScreen({
    required this.questions,
    required this.selectedAnswers,
    required this.totalTime,
    required this.accuracy,
    this.marksAwarded = 0,
    this.marksAvailable = 0,
    this.examMode = false,
    required this.topic,
    this.quizName,
    super.key,
  });
  @override
  ConsumerState<SessionSummaryScreen> createState() =>
      _SessionSummaryScreenState();
}

class _SessionSummaryScreenState extends ConsumerState<SessionSummaryScreen> {
  bool _loading = true;
  String? aiAnalysis;
  List<String> _wins = [];
  List<String> _focusNext = [];
  String? _summaryLine;
  void _setStateSafe(VoidCallback fn) {
    if (!mounted) return;
    setState(fn);
  }

  @override
  void initState() {
    super.initState();
    _analyzePerformance();
  }

  Future<void> _analyzePerformance() async {
    final summary = _buildAISummary();
    _setStateSafe(() {
      _loading = true;
      aiAnalysis = null;
      _wins = [];
      _focusNext = [];
      _summaryLine = null;
    });
    try {
      if (widget.questions.isEmpty) {
        _setStateSafe(() {
          aiAnalysis = 'No questions found for this session.';
          _loading = false;
        });
        return;
      }

      final String analysis = await AIService.analyzeQuizPerformance(summary)
          .timeout(const Duration(seconds: 15));
      if (!mounted) return;

      try {
        final sessionRepo = ref.read(sessionAnalysisRepositoryProvider);
        await sessionRepo.save(
          topic: widget.topic,
          quizName: widget.quizName ?? widget.topic,
          analysis: analysis,
          accuracy: widget.accuracy,
          totalTime: widget.totalTime.toDouble(),
        );
      } catch (e) {
        debugPrint('Error saving session analysis: $e');
      }
      if (!mounted) return;

      if (analysis.trim().isNotEmpty) {
        final parsed = _parseAnalysis(analysis);
        final summaryList = parsed['summary'];
        _setStateSafe(() {
          aiAnalysis = analysis;
          _wins = parsed['wins'] ?? [];
          _focusNext = parsed['focus'] ?? [];
          _summaryLine = (summaryList != null && summaryList.isNotEmpty)
              ? summaryList.first
              : null;
          _loading = false;
        });
      } else {
        _setStateSafe(() {
          aiAnalysis = 'Could not analyze performance. (No analysis returned)';
          _loading = false;
        });
      }
    } catch (e) {
      _setStateSafe(() {
        aiAnalysis = 'Could not analyze performance. (${e.toString()})';
        _loading = false;
      });
    } finally {
      _setStateSafe(() {
        _loading = false;
      });
    }
  }

  List<int> _incorrectIndices() {
    final indices = <int>[];
    for (int i = 0; i < widget.questions.length; i++) {
      final q = widget.questions[i];
      final userAns = widget.selectedAnswers[i];
      if (!QuizReview.isAnswerCorrect(q, userAns)) {
        indices.add(i);
      }
    }
    return indices;
  }

  String _buildAISummary() {
    final buffer = StringBuffer();
    buffer.writeln('Quiz Topic: ${widget.topic}');
    buffer.writeln('Accuracy: ${(widget.accuracy * 100).toStringAsFixed(1)}%');
    if (widget.marksAvailable > 0) {
      buffer.writeln(
          'Marks: ${widget.marksAwarded.toStringAsFixed(1)}/${widget.marksAvailable.toStringAsFixed(1)}');
    }
    buffer.writeln('Total Time: ${widget.totalTime}s');
    for (int i = 0; i < widget.questions.length; i++) {
      final q = widget.questions[i];
      final markScheme = q['markScheme'] ?? q['mark_scheme'];
      final totalMarks = markScheme is Map
          ? (markScheme['total_marks'] ?? markScheme['totalMarks'])
          : null;
      buffer.writeln('Q${i + 1}: ${q['question'] ?? ''}');
      buffer.writeln('User Answer: ${widget.selectedAnswers[i] ?? ''}');
      buffer.writeln(
          'Correct Answer: ${q['solution'] ?? q['answer'] ?? q['options']?[q['solution']] ?? ''}');
      if (totalMarks is num) {
        buffer.writeln('Marks available: ${totalMarks.toStringAsFixed(1)}');
      }
      buffer.writeln('---');
    }
    buffer.writeln(
        'Please provide a concise analysis of the user\'s strengths and weaknesses in this quiz, and suggest what topics or question types they should focus on to improve.');
    return buffer.toString();
  }

  Map<String, List<String>> _parseAnalysis(String text) {
    final wins = <String>[];
    final focus = <String>[];
    String? summary;
    String section = '';
    final lines = text.split('\n');
    for (final raw in lines) {
      final line = raw.trim();
      if (line.isEmpty) continue;
      final lower = line.toLowerCase();
      if (lower.startsWith('wins')) {
        section = 'wins';
        continue;
      }
      if (lower.startsWith('focus')) {
        section = 'focus';
        continue;
      }
      if (lower.startsWith('summary')) {
        summary = line.split(':').skip(1).join(':').trim();
        continue;
      }
      if (line.startsWith('-') || line.startsWith('•')) {
        final item = line.replaceFirst(RegExp(r'^[-•]\s*'), '').trim();
        if (item.isEmpty) continue;
        if (section == 'wins') {
          wins.add(item);
        } else if (section == 'focus') {
          focus.add(item);
        }
      }
    }
    return {
      'wins': wins,
      'focus': focus,
      if (summary != null && summary.isNotEmpty) 'summary': [summary],
    };
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
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final tiles = <Widget>[
                        _summaryTile(
                          context,
                          Icons.check_circle,
                          'Accuracy',
                          '${(widget.accuracy * 100).toStringAsFixed(1)}%',
                          Colors.green,
                        ),
                        _summaryTile(
                          context,
                          Icons.timer,
                          'Total time',
                          '${widget.totalTime}s',
                          Colors.blue,
                        ),
                        if (widget.marksAvailable > 0)
                          _summaryTile(
                            context,
                            Icons.grading,
                            'Marks',
                            '${widget.marksAwarded.toStringAsFixed(1)}/${widget.marksAvailable.toStringAsFixed(1)}',
                            Colors.orange,
                          ),
                        _summaryTile(
                          context,
                          Icons.question_answer,
                          'Questions',
                          '${widget.questions.length}',
                          Colors.deepPurple,
                        ),
                      ];
                      final hasMarksTile = widget.marksAvailable > 0;
                      final isCompact = constraints.maxWidth < 560;
                      final crossAxisCount =
                          hasMarksTile ? (isCompact ? 2 : 4) : 3;
                      final childAspectRatio =
                          hasMarksTile ? 1.9 : (isCompact ? 1.35 : 1.6);
                      return GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: childAspectRatio,
                        ),
                        itemCount: tiles.length,
                        itemBuilder: (_, index) => tiles[index],
                      );
                    },
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
                      child: _wins.isNotEmpty || _focusNext.isNotEmpty
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _analysisSection(
                                    context, 'What you did well', _wins),
                                const SizedBox(height: 12),
                                _analysisSection(
                                    context, 'Focus next', _focusNext),
                                if (_summaryLine != null &&
                                    _summaryLine!.isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  Text(
                                    _summaryLine!,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ],
                            )
                          : Text(aiAnalysis ?? '',
                              style: theme.textTheme.bodyLarge),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () {
                      final encoded = Uri.encodeComponent(widget.topic);
                      context.push('/topic/$encoded');
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Practice this topic'),
                  ),
                  if (_incorrectIndices().isNotEmpty) ...[
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: () {
                        final indices = _incorrectIndices();
                        final weakQuestions =
                            indices.map((i) => widget.questions[i]).toList();
                        final weakAnswers = indices
                            .map((i) => widget.selectedAnswers[i])
                            .toList();
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => QuizReviewScreen(
                              questions: weakQuestions,
                              selectedAnswers: weakAnswers,
                              quizName: widget.quizName,
                              topic: widget.topic,
                              examMode: widget.examMode,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.school_outlined),
                      label: const Text('Review weak questions'),
                    ),
                  ],
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => QuizReviewScreen(
                            questions: widget.questions,
                            selectedAnswers: widget.selectedAnswers,
                            quizName: widget.quizName,
                            topic: widget.topic,
                            examMode: widget.examMode,
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
                      if (!context.mounted) return;
                      final box = context.findRenderObject() as RenderBox?;
                      final origin = box != null
                          ? box.localToGlobal(Offset.zero) & box.size
                          : null;
                      await SharePlus.instance.share(
                        ShareParams(
                          text: shareText,
                          files: [XFile(file.path)],
                          subject: 'Celebrate my Neurobits Achievement!',
                          sharePositionOrigin: origin,
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
        '${widget.marksAvailable > 0 ? '• Marks: ${widget.marksAwarded.toStringAsFixed(1)}/${widget.marksAvailable.toStringAsFixed(1)}\n' : ''}'
        '• Time: ${widget.totalTime}s\n'
        '\nNeurobits is an adaptive learning platform for brain training and knowledge mastery.\n'
        'Think you can do better? Try the app and challenge yourself!';
  }

  Widget _summaryTile(BuildContext context, IconData icon, String label,
      String value, Color accent) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: accent, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(value,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSurface,
                  )),
        ],
      ),
    );
  }

  Widget _analysisSection(
      BuildContext context, String title, List<String> items) {
    if (items.isEmpty) return const SizedBox.shrink();
    final colorScheme = Theme.of(context).colorScheme;
    final visible = items.take(3).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                )),
        const SizedBox(height: 8),
        Column(
          children: visible
              .map((item) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('• ',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(color: colorScheme.primary)),
                        Expanded(
                          child: Text(
                            item,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  ))
              .toList(),
        ),
      ],
    );
  }
}
