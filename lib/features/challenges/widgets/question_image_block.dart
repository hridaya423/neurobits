import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

class QuestionImageBlock extends StatefulWidget {
  final String imageUrl;

  const QuestionImageBlock({
    super.key,
    required this.imageUrl,
  });

  @override
  State<QuestionImageBlock> createState() => _QuestionImageBlockState();
}

class _QuestionImageBlockState extends State<QuestionImageBlock> {
  Uint8List? _inlineBytes;

  @override
  void initState() {
    super.initState();
    _inlineBytes = _decodeDataImage(widget.imageUrl);
  }

  @override
  void didUpdateWidget(covariant QuestionImageBlock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _inlineBytes = _decodeDataImage(widget.imageUrl);
    }
  }

  Uint8List? _decodeDataImage(String value) {
    if (!value.startsWith('data:image/')) return null;
    final commaIndex = value.indexOf(',');
    if (commaIndex <= 0 || commaIndex >= value.length - 1) return null;
    final base64Part = value.substring(commaIndex + 1);
    try {
      return base64Decode(base64Part);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final imageUrl = widget.imageUrl;
    final inlineBytes = _inlineBytes;

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          border:
              Border.all(color: colorScheme.outline.withValues(alpha: 0.25)),
          borderRadius: BorderRadius.circular(12),
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
        ),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: inlineBytes != null
              ? Image.memory(
                  inlineBytes,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                  errorBuilder: (context, error, stackTrace) {
                    return Center(
                      child: Text(
                        'Image unavailable',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    );
                  },
                )
              : Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Center(
                      child: SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded /
                                  loadingProgress.expectedTotalBytes!
                              : null,
                        ),
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Center(
                      child: Text(
                        'Image unavailable',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}
