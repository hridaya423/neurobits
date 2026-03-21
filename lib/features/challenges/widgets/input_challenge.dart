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
  });

  @override
  State<InputChallenge> createState() => _InputChallengeState();
}

class _InputChallengeState extends State<InputChallenge> {
  late TextEditingController _controller;
  bool _submitted = false;
  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final answer = _controller.text.trim();
    setState(() {
      _submitted = true;
    });
    widget.onSubmitted(answer);
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
            const SizedBox(height: 16),
            _isMathQuestion()
                ? MathInputField(
                    controller: _controller,
                    labelText: 'Your Answer',
                    hintText: 'Enter your mathematical answer...',
                    enabled: !_submitted && !widget.isDisabled,
                    onSubmitted: _submit,
                  )
                : TextField(
                    controller: _controller,
                    enabled: !_submitted && !widget.isDisabled,
                    decoration: const InputDecoration(
                      labelText: 'Your Answer',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _submit(),
                  ),
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
