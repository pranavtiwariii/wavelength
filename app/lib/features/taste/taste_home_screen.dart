import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../widgets/page_shell.dart';
import '../auth/auth_controller.dart';
import 'taste_controller.dart';
import 'taste_models.dart';

/// The post-sign-in home: build your taste profile. Each domain is a real
/// destination, not a decorative tile.
class TasteHomeScreen extends ConsumerWidget {
  const TasteHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final authState = ref.watch(authControllerProvider).value;
    final user = authState is SignedIn ? authState.user : null;
    final tasteAsync = ref.watch(tasteControllerProvider);

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          color: WaveColors.music,
          backgroundColor: WaveColors.surface,
          onRefresh: () => ref.read(tasteControllerProvider.notifier).refresh(),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: PageShell(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 28),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Hey ${user?.displayName ?? 'there'}',
                              style: text.bodyMedium?.copyWith(color: WaveColors.muted),
                            ),
                            const SizedBox(height: 6),
                            Text('Your taste profile', style: text.headlineMedium),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Sign out',
                        onPressed: () => ref.read(authControllerProvider.notifier).signOut(),
                        icon: const Icon(Icons.logout_rounded,
                            size: 20, color: WaveColors.muted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 26),
                  tasteAsync.when(
                    loading: () => const _LoadingBlock(),
                    error: (err, _) => _ErrorBlock(
                      message: '$err',
                      onRetry: () => ref.read(tasteControllerProvider.notifier).refresh(),
                    ),
                    data: (profile) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _CompletenessCard(profile: profile),
                        const SizedBox(height: 22),
                        Text('SOURCES', style: text.labelSmall?.copyWith(
                          color: WaveColors.muted,
                          letterSpacing: 1.4,
                          fontWeight: FontWeight.w600,
                        )),
                        const SizedBox(height: 12),
                        for (final domain in TasteDomain.values) ...[
                          _DomainRow(
                            domain: domain,
                            taste: profile[domain],
                            onTap: () => context.push('/taste/${domain.id}'),
                          ),
                          const SizedBox(height: 10),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CompletenessCard extends StatelessWidget {
  const _CompletenessCard({required this.profile});

  final TasteProfile profile;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final percent = profile.completeness;
    final done = percent >= 100;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: WaveColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: WaveColors.surfaceHigh),
      ),
      child: Row(
        children: [
          _ProgressRing(value: percent / 100),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  done ? 'Ready to match' : '$percent% complete',
                  style: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 5),
                Text(
                  done
                      ? 'Your profile has enough signal to find good matches.'
                      : 'Add a few favourites in each area — the more specific, the better the match.',
                  style: text.bodySmall?.copyWith(color: WaveColors.muted, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A small three-segment ring — one arc per domain — so the meter itself hints
/// that the profile is made of three parts.
class _ProgressRing extends StatelessWidget {
  const _ProgressRing({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      width: 54,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            height: 54,
            width: 54,
            child: CircularProgressIndicator(
              value: value.clamp(0.0, 1.0),
              strokeWidth: 4,
              strokeCap: StrokeCap.round,
              backgroundColor: WaveColors.surfaceHigh,
              valueColor: const AlwaysStoppedAnimation(WaveColors.music),
            ),
          ),
          Text(
            '${(value * 100).round()}',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _DomainRow extends StatelessWidget {
  const _DomainRow({required this.domain, required this.taste, required this.onTap});

  final TasteDomain domain;
  final DomainTaste taste;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final count = taste.items.length;

    final String status;
    if (!taste.available) {
      status = 'Needs setup';
    } else if (count == 0) {
      status = 'Add your favourite ${domain.noun}';
    } else if (taste.isComplete) {
      status = '$count ${domain.noun} · looking good';
    } else {
      status = '$count of ${taste.target} ${domain.noun}';
    }

    return Semantics(
      button: true,
      label: '${domain.label}. $status',
      child: Material(
        color: WaveColors.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: count > 0 ? domain.color.withValues(alpha: 0.35) : WaveColors.surfaceHigh,
              ),
            ),
            child: Row(
              children: [
                Container(
                  height: 42,
                  width: 42,
                  decoration: BoxDecoration(
                    color: domain.color.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(domain.icon, color: domain.color, size: 21),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(domain.label,
                          style: text.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 3),
                      Text(
                        status,
                        style: text.bodySmall?.copyWith(
                          color: taste.available ? WaveColors.muted : WaveColors.movie,
                        ),
                      ),
                      if (taste.available && count > 0) ...[
                        const SizedBox(height: 9),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            value: taste.progress,
                            minHeight: 3,
                            backgroundColor: WaveColors.surfaceHigh,
                            valueColor: AlwaysStoppedAnimation(domain.color),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right_rounded, color: WaveColors.muted, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LoadingBlock extends StatelessWidget {
  const _LoadingBlock();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(vertical: 60),
        child: Center(
          child: SizedBox(
            height: 22,
            width: 22,
            child: CircularProgressIndicator(strokeWidth: 2, color: WaveColors.muted),
          ),
        ),
      );
}

class _ErrorBlock extends StatelessWidget {
  const _ErrorBlock({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: WaveColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Couldn't load your taste profile",
              style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Text(message,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: WaveColors.muted)),
          const SizedBox(height: 14),
          OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    );
  }
}
