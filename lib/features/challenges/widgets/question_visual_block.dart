import 'package:flutter/material.dart';
import 'package:neurobits/features/challenges/widgets/question_chart_block.dart';
import 'package:neurobits/features/challenges/widgets/question_image_block.dart';

class QuestionVisualBlock extends StatelessWidget {
  final String? imageUrl;
  final Map<String, dynamic>? chartSpec;

  const QuestionVisualBlock({
    super.key,
    this.imageUrl,
    this.chartSpec,
  });

  @override
  Widget build(BuildContext context) {
    if (chartSpec != null && chartSpec!.isNotEmpty) {
      return QuestionChartBlock(chartSpec: chartSpec!);
    }

    final url = imageUrl?.trim() ?? '';
    if (url.isNotEmpty) {
      return QuestionImageBlock(imageUrl: url);
    }

    return const SizedBox.shrink();
  }
}
