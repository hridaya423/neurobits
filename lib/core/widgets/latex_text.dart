import 'package:flutter/material.dart';

class LaTeXText extends StatelessWidget {
  final String content;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  const LaTeXText(
    this.content, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
  });

  @override
  Widget build(BuildContext context) {
    if (content.isEmpty) {
      return const SizedBox.shrink();
    }

    final formattedContent = _formatText(content);

    return Text(
      formattedContent,
      style: style,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
    );
  }

  String _formatText(String content) {
    String formatted = content;

    formatted = formatted.replaceAllMapped(
      RegExp(r'([A-Za-z])_\{?(\d+)\}?'),
      (match) => '${match.group(1)}${_getSubscript(match.group(2)!)}',
    );
    formatted = formatted.replaceAllMapped(
      RegExp(r'([A-Z][a-z]?)(\d+)'),
      (match) => '${match.group(1)}${_getSubscript(match.group(2)!)}',
    );

    formatted = formatted.replaceAllMapped(
      RegExp(r'([A-Za-z\d])(\^)\{?(\d+)\}?'),
      (match) => '${match.group(1)}${_getSuperscript(match.group(3)!)}',
    );

    final symbolReplacements = {
      r'\rightarrow': '→',
      r'\leftarrow': '←',
      r'\pi': 'π',
      r'\alpha': 'α',
      r'\beta': 'β',
      r'\gamma': 'γ',
      r'\delta': 'δ',
      r'\theta': 'θ',
      r'\lambda': 'λ',
      r'\mu': 'μ',
      r'\sigma': 'σ',
      r'\infty': '∞',
      r'\sum': '∑',
      r'\int': '∫',
      r'\neq': '≠',
      r'\leq': '≤',
      r'\geq': '≥',
      r'\pm': '±',
      r'\times': '×',
      r'\div': '÷',
      r'\approx': '≈',
      r'\equiv': '≡',
      r'\subset': '⊂',
      r'\supset': '⊃',
      r'\in': '∈',
      r'\notin': '∉',
      r'\cup': '∪',
      r'\cap': '∩',
      r'\emptyset': '∅',
      r'\sqrt': '√',
      '-->': '→',
      '->': '→',
    };

    symbolReplacements.forEach((latex, unicode) {
      formatted = formatted.replaceAll(latex, unicode);
    });

    formatted = formatted.replaceAll(r'\(', '');
    formatted = formatted.replaceAll(r'\)', '');
    formatted = formatted.replaceAll(r'\[', '');
    formatted = formatted.replaceAll(r'\]', '');
    formatted = formatted.replaceAll(r'$$', '');

    formatted = formatted.replaceAllMapped(
      RegExp(r'(?<!\$)\$([^$]+)\$(?!\$)'),
      (match) => match.group(1)!,
    );

    formatted = formatted.replaceAllMapped(
      RegExp(r'\text\{([^}]+)\}'),
      (match) => match.group(1)!,
    );

    formatted = formatted.replaceAllMapped(
      RegExp(r'\frac\{([^}]+)\}\{([^}]+)\}'),
      (match) => '${match.group(1)}/${match.group(2)}',
    );

    formatted = formatted.replaceAllMapped(
      RegExp(r'\sqrt\{([^}]+)\}'),
      (match) => '√(${match.group(1)})',
    );

    return formatted;
  }

  String _getSubscript(String number) {
    const subscripts = {
      '0': '₀',
      '1': '₁',
      '2': '₂',
      '3': '₃',
      '4': '₄',
      '5': '₅',
      '6': '₆',
      '7': '₇',
      '8': '₈',
      '9': '₉'
    };
    return number.split('').map((char) => subscripts[char] ?? char).join();
  }

  String _getSuperscript(String number) {
    const superscripts = {
      '0': '⁰',
      '1': '¹',
      '2': '²',
      '3': '³',
      '4': '⁴',
      '5': '⁵',
      '6': '⁶',
      '7': '⁷',
      '8': '⁸',
      '9': '⁹'
    };
    return number.split('').map((char) => superscripts[char] ?? char).join();
  }
}
