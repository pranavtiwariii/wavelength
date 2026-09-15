import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_exception.dart';
import '../../core/theme.dart';
import '../../widgets/page_shell.dart';
import 'auth_controller.dart';

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _controller = TextEditingController();
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final identifier = _controller.text.trim();
    if (identifier.isEmpty) return;

    setState(() {
      _sending = true;
      _error = null;
    });

    try {
      final result = await ref.read(authControllerProvider.notifier).requestOtp(identifier);
      if (!mounted) return;
      context.push('/verify', extra: {'identifier': identifier, 'devCode': result.devCode});
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: PageShell(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(flex: 2),
              const _WaveMark(),
              const SizedBox(height: 28),
              Text('Find people on\nyour wavelength.', style: text.displaySmall),
              const SizedBox(height: 14),
              Text(
                'We match on what you actually listen to, watch and read — not on a bio.',
                style: text.bodyMedium?.copyWith(color: WaveColors.muted),
              ),
              const Spacer(flex: 2),
              TextField(
                controller: _controller,
                autocorrect: false,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.go,
                onSubmitted: (_) => _submit(),
                decoration: const InputDecoration(hintText: 'Email or phone number'),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: text.bodyMedium?.copyWith(color: WaveColors.danger),
                ),
              ],
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _sending ? null : _submit,
                child: _sending
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: WaveColors.ink),
                      )
                    : const Text('Send me a code'),
              ),
              const SizedBox(height: 18),
              Text(
                'We’ll text or email you a 6-digit code. No password to forget.',
                textAlign: TextAlign.center,
                style: text.bodySmall?.copyWith(color: WaveColors.muted),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}

/// Three offset arcs — the "wavelength" mark. Drawn rather than shipped as an
/// asset so it scales and re-themes cleanly.
class _WaveMark extends StatelessWidget {
  const _WaveMark();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      width: 90,
      child: CustomPaint(painter: _WavePainter()),
    );
  }
}

class _WavePainter extends CustomPainter {
  static const _colors = [WaveColors.music, WaveColors.movie, WaveColors.book];

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < _colors.length; i++) {
      final paint = Paint()
        ..color = _colors[i]
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round;

      final path = Path();
      final amplitude = size.height / 2 - 4;
      final phase = i * 0.7;
      for (var x = 0.0; x <= size.width; x += 1) {
        final y = size.height / 2 +
            amplitude * 0.8 * _sin((x / size.width) * 6.2831 + phase) * (1 - i * 0.22);
        if (x == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      canvas.drawPath(path, paint);
    }
  }

  static double _sin(double v) => math.sin(v);

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
