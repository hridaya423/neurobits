import 'package:flutter/material.dart';
import 'package:neurobits/core/widgets/latex_text.dart';

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
  String? _selectedAnswer;
  bool _isSubmitted = false;

  void _selectAnswer(String answer) {
    if (_isSubmitted) return;

    setState(() {
      _selectedAnswer = answer;
      _isSubmitted = true;
    });

    widget.onSubmitted(answer);
  }

  @override
  void didUpdateWidget(QuizChallenge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.question != widget.question ||
        oldWidget.options.length != widget.options.length) {
      _selectedAnswer = null;
      _isSubmitted = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LaTeXText(
            widget.question,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),

          ...widget.options.asMap().entries.map((entry) {
            final index = entry.key;
            final option = entry.value;
            final isSelected = _selectedAnswer == option;
            final optionLabel = String.fromCharCode(65 + index);
            return Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: Material(
                elevation: isSelected ? 4 : 1,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: _isSubmitted ? null : () => _selectAnswer(option),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(16.0),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? theme.colorScheme.primary
                            : theme.colorScheme.outline.withOpacity(0.3),
                        width: isSelected ? 2 : 1,
                      ),
                      color: isSelected
                          ? theme.colorScheme.primary.withOpacity(0.1)
                          : theme.colorScheme.surface,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isSelected
                                ? theme.colorScheme.primary
                                : theme.colorScheme.outline.withOpacity(0.2),
                          ),
                          child: Center(
                            child: Text(
                              optionLabel,
                              style: theme.textTheme.titleSmall?.copyWith(
                                color: isSelected
                                    ? theme.colorScheme.onPrimary
                                    : theme.colorScheme.onSurface,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),

                        Expanded(
                          child: LaTeXText(
                            option,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: isSelected
                                  ? theme.colorScheme.onSurface
                                  : theme.colorScheme.onSurface
                                      .withOpacity(0.87),
                              fontWeight: isSelected
                                  ? FontWeight.w500
                                  : FontWeight.normal,
                            ),
                          ),
                        ),

                        if (isSelected) ...[
                          const SizedBox(width: 8),
                          Icon(
                            Icons.check_circle,
                            color: theme.colorScheme.primary,
                            size: 20,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
