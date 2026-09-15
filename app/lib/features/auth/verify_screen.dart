import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_exception.dart';
import '../../core/theme.dart';
import '../../widgets/page_shell.dart';
import 'auth_controller.dart';

class VerifyScreen extends ConsumerStatefulWidget {
  const VerifyScreen({super.key, required this.identifier, this.devCode});

  final String identifier;

  /// Present only against a dev server; prefilled so the loop is testable
  /// without an SMS provider wired up.
  final String? devCode;

  @override
  ConsumerState<VerifyScreen> createState() => _VerifyScreenState();
}

class _VerifyScreenState extends ConsumerState<VerifyScreen> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.devCode ?? '');
  bool _verifying = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final code = _controller.text.trim();
    if (code.length != 6) {
      setState(() => _error = 'Enter the 6-digit code.');
      return;
    }

    setState(() {
      _verifying = true;
      _error = null;
    });

    try {
      // On success the router redirects automatically off the auth state.
      await ref.read(authControllerProvider.notifier).verifyOtp(widget.identifier, code);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  Future<void> _resend() async {
    try {
      final result = await ref.read(authControllerProvider.notifier).requestOtp(widget.identifier);
      if (!mounted) return;
      setState(() {
        _error = null;
        if (result.devCode != null) _controller.text = result.devCode!;
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('New code sent.')));
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      body: SafeArea(
        child: PageShell(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              Text('Enter your code', style: text.displaySmall),
              const SizedBox(height: 12),
              Text(
                'Sent to ${widget.identifier}',
                style: text.bodyMedium?.copyWith(color: WaveColors.muted),
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _controller,
                autofocus: true,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                style: const TextStyle(fontSize: 28, letterSpacing: 12, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
                onSubmitted: (_) => _submit(),
                decoration: const InputDecoration(hintText: '······'),
              ),
              if (widget.devCode != null) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.info_outline, size: 15, color: WaveColors.muted),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        'Dev server: code prefilled for you.',
                        style: text.bodySmall?.copyWith(color: WaveColors.muted),
                      ),
                    ),
                  ],
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: text.bodyMedium?.copyWith(color: WaveColors.danger)),
              ],
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _verifying ? null : _submit,
                child: _verifying
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: WaveColors.ink),
                      )
                    : const Text('Continue'),
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: _verifying ? null : _resend,
                  child: const Text('Send a new code',
                      style: TextStyle(color: WaveColors.muted)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
