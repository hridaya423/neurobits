import 'package:flutter/material.dart';
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
  late final _questionWidget = Text(
    widget.question,
    style: Theme.of(context).textTheme.titleLarge,
    key: const ValueKey('question'),
  );
  late final _textField = TextField(
    controller: _controller,
    keyboardType: TextInputType.number,
    decoration: const InputDecoration(
      border: OutlineInputBorder(),
      hintText: 'Enter your answer...',
    ),
  );
  void _submitAnswer() {
    widget.onSubmitted(_controller.text.trim());
  }
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          _questionWidget,
          const SizedBox(height: 20),
          _textField,
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