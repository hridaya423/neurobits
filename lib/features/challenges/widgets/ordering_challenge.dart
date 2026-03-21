import 'package:flutter/material.dart';
import 'package:neurobits/core/widgets/latex_text.dart';
import 'package:neurobits/features/challenges/widgets/question_hint_accordion.dart';
import 'package:neurobits/features/challenges/widgets/question_visual_block.dart';

class OrderingChallenge extends StatefulWidget {
  final String question;
  final List<String> items;
  final void Function(List<String>) onSubmitted;
  final bool isDisabled;
  final String? hint;
  final String? imageUrl;
  final Map<String, dynamic>? chartSpec;

  const OrderingChallenge({
    super.key,
    required this.question,
    required this.items,
    required this.onSubmitted,
    this.isDisabled = false,
    this.hint,
    this.imageUrl,
    this.chartSpec,
  });

  @override
  State<OrderingChallenge> createState() => _OrderingChallengeState();
}

class _OrderingChallengeState extends State<OrderingChallenge> {
  late List<String> _currentOrder;
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    _currentOrder = List<String>.from(widget.items);
  }

  @override
  void didUpdateWidget(covariant OrderingChallenge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.question != widget.question ||
        oldWidget.items.length != widget.items.length) {
      _currentOrder = List<String>.from(widget.items);
      _submitted = false;
    }
  }

  void _moveUp(int index) {
    if (_submitted || widget.isDisabled || index <= 0) return;
    setState(() {
      final item = _currentOrder.removeAt(index);
      _currentOrder.insert(index - 1, item);
    });
  }

  void _moveDown(int index) {
    if (_submitted || widget.isDisabled || index >= _currentOrder.length - 1) {
      return;
    }
    setState(() {
      final item = _currentOrder.removeAt(index);
      _currentOrder.insert(index + 1, item);
    });
  }

  void _submit() {
    if (_submitted || widget.isDisabled) return;
    setState(() => _submitted = true);
    widget.onSubmitted(List<String>.from(_currentOrder));
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
            'Arrange the items in the correct order',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 18),
          ..._currentOrder.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color:
                    colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: colorScheme.outline.withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: colorScheme.primary.withValues(alpha: 0.15),
                    ),
                    child: Text(
                      '${index + 1}',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: LaTeXText(item, style: theme.textTheme.bodyMedium),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        onPressed: (_submitted || widget.isDisabled)
                            ? null
                            : () => _moveUp(index),
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.keyboard_arrow_up_rounded),
                      ),
                      IconButton(
                        onPressed: (_submitted || widget.isDisabled)
                            ? null
                            : () => _moveDown(index),
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.keyboard_arrow_down_rounded),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: (_submitted || widget.isDisabled) ? null : _submit,
            child: const Text('Submit Order'),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
