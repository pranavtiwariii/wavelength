import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_exception.dart';
import '../../core/theme.dart';
import '../../widgets/page_shell.dart';
import '../auth/auth_controller.dart';
import '../discovery/discovery_controller.dart';
import '../taste/taste_controller.dart';
import '../taste/taste_models.dart';

/// Add a person to the matching pool by hand.
///
/// The proposal's pilot plan calls for a curated set of synthetic profiles so
/// the engine has enough density to produce meaningful matches before organic
/// signups arrive. This is that, as a screen.
class CreateProfileScreen extends ConsumerStatefulWidget {
  const CreateProfileScreen({super.key});

  @override
  ConsumerState<CreateProfileScreen> createState() => _CreateProfileScreenState();
}

class _CreateProfileScreenState extends ConsumerState<CreateProfileScreen> {
  final _name = TextEditingController();
  final _age = TextEditingController();
  final _city = TextEditingController();
  final _bio = TextEditingController();

  String _gender = 'woman';
  String _intent = 'both';
  bool _autoReply = true;
  bool _saving = false;
  String? _error;

  final _picks = <TasteDomain, List<TasteItem>>{
    TasteDomain.music: [],
    TasteDomain.movie: [],
    TasteDomain.book: [],
  };

  @override
  void dispose() {
    _name.dispose();
    _age.dispose();
    _city.dispose();
    _bio.dispose();
    super.dispose();
  }

  int get _totalPicks => _picks.values.fold(0, (a, b) => a + b.length);

  bool get _valid {
    final age = int.tryParse(_age.text.trim());
    return _name.text.trim().isNotEmpty &&
        age != null &&
        age >= 18 &&
        age <= 120 &&
        _totalPicks > 0;
  }

  Future<void> _save() async {
    if (!_valid) {
      setState(() => _error =
          'Needs a name, an age (18+), and at least one favourite — without taste they can never match.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await ref.read(authRepositoryProvider).client.post('/profiles', body: {
        'name': _name.text.trim(),
        'age': int.parse(_age.text.trim()),
        'gender': _gender,
        'intent': _intent,
        'autoReply': _autoReply,
        if (_city.text.trim().isNotEmpty) 'city': _city.text.trim(),
        if (_bio.text.trim().isNotEmpty) 'bio': _bio.text.trim(),
        for (final entry in _picks.entries)
          if (entry.value.isNotEmpty)
            entry.key.id: entry.value.map((i) => i.toJson()).toList(),
      });

      // The new person changes the pool, so rebuild the queue.
      ref.invalidate(discoveryControllerProvider);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${_name.text.trim()} joined the pool.')),
      );
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickTaste(TasteDomain domain) async {
    final picked = await showModalBottomSheet<TasteItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TastePickerSheet(domain: domain),
    );
    if (picked == null) return;
    setState(() {
      final list = _picks[domain]!;
      if (!list.any((i) => i.key == picked.key)) list.add(picked);
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = Palette.of(context);
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Add a profile', style: text.titleMedium),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: PageShell(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'They join the matching pool straight away. A portrait is generated for them automatically.',
                  style: text.bodySmall?.copyWith(color: palette.muted, height: 1.45),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(hintText: 'Name'),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 10),
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
                    const SizedBox(width: 10),
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
                const SizedBox(height: 10),
                TextField(
                  controller: _bio,
                  maxLines: 2,
                  maxLength: 200,
                  decoration: InputDecoration(
                    hintText: 'One line about them',
                    counterStyle: TextStyle(color: palette.faint),
                  ),
                ),
                const SizedBox(height: 8),
                _ChipRow(
                  label: 'GENDER',
                  options: const [
                    ('woman', 'Woman'),
                    ('man', 'Man'),
                    ('nonbinary', 'Non-binary'),
                  ],
                  value: _gender,
                  onChanged: (v) => setState(() => _gender = v),
                ),
                const SizedBox(height: 16),
                _ChipRow(
                  label: 'HERE FOR',
                  options: const [
                    ('dating', 'Dating'),
                    ('friends', 'Friends'),
                    ('both', 'Both'),
                  ],
                  value: _intent,
                  onChanged: (v) => setState(() => _intent = v),
                ),
                const SizedBox(height: 20),
                Text('THEIR TASTE',
                    style: text.labelSmall
                        ?.copyWith(color: palette.faint, letterSpacing: 1.3)),
                const SizedBox(height: 10),
                for (final domain in TasteDomain.values) ...[
                  _TasteRow(
                    domain: domain,
                    items: _picks[domain]!,
                    onAdd: () => _pickTaste(domain),
                    onRemove: (key) => setState(
                        () => _picks[domain]!.removeWhere((i) => i.key == key)),
                  ),
                  const SizedBox(height: 8),
                ],
                const SizedBox(height: 12),
                Material(
                  color: palette.surface,
                  borderRadius: BorderRadius.circular(15),
                  child: SwitchListTile(
                    value: _autoReply,
                    onChanged: (v) => setState(() => _autoReply = v),
                    activeThumbColor: palette.music,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                      side: BorderSide(color: palette.stroke),
                    ),
                    title: Text('Replies to messages', style: text.titleSmall),
                    subtitle: Text(
                      'Answers once, using your shared taste. Useful for demos.',
                      style: text.bodySmall?.copyWith(color: palette.muted),
                    ),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  Text(_error!,
                      style: text.bodySmall?.copyWith(color: MateColors.danger)),
                ],
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Add to the pool'),
                ),
                const SizedBox(height: 34),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ChipRow extends StatelessWidget {
  const _ChipRow({
    required this.label,
    required this.options,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final List<(String, String)> options;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = Palette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: palette.faint, letterSpacing: 1.3)),
        const SizedBox(height: 9),
        Row(
          children: [
            for (final option in options)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 7),
                  child: SelectChip(
                    label: option.$2,
                    selected: value == option.$1,
                    onTap: () => onChanged(option.$1),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// Shared selectable chip — onboarding, filters and this screen all use it.
class SelectChip extends StatelessWidget {
  const SelectChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = Palette.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        decoration: BoxDecoration(
          color: selected ? palette.music.withValues(alpha: 0.15) : palette.surface,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: selected ? palette.music : palette.stroke),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            color: selected ? palette.music : palette.muted,
          ),
        ),
      ),
    );
  }
}

class _TasteRow extends StatelessWidget {
  const _TasteRow({
    required this.domain,
    required this.items,
    required this.onAdd,
    required this.onRemove,
  });

  final TasteDomain domain;
  final List<TasteItem> items;
  final VoidCallback onAdd;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    final palette = Palette.of(context);
    final color = palette.domain(domain.id);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: items.isEmpty ? palette.stroke : color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(domain.icon, size: 15, color: color),
              const SizedBox(width: 8),
              Expanded(child: Text(domain.label, style: Theme.of(context).textTheme.titleSmall)),
              GestureDetector(
                onTap: onAdd,
                child: Row(
                  children: [
                    Icon(Icons.add_rounded, size: 16, color: color),
                    const SizedBox(width: 4),
                    Text('Add', style: TextStyle(fontSize: 13, color: color)),
                  ],
                ),
              ),
            ],
          ),
          if (items.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final item in items)
                  Chip(
                    label: Text(item.label, style: const TextStyle(fontSize: 12.5)),
                    backgroundColor: color.withValues(alpha: 0.13),
                    side: BorderSide(color: color.withValues(alpha: 0.32)),
                    deleteIcon: const Icon(Icons.close_rounded, size: 14),
                    onDeleted: () => onRemove(item.key),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// A search sheet that reuses the same provider-backed search the Taste tab uses.
class _TastePickerSheet extends ConsumerStatefulWidget {
  const _TastePickerSheet({required this.domain});

  final TasteDomain domain;

  @override
  ConsumerState<_TastePickerSheet> createState() => _TastePickerSheetState();
}

class _TastePickerSheetState extends ConsumerState<_TastePickerSheet> {
  final _controller = TextEditingController();
  Timer? _debounce;
  List<TasteItem> _results = const [];
  bool _searching = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    if (value.trim().length < 2) {
      setState(() => _results = const []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      setState(() => _searching = true);
      try {
        final results =
            await ref.read(tasteRepositoryProvider).search(widget.domain, value.trim());
        if (mounted) setState(() => _results = results);
      } on ApiException {
        if (mounted) setState(() => _results = const []);
      } finally {
        if (mounted) setState(() => _searching = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = Palette.of(context);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        height: MediaQuery.sizeOf(context).height * 0.75,
        decoration: BoxDecoration(
          color: palette.ink,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: palette.stroke),
        ),
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
        child: Column(
          children: [
            Container(
              height: 4,
              width: 40,
              decoration: BoxDecoration(
                color: palette.stroke,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              autofocus: true,
              onChanged: _onChanged,
              decoration: InputDecoration(
                hintText: 'Search ${widget.domain.noun}…',
                prefixIcon: Icon(Icons.search_rounded, size: 19, color: palette.muted),
                suffixIcon: _searching
                    ? const Padding(
                        padding: EdgeInsets.all(14),
                        child: SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.separated(
                itemCount: _results.length,
                separatorBuilder: (_, _) => const SizedBox(height: 6),
                itemBuilder: (context, i) {
                  final item = _results[i];
                  return Material(
                    color: palette.surface,
                    borderRadius: BorderRadius.circular(13),
                    child: ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13),
                        side: BorderSide(color: palette.stroke),
                      ),
                      title: Text(item.label,
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: item.subtitle == null
                          ? null
                          : Text(item.subtitle!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: palette.muted)),
                      onTap: () => Navigator.of(context).pop(item),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
