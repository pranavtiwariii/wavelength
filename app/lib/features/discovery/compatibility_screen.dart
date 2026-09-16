import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../widgets/page_shell.dart';
import '../../widgets/score_badge.dart';
import '../../widgets/entrance.dart';
import '../../widgets/taste_dna_radar.dart';
import '../../core/api/api_exception.dart';
import '../auth/auth_controller.dart';
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
          loading: () => Center(
            child: SizedBox(
              height: 22,
              width: 22,
              child: CircularProgressIndicator(strokeWidth: 2, color: Palette.of(context).muted),
            ),
          ),
          error: (err, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Text('$err',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Palette.of(context).muted)),
            ),
          ),
          data: (card) => SingleChildScrollView(
            child: PageShell(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Entrance(child: _Header(card: card)),
                  const SizedBox(height: 26),
                  Entrance(
                    delay: const Duration(milliseconds: 80),
                    child: _NarrativeBlock(userId: widget.userId),
                  ),
                  const SizedBox(height: 12),
                  Entrance(
                    delay: const Duration(milliseconds: 120),
                    child: _ExplanationRating(userId: widget.userId),
                  ),
                  const SizedBox(height: 26),
                  Entrance(
                    delay: const Duration(milliseconds: 160),
                    child: _DnaBlock(card: card),
                  ),
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
                    style: text.bodySmall?.copyWith(color: Palette.of(context).muted)),
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
        color: Palette.of(context).surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Palette.of(context).stroke),
      ),
      child: async.when(
        loading: () => SizedBox(
          height: 46,
          child: Center(
            child: SizedBox(
              height: 16,
              width: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: Palette.of(context).faint),
            ),
          ),
        ),
        error: (_, _) => Text(
          'No read on this one yet.',
          style: TextStyle(color: Palette.of(context).muted),
        ),
        data: (narrative) => Text(
          narrative,
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(height: 1.55, color: Palette.of(context).text),
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
        color: Palette.of(context).surface,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: Palette.of(context).stroke),
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
            color: selected ? Palette.of(context).surfaceHigh : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: selected ? Palette.of(context).text : Palette.of(context).muted,
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
        color: Palette.of(context).surface,
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
              color: Palette.of(context).surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Palette.of(context).stroke),
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
                      style: TextStyle(fontSize: 12, color: Palette.of(context).muted),
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
                  style: text.bodySmall?.copyWith(color: Palette.of(context).faint),
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
        style: TextStyle(
          fontSize: 11.5,
          letterSpacing: 1.4,
          fontWeight: FontWeight.w700,
          color: Palette.of(context).faint,
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
          color: Palette.of(context).surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Palette.of(context).stroke),
        ),
        child: Text(text, style: TextStyle(color: Palette.of(context).muted, fontSize: 13.5)),
      );
}


/// Proposal 6.2: explainability satisfaction. Asking here, right under the
/// explanation, is the only place the rating means anything — and it's the one
/// evaluation metric with no data behind it otherwise.
class _ExplanationRating extends ConsumerStatefulWidget {
  const _ExplanationRating({required this.userId});

  final String userId;

  @override
  ConsumerState<_ExplanationRating> createState() => _ExplanationRatingState();
}

class _ExplanationRatingState extends ConsumerState<_ExplanationRating> {
  int? _rating;
  bool _sent = false;

  Future<void> _rate(int value) async {
    setState(() => _rating = value);
    try {
      await ref
          .read(authRepositoryProvider)
          .client
          .post('/compatibility/${widget.userId}/rate', body: {'rating': value});
      if (mounted) setState(() => _sent = true);
    } on ApiException {
      // A rating is optional feedback; failing to record it changes nothing
      // for the reader, so don't interrupt them with an error.
      if (mounted) setState(() => _sent = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = Palette.of(context);
    final text = Theme.of(context).textTheme;

    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      child: _sent
          ? Row(
              children: [
                Icon(Icons.check_rounded, size: 15, color: palette.music),
                const SizedBox(width: 7),
                Text('Thanks — that helps us tune the matching.',
                    style: text.bodySmall?.copyWith(color: palette.muted)),
              ],
            )
          : Row(
              children: [
                Expanded(
                  child: Text('Did that explain the match?',
                      style: text.bodySmall?.copyWith(color: palette.muted)),
                ),
                for (var i = 1; i <= 5; i++)
                  GestureDetector(
                    onTap: () => _rate(i),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: Icon(
                        (_rating ?? 0) >= i
                            ? Icons.star_rounded
                            : Icons.star_border_rounded,
                        size: 21,
                        color: (_rating ?? 0) >= i ? palette.music : palette.faint,
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
