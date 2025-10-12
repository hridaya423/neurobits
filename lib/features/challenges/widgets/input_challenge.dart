import 'package:flutter/material.dart';
import 'package:neurobits/core/widgets/latex_text.dart';
import 'package:neurobits/core/widgets/math_input_field.dart';

class InputChallenge extends StatefulWidget {
  final String question;
  final String solution;
  final Function(String) onSubmitted;
  final String? title;
  const InputChallenge({
    super.key,
    required this.question,
    required this.solution,
    required this.onSubmitted,
    this.title,
  });
  @override
  State<InputChallenge> createState() => _InputChallengeState();
}

class _InputChallengeState extends State<InputChallenge> {
  late TextEditingController _controller;
  bool _submitted = false;
  String? _userAnswer;
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
      _userAnswer = answer;
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
            const SizedBox(height: 16),
            _isMathQuestion()
                ? MathInputField(
                    controller: _controller,
                    labelText: 'Your Answer',
                    hintText: 'Enter your mathematical answer...',
                    enabled: !_submitted,
                    onSubmitted: _submit,
                  )
                : TextField(
                    controller: _controller,
                    enabled: !_submitted,
                    decoration: const InputDecoration(
                      labelText: 'Your Answer',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _submit(),
                  ),
            const SizedBox(height: 16),
            if (!_submitted)
              ElevatedButton(
                onPressed: _submit,
                child: const Text('Submit'),
              ),
          ],
        ),
      ),
    );
  }
}
