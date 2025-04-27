import 'package:flutter/material.dart';

class InputChallenge extends StatefulWidget {
  final String question;
  final String solution;
  final Function(String) onSubmitted;
  final String? title;
  const InputChallenge({
    Key? key,
    required this.question,
    required this.solution,
    required this.onSubmitted,
    this.title,
  }) : super(key: key);
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
              Text(widget.title!,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(widget.question, style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              enabled: !_submitted,
              decoration: InputDecoration(
                labelText: 'Your Answer',
                border: const OutlineInputBorder(),
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
