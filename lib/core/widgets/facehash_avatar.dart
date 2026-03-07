import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:path_drawing/path_drawing.dart';

enum FacehashVariant { gradient, solid }

enum FacehashIntensity { none, subtle, medium, dramatic }

enum FacehashShape { square, squircle, round }

enum FacehashFaceType { round, cross, line, curved }

class FacehashAvatar extends StatefulWidget {
  final String name;
  final double size;
  final FacehashVariant variant;
  final FacehashIntensity intensity3d;
  final FacehashShape shape;
  final bool showInitial;
  final bool showMouth;
  final bool enableBlink;
  final bool interactive;
  final List<Color>? colors;

  const FacehashAvatar({
    super.key,
    required this.name,
    this.size = 40,
    this.variant = FacehashVariant.gradient,
    this.intensity3d = FacehashIntensity.dramatic,
    this.shape = FacehashShape.round,
    this.showInitial = true,
    this.showMouth = true,
    this.enableBlink = false,
    this.interactive = true,
    this.colors,
  });

  @override
  State<FacehashAvatar> createState() => _FacehashAvatarState();
}

class _FacehashAvatarState extends State<FacehashAvatar>
    with SingleTickerProviderStateMixin {
  late FacehashData _data;
  late AnimationController _blinkController;
  Timer? _blinkDelayTimer;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _data = computeFacehash(widget.name, colorsLength: _palette.length);
    _blinkController = AnimationController(
      vsync: this,
      duration: _blinkDuration,
    );
    _scheduleBlink();
  }

  @override
  void didUpdateWidget(FacehashAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.name != widget.name ||
        oldWidget.colors?.length != widget.colors?.length) {
      _data = computeFacehash(widget.name, colorsLength: _palette.length);
      _blinkController
        ..stop()
        ..duration = _blinkDuration;
      _scheduleBlink();
    }
  }

  @override
  void dispose() {
    _blinkDelayTimer?.cancel();
    _blinkController.dispose();
    super.dispose();
  }

  Duration get _blinkDuration {
    final blinkSeed = (_data.hash * 31) & 0xffffffff;
    final durationSeconds = 2 + (blinkSeed % 40) / 10;
    return Duration(milliseconds: (durationSeconds * 1000).round());
  }

  Duration get _blinkDelay {
    final blinkSeed = (_data.hash * 31) & 0xffffffff;
    final delaySeconds = (blinkSeed % 40) / 10;
    return Duration(milliseconds: (delaySeconds * 1000).round());
  }

  void _scheduleBlink() {
    _blinkDelayTimer?.cancel();
    if (!widget.enableBlink) return;
    _blinkDelayTimer = Timer(_blinkDelay, () {
      if (!mounted) return;
      _blinkController.repeat();
    });
  }

  List<Color> get _palette => widget.colors ?? kCossistantColors;

  @override
  Widget build(BuildContext context) {
    final base = AnimatedBuilder(
      animation: _blinkController,
      builder: (context, _) {
        final blinkPhase = widget.enableBlink ? _blinkController.value : 0.0;
        return CustomPaint(
          size: Size.square(widget.size),
          painter: FacehashPainter(
            data: _data,
            colors: _palette,
            variant: widget.variant,
            intensity3d: widget.intensity3d,
            showInitial: widget.showInitial,
            showMouth: widget.showMouth,
            blinkPhase: blinkPhase,
            isHovered: _isHovered && widget.interactive,
          ),
        );
      },
    );

    Widget clipped = base;
    final borderRadius = _shapeRadius(widget.shape, widget.size);
    if (borderRadius > 0) {
      clipped = ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: base,
      );
    }

    return MouseRegion(
      onEnter: (_) {
        if (!widget.interactive) return;
        setState(() => _isHovered = true);
      },
      onExit: (_) {
        if (!widget.interactive) return;
        setState(() => _isHovered = false);
      },
      child: clipped,
    );
  }
}

double _shapeRadius(FacehashShape shape, double size) {
  switch (shape) {
    case FacehashShape.round:
      return size / 2;
    case FacehashShape.squircle:
      return size * 0.28;
    case FacehashShape.square:
      return 0;
  }
}

class FacehashData {
  final FacehashFaceType faceType;
  final int colorIndex;
  final Offset rotation;
  final String initial;
  final int hash;

  const FacehashData({
    required this.faceType,
    required this.colorIndex,
    required this.rotation,
    required this.initial,
    required this.hash,
  });
}

const List<Offset> _spherePositions = [
  Offset(-1, 1),
  Offset(1, 1),
  Offset(1, 0),
  Offset(0, 1),
  Offset(-1, 0),
  Offset(0, 0),
  Offset(0, -1),
  Offset(-1, -1),
  Offset(1, -1),
];

const List<FacehashFaceType> _faceTypes = [
  FacehashFaceType.round,
  FacehashFaceType.cross,
  FacehashFaceType.line,
  FacehashFaceType.curved,
];

FacehashData computeFacehash(String name, {int colorsLength = 5}) {
  final hash = stringHash(name);
  final faceIndex = hash % _faceTypes.length;
  final colorIndex = hash % max(colorsLength, 1).toInt();
  final positionIndex = hash % _spherePositions.length;
  final position = _spherePositions[positionIndex];
  final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

  return FacehashData(
    faceType: _faceTypes[faceIndex],
    colorIndex: colorIndex,
    rotation: position,
    initial: initial,
    hash: hash,
  );
}

int stringHash(String input) {
  int hash = 0;
  for (final unit in input.codeUnits) {
    hash = (hash << 5) - hash + unit;
    hash = hash.toSigned(32);
  }
  return hash.abs();
}

class FacehashPainter extends CustomPainter {
  final FacehashData data;
  final List<Color> colors;
  final FacehashVariant variant;
  final FacehashIntensity intensity3d;
  final bool showInitial;
  final bool showMouth;
  final double blinkPhase;
  final bool isHovered;

  FacehashPainter({
    required this.data,
    required this.colors,
    required this.variant,
    required this.intensity3d,
    required this.showInitial,
    required this.showMouth,
    required this.blinkPhase,
    required this.isHovered,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final background = colors[data.colorIndex % colors.length];
    final paint = Paint()..color = background;
    canvas.drawRect(Offset.zero & size, paint);

    if (variant == FacehashVariant.gradient) {
      final gradient = RadialGradient(
        colors: [
          Colors.white.withOpacity(0.15),
          Colors.transparent,
        ],
        stops: const [0.0, 0.6],
      );
      final gradientPaint = Paint()
        ..shader = gradient.createShader(Offset.zero & size);
      canvas.drawRect(Offset.zero & size, gradientPaint);
    }

    final faceWidth = size.width * 0.6;
    final rawFaceHeight = faceWidth / _faceAspectRatio(data.faceType);
    final faceHeight = min(rawFaceHeight, size.height * 0.4);
    final faceRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: faceWidth,
      height: faceHeight,
    );

    final offsetMagnitude = size.width * 0.05 * _intensityFactor(intensity3d);
    final offset = isHovered
        ? Offset.zero
        : Offset(data.rotation.dy * offsetMagnitude,
            -data.rotation.dx * offsetMagnitude);

    canvas.save();
    canvas.translate(offset.dx, offset.dy);
    _drawFace(canvas, faceRect, size);
    if (showInitial) {
      _drawInitial(canvas, size, faceRect);
    } else if (showMouth) {
      _drawMouth(canvas, size, faceRect);
    }
    canvas.restore();
  }

  void _drawFace(Canvas canvas, Rect rect, Size size) {
    final facePaint = Paint()..color = Colors.black;
    final blinkScale = _blinkScale(blinkPhase);

    canvas.save();
    canvas.translate(rect.left, rect.top);
    canvas.scale(rect.width / _faceWidth(data.faceType),
        rect.height / _faceHeight(data.faceType));

    switch (data.faceType) {
      case FacehashFaceType.round:
        _drawRoundFace(canvas, facePaint, blinkScale);
        break;
      case FacehashFaceType.cross:
        _drawCrossFace(canvas, facePaint, blinkScale);
        break;
      case FacehashFaceType.line:
        _drawLineFace(canvas, facePaint, blinkScale);
        break;
      case FacehashFaceType.curved:
        _drawCurvedFace(canvas, facePaint, blinkScale);
        break;
    }

    canvas.restore();
  }

  void _drawInitial(Canvas canvas, Size size, Rect faceRect) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: data.initial,
        style: TextStyle(
          color: Colors.black,
          fontWeight: FontWeight.w700,
          fontSize: size.width * 0.26,
          fontFamily: 'monospace',
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final offset = Offset(
      (size.width - textPainter.width) / 2,
      faceRect.bottom + size.height * 0.08,
    );
    textPainter.paint(canvas, offset);
  }

  void _drawMouth(Canvas canvas, Size size, Rect faceRect) {
    final mouthPaint = Paint()
      ..color = Colors.black
      ..strokeWidth = size.width * 0.045
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final center = Offset(size.width / 2, faceRect.bottom + size.height * 0.08);
    final width = size.width * 0.22;
    final height = size.width * 0.06;
    final isSmile = (data.hash % 2) == 0;

    final path = Path();
    if (isSmile) {
      path.moveTo(center.dx - width, center.dy);
      path.quadraticBezierTo(
        center.dx,
        center.dy + height,
        center.dx + width,
        center.dy,
      );
    } else {
      path.moveTo(center.dx - width * 0.9, center.dy);
      path.lineTo(center.dx + width * 0.9, center.dy);
    }
    canvas.drawPath(path, mouthPaint);
  }

  double _blinkScale(double t) {
    if (t <= 0) return 1.0;
    if (t < 0.92) return 1.0;
    if (t < 0.96) {
      return lerpDouble(1.0, 0.05, (t - 0.92) / 0.04) ?? 1.0;
    }
    if (t <= 1.0) {
      return lerpDouble(0.05, 1.0, (t - 0.96) / 0.04) ?? 1.0;
    }
    return 1.0;
  }

  @override
  bool shouldRepaint(covariant FacehashPainter oldDelegate) {
    return oldDelegate.data != data ||
        oldDelegate.colors != colors ||
        oldDelegate.variant != variant ||
        oldDelegate.intensity3d != intensity3d ||
        oldDelegate.showInitial != showInitial ||
        oldDelegate.showMouth != showMouth ||
        oldDelegate.blinkPhase != blinkPhase ||
        oldDelegate.isHovered != isHovered;
  }
}

double _intensityFactor(FacehashIntensity intensity) {
  switch (intensity) {
    case FacehashIntensity.none:
      return 0;
    case FacehashIntensity.subtle:
      return 0.6;
    case FacehashIntensity.medium:
      return 0.8;
    case FacehashIntensity.dramatic:
      return 1.0;
  }
}

double _faceAspectRatio(FacehashFaceType type) {
  return _faceWidth(type) / _faceHeight(type);
}

double _faceWidth(FacehashFaceType type) {
  switch (type) {
    case FacehashFaceType.round:
      return 63;
    case FacehashFaceType.cross:
      return 71;
    case FacehashFaceType.line:
      return 82;
    case FacehashFaceType.curved:
      return 63;
  }
}

double _faceHeight(FacehashFaceType type) {
  switch (type) {
    case FacehashFaceType.round:
      return 15;
    case FacehashFaceType.cross:
      return 23;
    case FacehashFaceType.line:
      return 8;
    case FacehashFaceType.curved:
      return 9;
  }
}

void _drawRoundFace(Canvas canvas, Paint paint, double blinkScale) {
  _drawBlinkGroup(
    canvas,
    Rect.fromCircle(center: const Offset(7.2, 7.2), radius: 7.2),
    blinkScale,
    () => canvas.drawCircle(const Offset(7.2, 7.2), 7.2, paint),
  );
  _drawBlinkGroup(
    canvas,
    Rect.fromCircle(center: const Offset(55.2, 7.2), radius: 7.2),
    blinkScale,
    () => canvas.drawCircle(const Offset(55.2, 7.2), 7.2, paint),
  );
}

void _drawCrossFace(Canvas canvas, Paint paint, double blinkScale) {
  final leftRects = [
    RRect.fromRectAndRadius(
      const Rect.fromLTWH(8, 0, 7, 23),
      const Radius.circular(3.5),
    ),
    RRect.fromRectAndRadius(
      const Rect.fromLTWH(0, 8, 23, 7),
      const Radius.circular(3.5),
    ),
  ];
  final rightRects = [
    RRect.fromRectAndRadius(
      const Rect.fromLTWH(55.2, 0, 7, 23),
      const Radius.circular(3.5),
    ),
    RRect.fromRectAndRadius(
      const Rect.fromLTWH(47.3, 8, 23, 7),
      const Radius.circular(3.5),
    ),
  ];

  _drawBlinkGroup(
    canvas,
    _rectBounds(leftRects),
    blinkScale,
    () {
      for (final rect in leftRects) {
        canvas.drawRRect(rect, paint);
      }
    },
  );
  _drawBlinkGroup(
    canvas,
    _rectBounds(rightRects),
    blinkScale,
    () {
      for (final rect in rightRects) {
        canvas.drawRRect(rect, paint);
      }
    },
  );
}

void _drawLineFace(Canvas canvas, Paint paint, double blinkScale) {
  final leftRects = [
    RRect.fromRectAndRadius(
      const Rect.fromLTWH(0.07, 0.16, 6.9, 6.9),
      const Radius.circular(3.5),
    ),
    RRect.fromRectAndRadius(
      const Rect.fromLTWH(7.9, 0.16, 20.7, 6.9),
      const Radius.circular(3.5),
    ),
  ];
  final rightRects = [
    RRect.fromRectAndRadius(
      const Rect.fromLTWH(74.7, 0.16, 6.9, 6.9),
      const Radius.circular(3.5),
    ),
    RRect.fromRectAndRadius(
      const Rect.fromLTWH(53.1, 0.16, 20.7, 6.9),
      const Radius.circular(3.5),
    ),
  ];

  _drawBlinkGroup(
    canvas,
    _rectBounds(leftRects),
    blinkScale,
    () {
      for (final rect in leftRects) {
        canvas.drawRRect(rect, paint);
      }
    },
  );
  _drawBlinkGroup(
    canvas,
    _rectBounds(rightRects),
    blinkScale,
    () {
      for (final rect in rightRects) {
        canvas.drawRRect(rect, paint);
      }
    },
  );
}

void _drawCurvedFace(Canvas canvas, Paint paint, double blinkScale) {
  final leftPath = parseSvgPathData(
    'M0 5.1c0-.1 0-.2 0-.3.1-.5.3-1 .7-1.3.1 0 .1-.1.2-.1C2.4 2.2 6 0 10.5 0S18.6 2.2 20.2 3.3c.1 0 .1.1.1.1.4.3.7.9.7 1.3v.3c0 1 0 1.4 0 1.7-.2 1.3-1.2 1.9-2.5 1.6-.2 0-.7-.3-1.8-.8C15 6.7 12.8 6 10.5 6s-4.5.7-6.3 1.5c-1 .5-1.5.7-1.8.8-1.3.3-2.3-.3-2.5-1.6v-1.7z',
  );
  final rightPath = parseSvgPathData(
    'M42 5.1c0-.1 0-.2 0-.3.1-.5.3-1 .7-1.3.1 0 .1-.1.2-.1C44.4 2.2 48 0 52.5 0S60.6 2.2 62.2 3.3c.1 0 .1.1.1.1.4.3.7.9.7 1.3v.3c0 1 0 1.4 0 1.7-.2 1.3-1.2 1.9-2.5 1.6-.2 0-.7-.3-1.8-.8C57 6.7 54.8 6 52.5 6s-4.5.7-6.3 1.5c-1 .5-1.5.7-1.8.8-1.3.3-2.3-.3-2.5-1.6v-1.7z',
  );

  _drawBlinkGroup(
    canvas,
    leftPath.getBounds(),
    blinkScale,
    () => canvas.drawPath(leftPath, paint),
  );
  _drawBlinkGroup(
    canvas,
    rightPath.getBounds(),
    blinkScale,
    () => canvas.drawPath(rightPath, paint),
  );
}

void _drawBlinkGroup(
  Canvas canvas,
  Rect bounds,
  double blinkScale,
  VoidCallback draw,
) {
  canvas.save();
  canvas.translate(bounds.center.dx, bounds.center.dy);
  canvas.scale(1, blinkScale);
  canvas.translate(-bounds.center.dx, -bounds.center.dy);
  draw();
  canvas.restore();
}

Rect _rectBounds(List<RRect> rects) {
  Rect? bounds;
  for (final rect in rects) {
    bounds = bounds == null
        ? rect.outerRect
        : bounds!.expandToInclude(rect.outerRect);
  }
  return bounds ?? Rect.zero;
}

final List<Color> kCossistantColors = [
  HSLColor.fromAHSL(1, 314, 1.0, 0.8).toColor(),
  HSLColor.fromAHSL(1, 58, 0.93, 0.72).toColor(),
  HSLColor.fromAHSL(1, 218, 0.92, 0.72).toColor(),
  HSLColor.fromAHSL(1, 19, 0.99, 0.44).toColor(),
  HSLColor.fromAHSL(1, 156, 0.86, 0.40).toColor(),
  HSLColor.fromAHSL(1, 314, 1.0, 0.85).toColor(),
  HSLColor.fromAHSL(1, 58, 0.92, 0.79).toColor(),
  HSLColor.fromAHSL(1, 218, 0.91, 0.78).toColor(),
  HSLColor.fromAHSL(1, 19, 0.99, 0.50).toColor(),
  HSLColor.fromAHSL(1, 156, 0.86, 0.64).toColor(),
];
