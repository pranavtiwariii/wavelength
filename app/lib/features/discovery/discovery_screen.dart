import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_exception.dart';
import '../../core/theme.dart';
import '../auth/auth_controller.dart';
import '../../widgets/page_shell.dart';
import '../../widgets/score_badge.dart';
import 'discovery_controller.dart';
import 'discovery_models.dart';
import 'filters.dart';

class DiscoveryScreen extends ConsumerWidget {
  const DiscoveryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = ref.watch(discoveryControllerProvider);

    return Scaffold(
      body: SafeArea(
        child: PageShell(
          maxWidth: 480,
          child: Column(
            children: [
              const _DiscoveryHeader(),
              Expanded(
                child: feed.when(
                  loading: () => Center(
                    child: SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Palette.of(context).muted),
                    ),
                  ),
                  error: (err, _) => _Empty(
                    title: "Couldn't load anyone",
                    body: '$err',
                    onRetry: () => ref.read(discoveryControllerProvider.notifier).refresh(),
                  ),
                  data: (cards) =>
                      cards.isEmpty ? const _ExhaustedPool() : _CardStack(cards: cards),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DiscoveryHeader extends ConsumerWidget {
  const _DiscoveryHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = Palette.of(context);
    final filters = ref.watch(discoveryFiltersProvider);

    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Discover', style: Theme.of(context).textTheme.headlineMedium),
          Semantics(
            button: true,
            label: 'Filters',
            child: Material(
              color: filters.isDefault ? palette.surface : palette.music.withValues(alpha: 0.16),
              shape: CircleBorder(
                side: BorderSide(
                  color: filters.isDefault ? palette.stroke : palette.music,
                ),
              ),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => showModalBottomSheet<bool>(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => const FiltersSheet(),
                ),
                child: SizedBox(
                  height: 42,
                  width: 42,
                  child: Icon(
                    Icons.tune_rounded,
                    size: 19,
                    color: filters.isDefault ? palette.muted : palette.music,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A draggable stack: the top card follows the finger and rotates slightly,
/// the next card sits behind it slightly scaled down.
class _CardStack extends ConsumerStatefulWidget {
  const _CardStack({required this.cards});

  final List<CompatibilityCard> cards;

  @override
  ConsumerState<_CardStack> createState() => _CardStackState();
}

class _CardStackState extends ConsumerState<_CardStack> {
  Offset _drag = Offset.zero;
  bool _settling = false;

  double get _progress => (_drag.dx / 140).clamp(-1.0, 1.0);

  Future<void> _commit(CompatibilityCard card, bool like) async {
    setState(() {
      _settling = true;
      _drag = Offset(like ? 600 : -600, _drag.dy);
    });
    await Future<void>.delayed(const Duration(milliseconds: 180));
    if (!mounted) return;
    setState(() {
      _drag = Offset.zero;
      _settling = false;
    });

    final outcome =
        await ref.read(discoveryControllerProvider.notifier).swipe(card, like: like);
    if (!mounted) return;

    if (outcome.matchId != null) {
      _celebrate(card);
    } else if (outcome.requested) {
      // Connections are opt-in: the like is a request until they accept.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Request sent to ${card.user.displayName}')),
      );
    }
  }

  void _celebrate(CompatibilityCard card) {
    showDialog<void>(
      context: context,
      builder: (context) => _MatchDialog(card: card),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cards = widget.cards;
    final top = cards.first;
    final next = cards.length > 1 ? cards[1] : null;

    return Column(
      children: [
        Expanded(
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (next != null)
                Transform.scale(
                  scale: 0.94 + 0.06 * _progress.abs(),
                  child: Opacity(
                    opacity: 0.55 + 0.45 * _progress.abs(),
                    child: _Card(card: next, onTap: () {}),
                  ),
                ),
              GestureDetector(
                onPanUpdate: (d) {
                  if (_settling) return;
                  setState(() => _drag += d.delta);
                },
                onPanEnd: (_) {
                  if (_settling) return;
                  if (_progress.abs() >= 0.75) {
                    _commit(top, _progress > 0);
                  } else {
                    setState(() => _drag = Offset.zero);
                  }
                },
                child: AnimatedContainer(
                  duration: Duration(milliseconds: _settling ? 180 : 0),
                  curve: Curves.easeOut,
                  transform: Matrix4.identity()
                    ..translateByDouble(_drag.dx, _drag.dy * 0.35, 0, 1)
                    ..rotateZ(_progress * 0.12),
                  transformAlignment: Alignment.center,
                  child: Stack(
                    alignment: Alignment.topCenter,
                    children: [
                      _Card(
                        card: top,
                        onTap: () => context.push('/compatibility/${top.user.id}'),
                      ),
                      if (_progress.abs() > 0.08) _SwipeStamp(progress: _progress),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _ActionButton(
              icon: Icons.close_rounded,
              color: MateColors.pass,
              onTap: () => _commit(top, false),
              semanticLabel: 'Pass',
            ),
            const SizedBox(width: 22),
            _ActionButton(
              icon: Icons.bar_chart_rounded,
              color: Palette.of(context).book,
              size: 48,
              onTap: () => context.push('/compatibility/${top.user.id}'),
              semanticLabel: 'See why you match',
            ),
            const SizedBox(width: 22),
            _ActionButton(
              icon: Icons.favorite_rounded,
              color: MateColors.like,
              onTap: () => _commit(top, true),
              semanticLabel: 'Like',
            ),
          ],
        ),
        const SizedBox(height: 18),
      ],
    );
  }
}

class _SwipeStamp extends StatelessWidget {
  const _SwipeStamp({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final like = progress > 0;
    final color = like ? MateColors.like : MateColors.danger;

    return Align(
      alignment: like ? Alignment.topLeft : Alignment.topRight,
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Opacity(
          opacity: progress.abs().clamp(0.0, 1.0),
          child: Transform.rotate(
            angle: like ? -0.22 : 0.22,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                border: Border.all(color: color, width: 2.5),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Text(
                like ? 'YES' : 'NOPE',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w800,
                  fontSize: 19,
                  letterSpacing: 1.5,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.color,
    required this.onTap,
    required this.semanticLabel,
    this.size = 58,
  });

  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final String semanticLabel;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: Material(
        color: Palette.of(context).surface,
        shape: CircleBorder(side: BorderSide(color: Palette.of(context).stroke)),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: SizedBox(
            height: size,
            width: size,
            child: Icon(icon, color: color, size: size * 0.42),
          ),
        ),
      ),
    );
  }
}

/// The discovery card: artwork collage, name, score, and the specific shared
/// taste that earned the score.
class _Card extends StatelessWidget {
  const _Card({required this.card, required this.onTap});

  final CompatibilityCard card;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final user = card.user;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Palette.of(context).surface,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: Palette.of(context).stroke),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _CardArt(card: card)),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.age != null
                                  ? '${user.displayName}, ${user.age}'
                                  : user.displayName,
                              style: text.titleLarge,
                            ),
                            if (user.city != null) ...[
                              const SizedBox(height: 3),
                              Text(user.city!,
                                  style: text.bodySmall?.copyWith(color: Palette.of(context).muted)),
                            ],
                          ],
                        ),
                      ),
                      ScoreBadge(score: card.overallScore, size: 58),
                    ],
                  ),
                  if (user.bio != null && user.bio!.isNotEmpty) ...[
                    const SizedBox(height: 11),
                    Text(
                      user.bio!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodySmall?.copyWith(color: Palette.of(context).muted),
                    ),
                  ],
                  const SizedBox(height: 14),
                  _SharedChips(shared: card.shared),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A soft gradient built from the domain accents, with the person's initial
/// over it. Real photos replace this once photo upload lands.
class _CardArt extends StatelessWidget {
  const _CardArt({required this.card});

  final CompatibilityCard card;

  @override
  Widget build(BuildContext context) {
    final user = card.user;
    if (user.photoUrl == null) return _GradientArt(card: card);

    // The portrait sits on the seeded gradient, so a slow or failed image
    // still leaves a composed card rather than a grey box.
    return Stack(
      fit: StackFit.expand,
      children: [
        _GradientArt(card: card),
        Image.network(
          user.photoUrl!,
          fit: BoxFit.cover,
          width: double.infinity,
          errorBuilder: (_, _, _) => const SizedBox.shrink(),
          frameBuilder: (context, child, frame, wasSync) {
            if (wasSync || frame != null) {
              return AnimatedOpacity(
                opacity: 1,
                duration: const Duration(milliseconds: 260),
                child: child,
              );
            }
            return const SizedBox.shrink();
          },
        ),
      ],
    );
  }
}

class _GradientArt extends StatelessWidget {
  const _GradientArt({required this.card});

  final CompatibilityCard card;

  @override
  Widget build(BuildContext context) {
    // Seed the gradient from the user id so a given person always looks the
    // same, rather than reshuffling on every rebuild.
    final seed = card.user.id.codeUnits.fold<int>(0, (a, b) => a + b);
    final rotation = (seed % 360) / 360 * 2 * math.pi;
    final palette = [Palette.of(context).music, Palette.of(context).movie, Palette.of(context).book];
    final a = palette[seed % 3];
    final b = palette[(seed + 1) % 3];

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [a.withValues(alpha: 0.42), b.withValues(alpha: 0.22), Palette.of(context).surface],
          begin: Alignment(math.cos(rotation), math.sin(rotation)),
          end: Alignment(-math.cos(rotation), -math.sin(rotation)),
        ),
      ),
      child: Center(
        child: Text(
          card.user.displayName.characters.first.toUpperCase(),
          style: TextStyle(
            fontSize: 84,
            fontWeight: FontWeight.w700,
            color: Palette.of(context).text.withValues(alpha: 0.32),
          ),
        ),
      ),
    );
  }
}

class _SharedChips extends StatelessWidget {
  const _SharedChips({required this.shared});

  final List<Highlight> shared;

  @override
  Widget build(BuildContext context) {
    if (shared.isEmpty) {
      return Text(
        'No shared favourites yet — which might be the interesting part.',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Palette.of(context).faint),
      );
    }

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final item in shared.take(3))
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: item.domain.color.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: item.domain.color.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(item.domain.icon, size: 12, color: item.domain.color),
                const SizedBox(width: 6),
                Text(
                  item.label,
                  style: TextStyle(fontSize: 12.5, color: item.domain.color),
                ),
              ],
            ),
          ),
        if (shared.length > 3)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Palette.of(context).stroke),
            ),
            child: Text('+${shared.length - 3} more',
                style: TextStyle(fontSize: 12.5, color: Palette.of(context).muted)),
          ),
      ],
    );
  }
}

class _MatchDialog extends StatelessWidget {
  const _MatchDialog({required this.card});

  final CompatibilityCard card;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Dialog(
      backgroundColor: Palette.of(context).surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(26),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ScoreBadge(score: card.overallScore, size: 84),
            const SizedBox(height: 18),
            Text("It's a match", style: text.titleLarge, textAlign: TextAlign.center),
            const SizedBox(height: 9),
            Text(
              '${card.user.displayName} liked you back.',
              style: text.bodyMedium?.copyWith(color: Palette.of(context).muted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 22),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop();
                context.go('/matches');
              },
              child: const Text('Say something'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Keep swiping', style: TextStyle(color: Palette.of(context).muted)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shown once the queue is worked through. Refresh here has to actually do
/// something — plain refetching returns the same empty list — so it clears
/// past passes, and offers to generate more people if that isn't enough.
class _ExhaustedPool extends ConsumerStatefulWidget {
  const _ExhaustedPool();

  @override
  ConsumerState<_ExhaustedPool> createState() => _ExhaustedPoolState();
}

class _ExhaustedPoolState extends ConsumerState<_ExhaustedPool> {
  bool _busy = false;

  Future<void> _run(Future<String> Function() action) async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      messenger.showSnackBar(SnackBar(content: Text(await action())));
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = Palette.of(context);
    final text = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 26),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.done_all_rounded, size: 34, color: palette.faint),
            const SizedBox(height: 16),
            Text("You've seen everyone", style: text.titleLarge, textAlign: TextAlign.center),
            const SizedBox(height: 10),
            Text(
              'Take another pass at the people you skipped, or bring in new ones.',
              textAlign: TextAlign.center,
              style: text.bodySmall?.copyWith(color: palette.muted),
            ),
            const SizedBox(height: 22),
            if (_busy)
              const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2))
            else ...[
              FilledButton(
                onPressed: () => _run(() async {
                  final restored =
                      await ref.read(discoveryControllerProvider.notifier).recycle();
                  return restored == 0
                      ? 'Nobody left to bring back — try adding new people.'
                      : 'Brought back $restored ${restored == 1 ? "profile" : "profiles"}';
                }),
                child: const Text('See skipped people again'),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: () => _run(() async {
                  final result =
                      await ref.read(authRepositoryProvider).client.post('/me/pool/expand');
                  ref.invalidate(discoveryControllerProvider);
                  return 'Added ${result["created"]} new people';
                }),
                child: const Text('Find new people'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.title, required this.body, required this.onRetry});

  final String title;
  final String body;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 26),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: text.titleLarge, textAlign: TextAlign.center),
            const SizedBox(height: 10),
            Text(
              body,
              textAlign: TextAlign.center,
              style: text.bodySmall?.copyWith(color: Palette.of(context).muted),
            ),
            const SizedBox(height: 20),
            OutlinedButton(onPressed: onRetry, child: const Text('Refresh')),
          ],
        ),
      ),
    );
  }
}
