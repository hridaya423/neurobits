import 'package:flutter/material.dart';
import 'package:neurobits/core/widgets/latex_text.dart';
import 'package:neurobits/core/widgets/math_input_field.dart';

class BrainChallenge extends StatefulWidget {
  final String question;
  final String solution;
  final Function(String) onSubmitted;
  const BrainChallenge({
    required this.question,
    required this.solution,
    required this.onSubmitted,
    super.key,
  });
  @override
  State<BrainChallenge> createState() => _BrainChallengeState();
}

class _BrainChallengeState extends State<BrainChallenge> {
  final _controller = TextEditingController();
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  late final _questionWidget = LaTeXText(
    widget.question,
    style: Theme.of(context).textTheme.titleLarge,
    key: const ValueKey('question'),
  );
  Widget _buildInputField() {
    if (_isMathQuestion()) {
      return MathInputField(
        controller: _controller,
        hintText: 'Enter your mathematical answer...',
        onSubmitted: _submitAnswer,
      );
    }
    return TextField(
      controller: _controller,
      keyboardType: TextInputType.number,
      decoration: const InputDecoration(
        border: OutlineInputBorder(),
        hintText: 'Enter your answer...',
      ),
    );
  }

  void _submitAnswer() {
    widget.onSubmitted(_controller.text.trim());
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

    final mathSymbols = ['+', '-', '×', '÷', '=', '^', '√', 'π', '∑', '∫'];
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
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          _questionWidget,
          const SizedBox(height: 20),
          _buildInputField(),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _submitAnswer,
            child: const Text('Submit Answer'),
          ),
        ],
      ),
    );
  }
}
