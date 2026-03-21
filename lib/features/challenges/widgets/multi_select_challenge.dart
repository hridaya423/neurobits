import 'package:flutter/material.dart';
import 'package:neurobits/core/widgets/latex_text.dart';
import 'package:neurobits/features/challenges/widgets/question_hint_accordion.dart';
import 'package:neurobits/features/challenges/widgets/question_visual_block.dart';

class MultiSelectChallenge extends StatefulWidget {
  final String question;
  final List<String> options;
  final void Function(List<String>) onSubmitted;
  final bool isDisabled;
  final String? hint;
  final String? imageUrl;
  final Map<String, dynamic>? chartSpec;

  const MultiSelectChallenge({
    super.key,
    required this.question,
    required this.options,
    required this.onSubmitted,
    this.isDisabled = false,
    this.hint,
    this.imageUrl,
    this.chartSpec,
  });

  @override
  State<MultiSelectChallenge> createState() => _MultiSelectChallengeState();
}

class _MultiSelectChallengeState extends State<MultiSelectChallenge> {
  final Set<int> _selected = <int>{};
  bool _submitted = false;

  @override
  void didUpdateWidget(covariant MultiSelectChallenge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.question != widget.question ||
        oldWidget.options.length != widget.options.length) {
      _selected.clear();
      _submitted = false;
    }
  }

  void _toggleOption(int index) {
    if (_submitted || widget.isDisabled) return;
    setState(() {
      if (_selected.contains(index)) {
        _selected.remove(index);
      } else {
        _selected.add(index);
      }
    });
  }

  void _submit() {
    if (_submitted || widget.isDisabled || _selected.isEmpty) return;
    setState(() => _submitted = true);
    final selectedIndices = _selected.toList()..sort();
    final selectedAnswers =
        selectedIndices.map((index) => widget.options[index]).toList();
    widget.onSubmitted(selectedAnswers);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: ListView(
        children: [
          LaTeXText(
            widget.question,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
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
          const SizedBox(height: 8),
          Text(
            'Select all correct answers',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          ...widget.options.asMap().entries.map((entry) {
            final index = entry.key;
            final option = entry.value;
            final isSelected = _selected.contains(index);
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: (_submitted || widget.isDisabled)
                    ? null
                    : () => _toggleOption(index),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? colorScheme.primary
                          : colorScheme.outline.withValues(alpha: 0.3),
                      width: isSelected ? 1.8 : 1,
                    ),
                    color: isSelected
                        ? colorScheme.primary.withValues(alpha: 0.12)
                        : colorScheme.surface,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isSelected
                            ? Icons.check_box_rounded
                            : Icons.check_box_outline_blank_rounded,
                        color: isSelected
                            ? colorScheme.primary
                            : colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: LaTeXText(
                          option,
                          style: theme.textTheme.bodyLarge,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: (_submitted || widget.isDisabled || _selected.isEmpty)
                ? null
                : _submit,
            child: const Text('Submit Selections'),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
