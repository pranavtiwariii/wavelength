import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme.dart';

/// The MATES mark: an M drawn as two linked peaks, with three offset waves
/// behind it in the domain accents. Drawn rather than shipped as an asset so
/// it scales, re-themes, and animates.
class MatesMark extends StatelessWidget {
  const MatesMark({super.key, this.size = 72, this.progress = 1});

  final double size;

  /// 0..1 — strokes draw on as this advances, used by the splash.
  final double progress;

  @override
  Widget build(BuildContext context) {
    final palette = Palette.of(context);
    return SizedBox(
      height: size,
      width: size,
      child: CustomPaint(
        painter: _MarkPainter(
          progress: progress,
          ink: palette.text,
          accents: [palette.music, palette.movie, palette.book],
        ),
      ),
    );
  }
}

class _MarkPainter extends CustomPainter {
  _MarkPainter({required this.progress, required this.ink, required this.accents});

  final double progress;
  final Color ink;
  final List<Color> accents;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Three waves behind the mark, each phase-shifted.
    for (var i = 0; i < accents.length; i++) {
      final paint = Paint()
        ..color = accents[i].withValues(alpha: 0.55 * progress)
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.035
        ..strokeCap = StrokeCap.round;

      final path = Path();
      final amp = h * 0.13;
      for (var x = 0.0; x <= w; x += 1) {
        final t = x / w;
        final y = h * 0.5 + amp * math.sin(t * math.pi * 2 + i * 0.85) * (1 - i * 0.18);
        x == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
      }
      canvas.drawPath(path, paint);
    }

    // The M itself, drawn on as progress advances.
    final m = Path()
      ..moveTo(w * 0.20, h * 0.72)
      ..lineTo(w * 0.20, h * 0.28)
      ..lineTo(w * 0.50, h * 0.58)
      ..lineTo(w * 0.80, h * 0.28)
      ..lineTo(w * 0.80, h * 0.72);

    final metrics = m.computeMetrics().toList();
    final drawn = Path();
    for (final metric in metrics) {
      drawn.addPath(metric.extractPath(0, metric.length * progress), Offset.zero);
    }

    canvas.drawPath(
      drawn,
      Paint()
        ..color = ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.085
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _MarkPainter old) =>
      old.progress != progress || old.ink != ink;
}

/// Splash animation: the mark rotates in, the M draws itself, then the
/// wordmark fades up. Hinge opens on a spinning H; this is the same idea.
class AnimatedMatesMark extends StatefulWidget {
  const AnimatedMatesMark({super.key, this.size = 92, this.showWordmark = true});

  final double size;
  final bool showWordmark;

  @override
  State<AnimatedMatesMark> createState() => _AnimatedMatesMarkState();
}

class _AnimatedMatesMarkState extends State<AnimatedMatesMark>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = Palette.of(context);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        // Draw on over the first 55%, hold, then loop.
        final draw = Curves.easeOutCubic.transform((t / 0.55).clamp(0.0, 1.0));
        final spin = Curves.easeInOutCubic.transform(t) * 2 * math.pi;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Transform.rotate(
              angle: spin,
              child: MatesMark(size: widget.size, progress: draw),
            ),
            if (widget.showWordmark) ...[
              const SizedBox(height: 20),
              Opacity(
                opacity: draw,
                child: Text(
                  'MATES',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 7,
                    color: palette.muted,
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
