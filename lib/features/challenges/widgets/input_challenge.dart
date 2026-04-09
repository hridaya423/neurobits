import 'package:flutter/material.dart';
import 'package:neurobits/core/widgets/latex_text.dart';
import 'package:neurobits/core/widgets/math_input_field.dart';
import 'package:neurobits/features/challenges/widgets/question_hint_accordion.dart';
import 'package:neurobits/features/challenges/widgets/question_visual_block.dart';

class InputChallenge extends StatefulWidget {
  final String question;
  final String solution;
  final Function(String) onSubmitted;
  final String? title;
  final bool isDisabled;
  final String? hint;
  final String? imageUrl;
  final Map<String, dynamic>? chartSpec;
  final List<Map<String, dynamic>>? progressiveHints;
  final bool enableProgressiveHints;
  final bool enableAssistedExplain;
  const InputChallenge({
    super.key,
    required this.question,
    required this.solution,
    required this.onSubmitted,
    this.title,
    this.isDisabled = false,
    this.hint,
    this.imageUrl,
    this.chartSpec,
    this.progressiveHints,
    this.enableProgressiveHints = false,
    this.enableAssistedExplain = false,
  });

  @override
  State<InputChallenge> createState() => _InputChallengeState();
}

class _InputChallengeState extends State<InputChallenge> {
  late TextEditingController _controller;
  late TextEditingController _pointController;
  late TextEditingController _whichMeansController;
  late TextEditingController _explainController;
  bool _submitted = false;
  int _hintStage = 0;
  bool _assistedModeEnabled = false;
  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _pointController = TextEditingController();
    _whichMeansController = TextEditingController();
    _explainController = TextEditingController();
    _assistedModeEnabled = widget.enableAssistedExplain;
  }

  @override
  void dispose() {
    _controller.dispose();
    _pointController.dispose();
    _whichMeansController.dispose();
    _explainController.dispose();
    super.dispose();
  }

  String _currentDraftAnswer() {
    if (!_assistedModeEnabled) {
      return _controller.text.trim();
    }
    return _composeAssistedAnswer();
  }

  String _normalizeSentencePart(String value) {
    final compact = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (compact.isEmpty) return '';
    if (RegExp(r'[.!?]$').hasMatch(compact)) return compact;
    return '$compact.';
  }

  String _composeAssistedAnswer() {
    final point = _pointController.text.trim();
    final whichMeans = _whichMeansController.text.trim();
    final explain = _explainController.text.trim();
    final parts = <String>[];
    if (point.isNotEmpty) parts.add(_normalizeSentencePart(point));
    if (whichMeans.isNotEmpty) parts.add(_normalizeSentencePart(whichMeans));
    if (explain.isNotEmpty) parts.add(_normalizeSentencePart(explain));
    return parts.join(' ').trim();
  }

  void _submit() {
    final answer = _currentDraftAnswer();
    setState(() {
      _submitted = true;
    });
    widget.onSubmitted(answer);
  }

  String _normalize(String value) {
    return value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9 ]+'), ' ').trim();
  }

  List<String> _criterionKeywords(Map<String, dynamic> criterion) {
    final explicit = criterion['keywords'];
    if (explicit is List) {
      final values = explicit
          .map((item) => item?.toString().trim().toLowerCase())
          .whereType<String>()
          .where((value) => value.isNotEmpty)
          .toList();
      if (values.isNotEmpty) return values;
    }

    final fallbackText =
        '${criterion['label']?.toString() ?? ''} ${criterion['description']?.toString() ?? ''}';
    return _normalize(fallbackText)
        .split(RegExp(r'\s+'))
        .where((token) => token.length >= 4)
        .take(8)
        .toList();
  }

  bool _criterionCovered(Map<String, dynamic> criterion, String answerLower) {
    final keywords = _criterionKeywords(criterion);
    if (keywords.isEmpty) return false;
    return keywords.any((keyword) => answerLower.contains(keyword));
  }

  List<Map<String, dynamic>> _criteriaCoverage() {
    final criteria = widget.progressiveHints ?? const <Map<String, dynamic>>[];
    final answerLower = _normalize(_currentDraftAnswer());
    return criteria.map((criterion) {
      final covered = _criterionCovered(criterion, answerLower);
      return {
        ...criterion,
        'covered': covered,
      };
    }).toList();
  }

  bool get _showAssistedModeToggle {
    return widget.enableAssistedExplain;
  }

  String _progressiveHintText(List<Map<String, dynamic>> coverage) {
    final firstMissing = coverage.firstWhere(
      (criterion) => criterion['covered'] != true,
      orElse: () => const <String, dynamic>{},
    );
    if (firstMissing.isEmpty) {
      return 'Great answer so far. You have covered the key points.';
    }

    final hint = firstMissing['hint']?.toString().trim() ?? '';
    if (hint.isNotEmpty) return hint;

    final label = firstMissing['label']?.toString().trim() ?? '';
    if (label.isNotEmpty) {
      return 'Include a clear point about: $label';
    }

    final description = firstMissing['description']?.toString().trim() ?? '';
    if (description.isNotEmpty) {
      return description;
    }

    return 'Add one more key mark-point from the question requirements.';
  }

  bool _isMathQuestion() {
    final question = widget.question.toLowerCase();
    final solution = widget.solution.toLowerCase();

    if (widget.question.contains(r'\(') ||
        widget.question.contains(r'\[') ||
        widget.question.contains(r'$$') ||
        widget.solution.contains(r'\(') ||
        widget.solution.contains(r'\[')) {
      return true;
    }

    final mathKeywords = [
      'solve',
      'calculate',
      'find',
      'equation',
      'formula',
      'derivative',
      'integral',
      'limit',
      'sum',
      'product',
      'fraction',
      'square root',
      'power',
      'exponent',
      'algebra',
      'calculus',
      'geometry',
      'trigonometry',
      'logarithm',
      'sine',
      'cosine',
      'tangent',
      'matrix',
      'vector',
      'polynomial',
      'factor'
    ];

    for (final keyword in mathKeywords) {
      if (question.contains(keyword) || solution.contains(keyword)) {
        return true;
      }
    }

    final mathSymbols = [
      '+',
      '-',
      '×',
      '÷',
      '=',
      '^',
      '√',
      'π',
      'θ',
      'α',
      'β',
      '∑',
      '∫'
    ];
    for (final symbol in mathSymbols) {
      if (widget.question.contains(symbol) ||
          widget.solution.contains(symbol)) {
        return true;
      }
    }

    return false;
  }

  @override
  Widget build(BuildContext context) {
    final coverage = _criteriaCoverage();
    final coveredCount =
        coverage.where((item) => item['covered'] == true).length;
    final showProgressiveHints =
        widget.enableProgressiveHints && coverage.isNotEmpty && !_submitted;

    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.title != null && widget.title!.isNotEmpty)
              LaTeXText(widget.title!,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            LaTeXText(widget.question,
                style: Theme.of(context).textTheme.bodyLarge),
            if ((widget.imageUrl != null &&
                    widget.imageUrl!.trim().isNotEmpty) ||
                (widget.chartSpec != null && widget.chartSpec!.isNotEmpty)) ...[
              const SizedBox(height: 12),
              QuestionVisualBlock(
                imageUrl: widget.imageUrl,
                chartSpec: widget.chartSpec,
              ),
            ],
            if (widget.hint != null && widget.hint!.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              QuestionHintAccordion(hint: widget.hint!.trim()),
            ],
            if (showProgressiveHints) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: Theme.of(context)
                      .colorScheme
                      .surfaceContainerHighest
                      .withValues(alpha: 0.22),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Exam hints',
                      style: Theme.of(context)
                          .textTheme
                          .labelLarge
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$coveredCount/${coverage.length} mark points covered',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    if (_hintStage == 0)
                      OutlinedButton.icon(
                        onPressed: () {
                          setState(() {
                            _hintStage = 1;
                          });
                        },
                        icon: const Icon(Icons.lightbulb_outline),
                        label: const Text('Show a hint'),
                      ),
                    if (_hintStage >= 1) ...[
                      Text(
                        _progressiveHintText(coverage),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 6),
                      if (_hintStage == 1)
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _hintStage = 2;
                            });
                          },
                          child: const Text('I still do not get it'),
                        ),
                    ],
                    if (_hintStage >= 2) ...[
                      const SizedBox(height: 4),
                      ...coverage.map((criterion) {
                        final covered = criterion['covered'] == true;
                        final label =
                            criterion['label']?.toString().trim() ?? '';
                        final description =
                            criterion['description']?.toString().trim() ?? '';
                        final text = label.isNotEmpty
                            ? label
                            : (description.isNotEmpty
                                ? description
                                : 'Include a key point');
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                covered
                                    ? Icons.check_circle_outline
                                    : Icons.radio_button_unchecked,
                                size: 18,
                                color: covered
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  text,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            if (_showAssistedModeToggle) ...[
              Row(
                children: [
                  const Expanded(
                    child: Text('Assisted exam answer mode'),
                  ),
                  Switch(
                    value: _assistedModeEnabled,
                    onChanged: (_submitted || widget.isDisabled)
                        ? null
                        : (value) {
                            setState(() {
                              _assistedModeEnabled = value;
                            });
                          },
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            if (_assistedModeEnabled)
              Column(
                children: [
                  TextField(
                    controller: _pointController,
                    enabled: !_submitted && !widget.isDisabled,
                    decoration: const InputDecoration(
                      labelText: 'Point',
                      hintText: 'State your key point clearly.',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _whichMeansController,
                    enabled: !_submitted && !widget.isDisabled,
                    decoration: const InputDecoration(
                      labelText: 'Which means',
                      hintText: 'Explain what that point means.',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _explainController,
                    enabled: !_submitted && !widget.isDisabled,
                    decoration: const InputDecoration(
                      labelText: 'Explain',
                      hintText: 'Link it back to the question for full marks.',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                    minLines: 2,
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) => _submit(),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest
                          .withValues(alpha: 0.2),
                      border: Border.all(
                        color: Theme.of(context)
                            .colorScheme
                            .outline
                            .withValues(alpha: 0.2),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Final answer sent for marking',
                          style: Theme.of(context)
                              .textTheme
                              .labelLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _composeAssistedAnswer().isEmpty
                              ? 'Your three parts will be combined into one final response.'
                              : _composeAssistedAnswer(),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              )
            else
              (_isMathQuestion()
                  ? MathInputField(
                      controller: _controller,
                      labelText: 'Your Answer',
                      hintText: 'Enter your mathematical answer...',
                      enabled: !_submitted && !widget.isDisabled,
                      onChanged: (_) => setState(() {}),
                      onSubmitted: _submit,
                    )
                  : TextField(
                      controller: _controller,
                      enabled: !_submitted && !widget.isDisabled,
                      decoration: const InputDecoration(
                        labelText: 'Your Answer',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) => setState(() {}),
                      onSubmitted: (_) => _submit(),
                    )),
            const SizedBox(height: 16),
            if (!_submitted)
              ElevatedButton(
                onPressed: widget.isDisabled ? null : _submit,
                child: const Text('Submit'),
              ),
          ],
        ),
      ),
    );
  }
}
