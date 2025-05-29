import 'package:flutter/material.dart';
class QuizSettingsDialog extends StatefulWidget {
  final String topic;
  const QuizSettingsDialog({super.key, required this.topic});
  @override
  _QuizSettingsDialogState createState() => _QuizSettingsDialogState();
}
class _QuizSettingsDialogState extends State<QuizSettingsDialog> {
  int _numQuestions = 5;
  String _difficulty = 'Medium';
  final List<int> _questionOptions = [5, 10, 15];
  final List<String> _difficultyOptions = ['Easy', 'Medium', 'Hard'];
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Quiz Settings for ${widget.topic}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<int>(
            value: _numQuestions,
            decoration: const InputDecoration(labelText: 'Number of Questions'),
            items: _questionOptions
                .map((val) => DropdownMenuItem(value: val, child: Text('$val')))
                .toList(),
            onChanged: (v) {
              if (v != null) setState(() => _numQuestions = v);
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _difficulty,
            decoration: const InputDecoration(labelText: 'Difficulty'),
            items: _difficultyOptions
                .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                .toList(),
            onChanged: (v) {
              if (v != null) setState(() => _difficulty = v);
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop({
            'topic': widget.topic,
            'numQuestions': _numQuestions,
            'difficulty': _difficulty,
          }),
          child: const Text('Start'),
        ),
      ],
    );
  }
}