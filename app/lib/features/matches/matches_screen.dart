import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../widgets/page_shell.dart';
import '../../widgets/score_badge.dart';
import '../../widgets/entrance.dart';
import '../discovery/discovery_controller.dart';
import '../discovery/discovery_models.dart';
import '../graph/graph_controller.dart';

class MatchesScreen extends ConsumerWidget {
  const MatchesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(matchesControllerProvider);
    final text = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          color: Palette.of(context).music,
          backgroundColor: Palette.of(context).surface,
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
                const SliverToBoxAdapter(child: _RequestsBanner()),
                async.when(
                  loading: () => SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Palette.of(context).muted),
                      ),
                    ),
                  ),
                  error: (err, _) => SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Text('$err', style: TextStyle(color: Palette.of(context).muted)),
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
                          itemBuilder: (context, i) => Entrance(
                            delay: Duration(milliseconds: i * 55),
                            child: _MatchRow(match: matches[i]),
                          ),
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
              style: text.bodySmall?.copyWith(color: Palette.of(context).muted),
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
      color: Palette.of(context).surface,
      borderRadius: BorderRadius.circular(17),
      child: InkWell(
        borderRadius: BorderRadius.circular(17),
        onTap: () => context.push('/chat/${match.matchId}', extra: match),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(17),
            border: Border.all(color: Palette.of(context).stroke),
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
                            decoration: BoxDecoration(
                              color: Palette.of(context).music,
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
                        color: match.lastMessage == null ? Palette.of(context).faint : Palette.of(context).muted,
                        fontStyle: match.lastMessage == null ? FontStyle.italic : FontStyle.normal,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: Palette.of(context).faint, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}


/// Pending connection requests, surfaced above the conversations so an opt-in
/// never sits unnoticed.
class _RequestsBanner extends ConsumerWidget {
  const _RequestsBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = Palette.of(context);
    final text = Theme.of(context).textTheme;
    final requests = ref.watch(requestsControllerProvider).value ?? const [];
    if (requests.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: palette.music.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(17),
        child: InkWell(
          borderRadius: BorderRadius.circular(17),
          onTap: () => context.push('/requests'),
          child: Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(17),
              border: Border.all(color: palette.music.withValues(alpha: 0.45)),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 58,
                  height: 34,
                  child: Stack(
                    children: [
                      for (var i = 0; i < requests.take(3).length; i++)
                        Positioned(
                          left: i * 16.0,
                          child: CircleAvatar(
                            radius: 17,
                            backgroundColor: palette.surface,
                            child: CircleAvatar(
                              radius: 15,
                              backgroundColor: palette.surfaceHigh,
                              backgroundImage: requests[i].user.photoUrl != null
                                  ? NetworkImage(requests[i].user.photoUrl!)
                                  : null,
                              child: requests[i].user.photoUrl == null
                                  ? Text(
                                      requests[i]
                                          .user
                                          .displayName
                                          .characters
                                          .first
                                          .toUpperCase(),
                                      style: const TextStyle(fontSize: 12))
                                  : null,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        requests.length == 1
                            ? '1 person wants to connect'
                            : '${requests.length} people want to connect',
                        style: text.titleSmall?.copyWith(color: palette.music),
                      ),
                      const SizedBox(height: 2),
                      Text('Accept to open the conversation',
                          style: text.bodySmall?.copyWith(color: palette.muted)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, size: 20, color: palette.music),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
