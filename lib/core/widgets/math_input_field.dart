import 'package:flutter/material.dart';

class MathInputField extends StatefulWidget {
  final TextEditingController controller;
  final String? labelText;
  final String? hintText;
  final bool enabled;
  final VoidCallback? onSubmitted;
  final ValueChanged<String>? onChanged;

  const MathInputField({
    super.key,
    required this.controller,
    this.labelText,
    this.hintText,
    this.enabled = true,
    this.onSubmitted,
    this.onChanged,
  });

  @override
  State<MathInputField> createState() => _MathInputFieldState();
}

class _MathInputFieldState extends State<MathInputField> {
  bool _showMathButtons = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: widget.controller,
          enabled: widget.enabled,
          decoration: InputDecoration(
            labelText: widget.labelText,
            hintText: widget.hintText,
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              icon: Icon(
                  _showMathButtons ? Icons.keyboard_hide : Icons.functions),
              onPressed: () {
                setState(() {
                  _showMathButtons = !_showMathButtons;
                });
              },
              tooltip:
                  _showMathButtons ? 'Hide math symbols' : 'Show math symbols',
            ),
          ),
          onSubmitted: (_) => widget.onSubmitted?.call(),
          onChanged: widget.onChanged,
        ),
        if (_showMathButtons) ...[
          const SizedBox(height: 8),
          _buildMathButtons(),
        ],
      ],
    );
  }

  Widget _buildMathButtons() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(color: Theme.of(context).colorScheme.outline),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          _buildButtonRow([
            {'display': '+', 'latex': '+'},
            {'display': '-', 'latex': '-'},
            {'display': '×', 'latex': r'\times'},
            {'display': '÷', 'latex': r'\div'},
            {'display': '=', 'latex': '='},
            {'display': '≠', 'latex': r'\neq'},
            {'display': '≤', 'latex': r'\leq'},
            {'display': '≥', 'latex': r'\geq'},
          ]),
          const SizedBox(height: 8),
          _buildButtonRow([
            {'display': 'x²', 'latex': '^2'},
            {'display': 'x³', 'latex': '^3'},
            {'display': '√', 'latex': r'\sqrt{}'},
            {'display': 'π', 'latex': r'\pi'},
            {'display': 'α', 'latex': r'\alpha'},
            {'display': 'β', 'latex': r'\beta'},
            {'display': 'θ', 'latex': r'\theta'},
            {'display': '∞', 'latex': r'\infty'},
          ]),
          const SizedBox(height: 8),
          _buildButtonRow([
            {'display': '(', 'latex': '('},
            {'display': ')', 'latex': ')'},
            {'display': '[', 'latex': '['},
            {'display': ']', 'latex': ']'},
            {'display': '{', 'latex': '{'},
            {'display': '}', 'latex': '}'},
            {'display': 'frac', 'latex': r'\frac{}{}'},
            {'display': '±', 'latex': r'\pm'},
          ]),
          const SizedBox(height: 8),
          _buildButtonRow([
            {'display': '∑', 'latex': r'\sum'},
            {'display': '∫', 'latex': r'\int'},
            {'display': '∈', 'latex': r'\in'},
            {'display': '∪', 'latex': r'\cup'},
            {'display': '∩', 'latex': r'\cap'},
            {'display': '→', 'latex': r'\rightarrow'},
            {'display': '↔', 'latex': r'\leftrightarrow'},
            {'display': '≈', 'latex': r'\approx'},
          ]),
        ],
      ),
    );
  }

  Widget _buildButtonRow(List<Map<String, String>> symbols) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: symbols.map((symbol) => _buildMathButton(symbol)).toList(),
    );
  }

  Widget _buildMathButton(Map<String, String> symbol) {
    final display = symbol['display']!;
    final latex = symbol['latex']!;

    return Flexible(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: ElevatedButton(
          onPressed: () => _insertSymbol(latex),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            minimumSize: const Size(32, 36),
          ),
          child: Text(
            display,
            style: const TextStyle(fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  void _insertSymbol(String symbol) {
    final controller = widget.controller;
    final text = controller.text;
    final selection = controller.selection;

    String newText;
    int newCursorPosition;

    final cursorPosition = selection.isValid && selection.baseOffset >= 0
        ? selection.baseOffset
        : text.length;

    if (selection.isValid && selection.start != selection.end) {
      newText = text.replaceRange(selection.start, selection.end, symbol);
      newCursorPosition = _calculateCursorPosition(symbol, selection.start);
    } else {
      newText = text.substring(0, cursorPosition) +
          symbol +
          text.substring(cursorPosition);
      newCursorPosition = _calculateCursorPosition(symbol, cursorPosition);
    }

    controller.text = newText;
    controller.selection = TextSelection.fromPosition(
      TextPosition(offset: newCursorPosition),
    );

    widget.onChanged?.call(newText);
  }

  int _calculateCursorPosition(String symbol, int insertPosition) {
    if (symbol.contains('{}')) {
      final braceIndex = symbol.indexOf('{}');
      return insertPosition + braceIndex + 1;
    } else if (symbol == r'\frac{}{}') {
      return insertPosition + 6;
    } else if (symbol == r'\sqrt{}') {
      return insertPosition + 6;
    } else {
      return insertPosition + symbol.length;
    }
  }
}
