import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme.dart';

/// The compatibility number, as a ring. Used at three sizes: on a discovery
/// card, on the breakdown header, and inline in the matches list.
class ScoreBadge extends StatelessWidget {
  const ScoreBadge({super.key, required this.score, this.size = 64, this.showLabel = true});

  final int score;
  final double size;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final color = WaveColors.forScore(score);

    return SizedBox(
      height: size,
      width: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size.square(size),
            painter: _RingPainter(value: score / 100, color: color),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$score',
                style: TextStyle(
                  fontSize: size * 0.34,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.8,
                  color: color,
                  height: 1,
                ),
              ),
              if (showLabel && size >= 56)
                Text(
                  'match',
                  style: TextStyle(
                    fontSize: size * 0.13,
                    color: WaveColors.muted,
                    letterSpacing: 0.4,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.value, required this.color});

  final double value;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - 3;
    final stroke = size.width * 0.065;

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = WaveColors.surfaceHigh,
    );

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * value.clamp(0.0, 1.0),
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => old.value != value || old.color != color;
}
