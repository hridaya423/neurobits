import 'package:flutter/material.dart';

class QuizChallenge extends StatefulWidget {
  final String question;
  final List<String> options;
  final Function(String) onSubmitted;
  const QuizChallenge({
    required this.question,
    required this.options,
    required this.onSubmitted,
    super.key,
  });
  @override
  State<QuizChallenge> createState() => _QuizChallengeState();
}

class _QuizChallengeState extends State<QuizChallenge> {
  late final _questionWidget = Text(
    widget.question,
    style: Theme.of(context).textTheme.titleLarge,
    key: const ValueKey('question'),
  );
  late final List<Widget> _optionButtons = widget.options.map((option) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: ElevatedButton(
        onPressed: () => widget.onSubmitted(option),
        child: Text(option),
      ),
    );
  }).toList();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          _questionWidget,
          const SizedBox(height: 20),
          ..._optionButtons,
        ],
      ),
    );
  }
}
