import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../widgets/page_shell.dart';
import '../../widgets/score_badge.dart';
import '../discovery/discovery_controller.dart';
import '../discovery/discovery_models.dart';

class MatchesScreen extends ConsumerWidget {
  const MatchesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(matchesControllerProvider);
    final text = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          color: WaveColors.music,
          backgroundColor: WaveColors.surface,
          onRefresh: () => ref.read(matchesControllerProvider.notifier).refresh(),
          child: PageShell(
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 14, bottom: 18),
                    child: Text('Matches', style: text.headlineMedium),
                  ),
                ),
                async.when(
                  loading: () => const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(strokeWidth: 2, color: WaveColors.muted),
                      ),
                    ),
                  ),
                  error: (err, _) => SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Text('$err', style: const TextStyle(color: WaveColors.muted)),
                    ),
                  ),
                  data: (matches) => matches.isEmpty
                      ? const SliverFillRemaining(
                          hasScrollBody: false,
                          child: _NoMatches(),
                        )
                      : SliverList.separated(
                          itemCount: matches.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 9),
                          itemBuilder: (context, i) => _MatchRow(match: matches[i]),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NoMatches extends StatelessWidget {
  const _NoMatches();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('No matches yet', style: text.titleLarge),
            const SizedBox(height: 9),
            Text(
              'When someone you like likes you back, the conversation opens here.',
              textAlign: TextAlign.center,
              style: text.bodySmall?.copyWith(color: WaveColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}

class _MatchRow extends StatelessWidget {
  const _MatchRow({required this.match});

  final MatchSummary match;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Material(
      color: WaveColors.surface,
      borderRadius: BorderRadius.circular(17),
      child: InkWell(
        borderRadius: BorderRadius.circular(17),
        onTap: () => context.push('/chat/${match.matchId}', extra: match),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(17),
            border: Border.all(color: WaveColors.stroke),
          ),
          child: Row(
            children: [
              ScoreBadge(score: match.overallScore, size: 50, showLabel: false),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(match.user.displayName, style: text.titleSmall),
                        if (match.unread) ...[
                          const SizedBox(width: 7),
                          Container(
                            height: 7,
                            width: 7,
                            decoration: const BoxDecoration(
                              color: WaveColors.music,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      match.lastMessage ?? 'Say something first',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodySmall?.copyWith(
                        color: match.lastMessage == null ? WaveColors.faint : WaveColors.muted,
                        fontStyle: match.lastMessage == null ? FontStyle.italic : FontStyle.normal,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: WaveColors.faint, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
