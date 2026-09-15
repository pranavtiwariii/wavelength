import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_exception.dart';
import '../../core/theme.dart';
import '../../widgets/page_shell.dart';
import '../auth/auth_controller.dart';

/// Spec 3.1: the minimum needed before someone can appear in Discovery —
/// a name, an age, an intent. Taste import happens after, on the Taste tab,
/// so the first run isn't a wall of forms.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _name = TextEditingController();
  final _age = TextEditingController();
  final _city = TextEditingController();
  final _bio = TextEditingController();
  String _intent = 'both';
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _age.dispose();
    _city.dispose();
    _bio.dispose();
    super.dispose();
  }

  bool get _valid {
    final age = int.tryParse(_age.text.trim());
    return _name.text.trim().isNotEmpty && age != null && age >= 18 && age <= 120;
  }

  Future<void> _save() async {
    if (!_valid) {
      setState(() => _error = 'A name and an age (18+) are needed to continue.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await ref.read(authRepositoryProvider).client.patch('/me', body: {
        'name': _name.text.trim(),
        'age': int.parse(_age.text.trim()),
        'intent': _intent,
        if (_city.text.trim().isNotEmpty) 'city': _city.text.trim(),
        if (_bio.text.trim().isNotEmpty) 'bio': _bio.text.trim(),
        'onboardingStage': 'complete',
      });
      // Refreshing auth flips the router over to the main shell.
      await ref.read(authControllerProvider.notifier).refreshUser();
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: PageShell(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 34),
                Text('A little about you', style: text.displaySmall),
                const SizedBox(height: 11),
                Text(
                  'Just enough to introduce you. Your taste does the rest.',
                  style: text.bodyMedium?.copyWith(color: WaveColors.muted),
                ),
                const SizedBox(height: 30),
                TextField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(hintText: 'First name'),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 11),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _age,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(3),
                        ],
                        decoration: const InputDecoration(hintText: 'Age'),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _city,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(hintText: 'City'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 11),
                TextField(
                  controller: _bio,
                  maxLines: 3,
                  maxLength: 200,
                  decoration: const InputDecoration(
                    hintText: 'One line about you',
                    counterStyle: TextStyle(color: WaveColors.faint),
                  ),
                ),
                const SizedBox(height: 16),
                Text('LOOKING FOR',
                    style: text.labelSmall?.copyWith(
                      color: WaveColors.faint,
                      letterSpacing: 1.3,
                    )),
                const SizedBox(height: 10),
                Row(
                  children: [
                    for (final option in const [
                      ('dating', 'Dating'),
                      ('friends', 'Friends'),
                      ('both', 'Both'),
                    ])
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: _IntentChip(
                            label: option.$2,
                            selected: _intent == option.$1,
                            onTap: () => setState(() => _intent = option.$1),
                          ),
                        ),
                      ),
                  ],
                ),
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  Text(_error!, style: text.bodySmall?.copyWith(color: WaveColors.danger)),
                ],
                const SizedBox(height: 26),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child:
                              CircularProgressIndicator(strokeWidth: 2, color: WaveColors.ink),
                        )
                      : const Text('Continue'),
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _IntentChip extends StatelessWidget {
  const _IntentChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          color: selected ? WaveColors.music.withValues(alpha: 0.15) : WaveColors.surface,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: selected ? WaveColors.music : WaveColors.stroke,
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: selected ? WaveColors.music : WaveColors.muted,
          ),
        ),
      ),
    );
  }
}
