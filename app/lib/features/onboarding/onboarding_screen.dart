import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_exception.dart';
import '../../core/theme.dart';
import '../../widgets/page_shell.dart';
import '../auth/auth_controller.dart';
import '../profiles/create_profile_screen.dart' show SelectChip;

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
  String _gender = 'woman';
  String _seeking = 'everyone';
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
        'gender': _gender,
        'intent': _intent,
        // Orientation only narrows the dating pool. Friends mode deliberately
        // shows everyone, so we don't ask and don't filter.
        'seeking': _intent == 'dating' ? _seeking : 'everyone',
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
                  style: text.bodyMedium?.copyWith(color: Palette.of(context).muted),
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
                  decoration: InputDecoration(
                    hintText: 'One line about you',
                    counterStyle: TextStyle(color: Palette.of(context).faint),
                  ),
                ),
                const SizedBox(height: 16),
                const _Label('YOU ARE'),
                const SizedBox(height: 10),
                _ChoiceRow(
                  options: const [
                    ('woman', 'Woman'),
                    ('man', 'Man'),
                    ('nonbinary', 'Non-binary'),
                  ],
                  value: _gender,
                  onChanged: (v) => setState(() => _gender = v),
                ),
                const SizedBox(height: 18),
                const _Label('HERE FOR'),
                const SizedBox(height: 10),
                _ChoiceRow(
                  options: const [
                    ('dating', 'Dating'),
                    ('friends', 'Friends'),
                    ('both', 'Both'),
                  ],
                  value: _intent,
                  onChanged: (v) => setState(() => _intent = v),
                ),
                // Orientation narrows the dating pool only. Someone here to
                // make friends sees everyone, so we never ask.
                AnimatedSize(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                  alignment: Alignment.topCenter,
                  child: _intent != 'dating'
                      ? const SizedBox(width: double.infinity)
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 18),
                            const _Label('SHOW ME'),
                            const SizedBox(height: 10),
                            _ChoiceRow(
                              options: const [
                                ('women', 'Women'),
                                ('men', 'Men'),
                                ('everyone', 'Everyone'),
                              ],
                              value: _seeking,
                              onChanged: (v) => setState(() => _seeking = v),
                            ),
                          ],
                        ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  Text(_error!, style: text.bodySmall?.copyWith(color: MateColors.danger)),
                ],
                const SizedBox(height: 26),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? SizedBox(
                          height: 20,
                          width: 20,
                          child:
                              CircularProgressIndicator(strokeWidth: 2, color: Palette.of(context).ink),
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

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Palette.of(context).faint,
              letterSpacing: 1.3,
            ),
      );
}


class _ChoiceRow extends StatelessWidget {
  const _ChoiceRow({
    required this.options,
    required this.value,
    required this.onChanged,
  });

  final List<(String, String)> options;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final option in options)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: SelectChip(
                label: option.$2,
                selected: value == option.$1,
                onTap: () => onChanged(option.$1),
              ),
            ),
          ),
      ],
    );
  }
}
