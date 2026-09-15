import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Spec 4.1 / 8.1: two people's Taste DNA overlaid on one five-axis chart.
///
/// Drawn by hand rather than with a charting package so it can stay calm —
/// no gridline clutter, no legend chrome, no tooltips. The point is that the
/// overlap area reads as compatibility before you read the number.
class TasteDnaRadar extends StatelessWidget {
  const TasteDnaRadar({
    super.key,
    required this.you,
    required this.them,
    this.themLabel = 'Them',
    this.size = 240,
  });

  /// Axis name -> 0..1. Both maps must share keys.
  final Map<String, double> you;
  final Map<String, double> them;
  final String themLabel;
  final double size;

  static const axisLabels = <String, String>{
    'niche': 'Niche',
    'melancholic': 'Melancholy',
    'contemporary': 'Current',
    'maximalist': 'Maximal',
    'challenging': 'Difficult',
  };

  @override
  Widget build(BuildContext context) {
    final axes = axisLabels.keys.where((k) => you.containsKey(k)).toList();

    return Column(
      children: [
        SizedBox(
          height: size,
          width: size,
          child: CustomPaint(
            painter: _RadarPainter(
              axes: axes,
              you: [for (final a in axes) (you[a] ?? 0).clamp(0.0, 1.0)],
              them: [for (final a in axes) (them[a] ?? 0).clamp(0.0, 1.0)],
              labels: [for (final a in axes) axisLabels[a] ?? a],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _LegendDot(color: WaveColors.cream, label: 'You'),
            const SizedBox(width: 18),
            _LegendDot(color: WaveColors.music, label: themLabel),
          ],
        ),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: 8,
          width: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 7),
        Text(label, style: const TextStyle(fontSize: 12.5, color: WaveColors.muted)),
      ],
    );
  }
}

class _RadarPainter extends CustomPainter {
  _RadarPainter({
    required this.axes,
    required this.you,
    required this.them,
    required this.labels,
  });

  final List<String> axes;
  final List<double> you;
  final List<double> them;
  final List<String> labels;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    // Leave room for the axis labels outside the web.
    final radius = math.min(size.width, size.height) / 2 - 30;
    final count = axes.length;
    if (count < 3) return;

    // Web: three faint rings plus spokes.
    final web = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = WaveColors.stroke;

    for (final ratio in [0.4, 0.7, 1.0]) {
      final path = Path();
      for (var i = 0; i < count; i++) {
        final p = _point(center, radius * ratio, i, count);
        i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
      }
      path.close();
      canvas.drawPath(path, web);
    }
    for (var i = 0; i < count; i++) {
      canvas.drawLine(center, _point(center, radius, i, count), web);
    }

    // Two shapes: the viewer in cream, the other person in the music accent.
    _drawShape(canvas, center, radius, them, WaveColors.music, 0.24);
    _drawShape(canvas, center, radius, you, WaveColors.cream, 0.16);

    // Axis labels.
    for (var i = 0; i < count; i++) {
      final anchor = _point(center, radius + 19, i, count);
      final tp = TextPainter(
        text: TextSpan(
          text: labels[i],
          style: const TextStyle(fontSize: 10.5, color: WaveColors.muted, fontWeight: FontWeight.w600),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(anchor.dx - tp.width / 2, anchor.dy - tp.height / 2));
    }
  }

  void _drawShape(
    Canvas canvas,
    Offset center,
    double radius,
    List<double> values,
    Color color,
    double fillOpacity,
  ) {
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      // Floor the radius slightly so a zero axis still reads as a shape.
      final p = _point(center, radius * (0.08 + values[i] * 0.92), i, values.length);
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    path.close();

    canvas.drawPath(path, Paint()..color = color.withValues(alpha: fillOpacity));
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round
        ..color = color.withValues(alpha: 0.9),
    );
  }

  /// Vertex i of an n-gon, starting at 12 o'clock and going clockwise.
  Offset _point(Offset center, double radius, int index, int count) {
    final angle = -math.pi / 2 + (2 * math.pi * index / count);
    return Offset(center.dx + radius * math.cos(angle), center.dy + radius * math.sin(angle));
  }

  @override
  bool shouldRepaint(covariant _RadarPainter old) =>
      old.you != you || old.them != them || old.axes != axes;
}
