import 'package:flutter/material.dart';
class FillInBlankChallenge extends StatefulWidget {
  final String question;
  final String answer;
  final void Function(String) onSubmitted;
  const FillInBlankChallenge({
    required this.question,
    required this.answer,
    required this.onSubmitted,
    super.key,
  });
  @override
  State<FillInBlankChallenge> createState() => _FillInBlankChallengeState();
}
class _FillInBlankChallengeState extends State<FillInBlankChallenge> {
  final _controller = TextEditingController();
  bool _submitted = false;
  bool _isCorrect = false;
  void _submit() {
    String userInput = _controller.text.trim();
    bool correct = userInput.toLowerCase() == widget.answer.toLowerCase();
    setState(() {
      _submitted = true;
      _isCorrect = correct;
    });
    widget.onSubmitted(userInput);
  }
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            widget.question,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _controller,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'Fill in the blank...',
            ),
            enabled: !_submitted,
          ),
          const SizedBox(height: 20),
          if (!_submitted)
            ElevatedButton(
              onPressed: _submit,
              child: const Text('Submit'),
            ),
          if (_submitted)
            Text(
              _isCorrect
                  ? 'Correct!'
                  : 'Incorrect. The answer was: ${widget.answer}',
              style: TextStyle(
                color: _isCorrect ? Colors.green : Colors.red,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
        ],
      ),
    );
  }
}