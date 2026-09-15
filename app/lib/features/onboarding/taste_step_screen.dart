import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_exception.dart';
import '../../core/theme.dart';
import '../../widgets/entrance.dart';
import '../../widgets/page_shell.dart';
import '../auth/auth_controller.dart';
import '../discovery/discovery_controller.dart';
import '../graph/graph_controller.dart';
import '../taste/taste_controller.dart';
import '../taste/taste_models.dart';

/// Second onboarding step: pick taste before entering the app.
///
/// This exists because compatibility needs BOTH sides to have taste — a user
/// who reaches Discover empty sees 0% against everyone, which reads as broken.
/// Picks are tap-to-select from what the pool already likes, so the very first
/// Discover screen has real overlap in it.
class TasteStepScreen extends ConsumerStatefulWidget {
  const TasteStepScreen({super.key});

  @override
  ConsumerState<TasteStepScreen> createState() => _TasteStepScreenState();
}

class _TasteStepScreenState extends ConsumerState<TasteStepScreen> {
  final _selected = <TasteDomain, List<TasteItem>>{
    TasteDomain.music: [],
    TasteDomain.movie: [],
    TasteDomain.book: [],
  };
  final _starters = <TasteDomain, List<TasteItem>>{};

  TasteDomain _domain = TasteDomain.music;
  bool _loading = true;
  bool _saving = false;
  String? _error;
  String _progress = '';

  static const _minimum = 3;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final repo = ref.read(tasteRepositoryProvider);
      for (final domain in TasteDomain.values) {
        _starters[domain] = await repo.starters(domain);
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  int get _total => _selected.values.fold(0, (a, b) => a + b.length);

  void _toggle(TasteItem item) {
    setState(() {
      final list = _selected[_domain]!;
      final existing = list.indexWhere((i) => i.key == item.key);
      existing >= 0 ? list.removeAt(existing) : list.add(item);
    });
  }

  Future<void> _finish() async {
    if (_total < _minimum) {
      setState(() => _error = 'Pick at least $_minimum things so we can find your people.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
      _progress = 'Saving your taste…';
    });

    try {
      final repo = ref.read(tasteRepositoryProvider);
      for (final entry in _selected.entries) {
        for (final item in entry.value) {
          await repo.add(entry.key, item);
        }
      }

      // Build a pool shaped by what was just picked, so Discover opens with
      // real matches rather than an empty queue of strangers at 0%.
      setState(() => _progress = 'Finding people on your wavelength…');
      await ref.read(authRepositoryProvider).client.post('/me/bootstrap');

      await ref.read(authRepositoryProvider).client.patch('/me', body: {
        'onboardingStage': 'complete',
      });

      ref.invalidate(tasteControllerProvider);
      ref.invalidate(discoveryControllerProvider);
      ref.invalidate(matchesControllerProvider);
      ref.invalidate(requestsControllerProvider);
      ref.invalidate(communitiesControllerProvider);
      ref.invalidate(dropsControllerProvider);

      await ref.read(authControllerProvider.notifier).refreshUser();
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = Palette.of(context);
    final text = Theme.of(context).textTheme;
    final items = _starters[_domain] ?? const <TasteItem>[];
    final chosen = _selected[_domain]!;

    if (_saving) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                  height: 26, width: 26, child: CircularProgressIndicator(strokeWidth: 2)),
              const SizedBox(height: 20),
              Text(_progress, style: text.bodyMedium?.copyWith(color: palette.muted)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: PageShell(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 26),
              Text('What are you into?', style: text.displaySmall),
              const SizedBox(height: 10),
              Text(
                'Tap anything you love. This is what we match on — pick at least $_minimum.',
                style: text.bodyMedium?.copyWith(color: palette.muted),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  for (final domain in TasteDomain.values)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 7),
                        child: _DomainTab(
                          domain: domain,
                          count: _selected[domain]!.length,
                          selected: _domain == domain,
                          onTap: () => setState(() => _domain = domain),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _loading
                    ? const Center(
                        child: SizedBox(
                            height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2)))
                    : items.isEmpty
                        ? Center(
                            child: Text('Nothing to show yet.',
                                style: text.bodySmall?.copyWith(color: palette.muted)))
                        : SingleChildScrollView(
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (var i = 0; i < items.length; i++)
                                  Entrance(
                                    delay: Duration(milliseconds: (i.clamp(0, 12)) * 28),
                                    offset: 8,
                                    child: _TasteChip(
                                      item: items[i],
                                      domain: _domain,
                                      selected: chosen.any((c) => c.key == items[i].key),
                                      onTap: () => _toggle(items[i]),
                                    ),
                                  ),
                              ],
                            ),
                          ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!, style: text.bodySmall?.copyWith(color: MateColors.danger)),
              ],
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _finish,
                child: Text(_total == 0 ? 'Pick a few to continue' : 'Continue with $_total'),
              ),
              const SizedBox(height: 22),
            ],
          ),
        ),
      ),
    );
  }
}

class _DomainTab extends StatelessWidget {
  const _DomainTab({
    required this.domain,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final TasteDomain domain;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = Palette.of(context);
    final accent = palette.domain(domain.id);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 170),
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: selected ? accent.withValues(alpha: 0.15) : palette.surface,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: selected ? accent : palette.stroke),
        ),
        child: Column(
          children: [
            Icon(domain.icon, size: 17, color: selected ? accent : palette.muted),
            const SizedBox(height: 5),
            Text(
              count == 0 ? domain.label : '${domain.label} · $count',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: selected ? accent : palette.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TasteChip extends StatelessWidget {
  const _TasteChip({
    required this.item,
    required this.domain,
    required this.selected,
    required this.onTap,
  });

  final TasteItem item;
  final TasteDomain domain;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = Palette.of(context);
    final accent = palette.domain(domain.id);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: selected ? accent.withValues(alpha: 0.18) : palette.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: selected ? accent : palette.stroke),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) ...[
              Icon(Icons.check_rounded, size: 15, color: accent),
              const SizedBox(width: 6),
            ],
            Text(
              item.label,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: selected ? accent : palette.text,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
