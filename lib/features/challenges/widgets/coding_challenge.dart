import 'package:flutter/material.dart';
import 'package:neurobits/core/widgets/latex_text.dart';
import 'package:neurobits/features/challenges/widgets/question_hint_accordion.dart';
import 'package:neurobits/features/challenges/widgets/question_visual_block.dart';

class CodingChallenge extends StatefulWidget {
  final String question;
  final String solution;
  final String? starterCode;
  final Function(String) onSubmitted;
  final bool isDisabled;
  final String? hint;
  final String? imageUrl;
  final Map<String, dynamic>? chartSpec;
  const CodingChallenge({
    required this.question,
    required this.solution,
    this.starterCode,
    required this.onSubmitted,
    this.isDisabled = false,
    this.hint,
    this.imageUrl,
    this.chartSpec,
    super.key,
  });

  @override
  State<CodingChallenge> createState() => _CodingChallengeState();
}

class _CodingChallengeState extends State<CodingChallenge> {
  late final TextEditingController _controller;
  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.starterCode ?? '');
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
        children: [
          LaTeXText(widget.question,
              style: Theme.of(context).textTheme.titleLarge),
          if ((widget.imageUrl != null && widget.imageUrl!.trim().isNotEmpty) ||
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
          const SizedBox(height: 20),
          TextField(
            controller: _controller,
            maxLines: 5,
            enabled: !widget.isDisabled,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'Write your code here...',
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: widget.isDisabled
                ? null
                : () => widget.onSubmitted(_controller.text.trim()),
            child: const Text('Submit Code'),
          ),
        ],
      ),
    );
  }
}
