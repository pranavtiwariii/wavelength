import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../widgets/page_shell.dart';
import '../../widgets/score_badge.dart';
import '../../widgets/taste_dna_radar.dart';
import '../taste/taste_models.dart';
import 'discovery_controller.dart';
import 'discovery_models.dart';

/// Spec 3.5: the emotional core. Why you match, in concrete artifacts — plus
/// a toggle to look at what you *don't* share, which is often the better
/// conversation.
class CompatibilityScreen extends ConsumerStatefulWidget {
  const CompatibilityScreen({super.key, required this.userId});

  final String userId;

  @override
  ConsumerState<CompatibilityScreen> createState() => _CompatibilityScreenState();
}

class _CompatibilityScreenState extends ConsumerState<CompatibilityScreen> {
  bool _showDivergence = false;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(compatibilityProvider(widget.userId));

    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      body: SafeArea(
        child: async.when(
          loading: () => const Center(
            child: SizedBox(
              height: 22,
              width: 22,
              child: CircularProgressIndicator(strokeWidth: 2, color: WaveColors.muted),
            ),
          ),
          error: (err, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Text('$err',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: WaveColors.muted)),
            ),
          ),
          data: (card) => SingleChildScrollView(
            child: PageShell(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Header(card: card),
                  const SizedBox(height: 26),
                  _NarrativeBlock(userId: widget.userId),
                  const SizedBox(height: 26),
                  _DnaBlock(card: card),
                  const SizedBox(height: 26),
                  _ToggleRow(
                    showDivergence: _showDivergence,
                    onChanged: (v) => setState(() => _showDivergence = v),
                  ),
                  const SizedBox(height: 16),
                  if (_showDivergence)
                    _DivergenceBlock(card: card)
                  else
                    _OverlapBlock(card: card),
                  const SizedBox(height: 44),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.card});

  final CompatibilityCard card;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        ScoreBadge(score: card.overallScore, size: 82),
        const SizedBox(width: 18),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                card.user.age != null
                    ? '${card.user.displayName}, ${card.user.age}'
                    : card.user.displayName,
                style: text.headlineMedium,
              ),
              if (card.user.city != null) ...[
                const SizedBox(height: 4),
                Text(card.user.city!,
                    style: text.bodySmall?.copyWith(color: WaveColors.muted)),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  for (final domain in TasteDomain.values)
                    if (card.scoreFor(domain) != null)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _DomainPill(domain: domain, score: card.scoreFor(domain)!),
                      ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DomainPill extends StatelessWidget {
  const _DomainPill({required this.domain, required this.score});

  final TasteDomain domain;
  final int score;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: domain.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(domain.icon, size: 12, color: domain.color),
          const SizedBox(width: 5),
          Text('$score',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: domain.color)),
        ],
      ),
    );
  }
}

class _NarrativeBlock extends ConsumerWidget {
  const _NarrativeBlock({required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(narrativeProvider(userId));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: WaveColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: WaveColors.stroke),
      ),
      child: async.when(
        loading: () => const SizedBox(
          height: 46,
          child: Center(
            child: SizedBox(
              height: 16,
              width: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: WaveColors.faint),
            ),
          ),
        ),
        error: (_, _) => const Text(
          'No read on this one yet.',
          style: TextStyle(color: WaveColors.muted),
        ),
        data: (narrative) => Text(
          narrative,
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(height: 1.55, color: WaveColors.cream),
        ),
      ),
    );
  }
}

class _DnaBlock extends StatelessWidget {
  const _DnaBlock({required this.card});

  final CompatibilityCard card;

  @override
  Widget build(BuildContext context) {
    if (card.tasteDna.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel('TASTE DNA'),
        const SizedBox(height: 4),
        Center(
          child: TasteDnaRadar(
            you: card.yourTasteDna,
            them: card.tasteDna,
            themLabel: card.user.displayName,
          ),
        ),
      ],
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({required this.showDivergence, required this.onChanged});

  final bool showDivergence;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: WaveColors.surface,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: WaveColors.stroke),
      ),
      child: Row(
        children: [
          _ToggleTab(
            label: 'What you share',
            selected: !showDivergence,
            onTap: () => onChanged(false),
          ),
          _ToggleTab(
            label: 'Where you differ',
            selected: showDivergence,
            onTap: () => onChanged(true),
          ),
        ],
      ),
    );
  }
}

class _ToggleTab extends StatelessWidget {
  const _ToggleTab({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: selected ? WaveColors.surfaceHigh : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: selected ? WaveColors.cream : WaveColors.muted,
            ),
          ),
        ),
      ),
    );
  }
}

class _OverlapBlock extends StatelessWidget {
  const _OverlapBlock({required this.card});

  final CompatibilityCard card;

  @override
  Widget build(BuildContext context) {
    if (card.shared.isEmpty) {
      return const _EmptyNote(
        'Nothing in common yet. Add more favourites and this fills in.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final domain in TasteDomain.values)
          if (card.sharedIn(domain).isNotEmpty) ...[
            _DomainSection(domain: domain, items: card.sharedIn(domain)),
            const SizedBox(height: 14),
          ],
      ],
    );
  }
}

class _DomainSection extends StatelessWidget {
  const _DomainSection({required this.domain, required this.items});

  final TasteDomain domain;
  final List<Highlight> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: WaveColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: domain.color.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(domain.icon, size: 15, color: domain.color),
              const SizedBox(width: 8),
              Text(
                'Both of you',
                style: TextStyle(
                  fontSize: 12,
                  letterSpacing: 0.8,
                  fontWeight: FontWeight.w700,
                  color: domain.color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 11),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(item.label,
                  style: Theme.of(context).textTheme.bodyMedium),
            ),
        ],
      ),
    );
  }
}

/// Spec 4.6: differences framed as prompts, not as deficits.
class _DivergenceBlock extends StatelessWidget {
  const _DivergenceBlock({required this.card});

  final CompatibilityCard card;

  @override
  Widget build(BuildContext context) {
    if (card.divergences.isEmpty) {
      return const _EmptyNote('No standout differences — you two are close to aligned.');
    }

    final text = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final item in card.divergences)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(17),
            decoration: BoxDecoration(
              color: WaveColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: WaveColors.stroke),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(item.domain.icon, size: 14, color: item.domain.color),
                    const SizedBox(width: 7),
                    Text(
                      item.heldBy == card.user.id
                          ? '${card.user.displayName} loves'
                          : 'You love',
                      style: const TextStyle(fontSize: 12, color: WaveColors.muted),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                Text(item.label, style: text.titleSmall),
                const SizedBox(height: 7),
                Text(
                  item.heldBy == card.user.id
                      ? "You've never touched it. Ask them to make the case."
                      : "They've never touched it. See if you can sell it.",
                  style: text.bodySmall?.copyWith(color: WaveColors.faint),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          fontSize: 11.5,
          letterSpacing: 1.4,
          fontWeight: FontWeight.w700,
          color: WaveColors.faint,
        ),
      );
}

class _EmptyNote extends StatelessWidget {
  const _EmptyNote(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: WaveColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: WaveColors.stroke),
        ),
        child: Text(text, style: const TextStyle(color: WaveColors.muted, fontSize: 13.5)),
      );
}
