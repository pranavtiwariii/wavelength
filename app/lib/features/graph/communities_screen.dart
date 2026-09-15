import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../widgets/entrance.dart';
import '../../widgets/page_shell.dart';
import 'drops_screen.dart';
import 'graph_controller.dart';
import 'graph_models.dart';

/// Proposal 4.1: niche, tag-based groups. Suggestions come from the user's own
/// taste vector, and each suggestion shows which of their tags pulled it up.
class CommunitiesScreen extends ConsumerWidget {
  const CommunitiesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = Palette.of(context);
    final text = Theme.of(context).textTheme;
    final async = ref.watch(communitiesControllerProvider);

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          color: palette.music,
          backgroundColor: palette.surface,
          onRefresh: () => ref.read(communitiesControllerProvider.notifier).refresh(),
          child: PageShell(
            child: async.when(
              loading: () => const Center(
                child: SizedBox(
                    height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2)),
              ),
              error: (err, _) =>
                  Center(child: Text('$err', style: TextStyle(color: palette.muted))),
              data: (data) {
                final joined = data.all.where((c) => c.joined).toList();
                final rest = data.all.where((c) => !c.joined).toList();

                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    const SizedBox(height: 14),
                    Text('Communities', style: text.headlineMedium),
                    const SizedBox(height: 6),
                    Text(
                      'Tag-based rooms for specific corners of taste.',
                      style: text.bodySmall?.copyWith(color: palette.muted),
                    ),
                    const SizedBox(height: 22),

                    if (data.suggested.isNotEmpty) ...[
                      _SectionLabel('SUGGESTED FOR YOU'),
                      const SizedBox(height: 10),
                      ...staggered([
                        for (final community in data.suggested)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 9),
                            child: _CommunityCard(community: community, showWhy: true),
                          ),
                      ]),
                      const SizedBox(height: 20),
                    ],

                    if (joined.isNotEmpty) ...[
                      _SectionLabel('YOURS'),
                      const SizedBox(height: 10),
                      for (final community in joined)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 9),
                          child: _CommunityCard(community: community),
                        ),
                      const SizedBox(height: 20),
                    ],

                    _SectionLabel('BROWSE ALL'),
                    const SizedBox(height: 10),
                    for (final community in rest)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 9),
                        child: _CommunityCard(community: community),
                      ),
                    const SizedBox(height: 40),
                  ],
                );
              },
            ),
          ),
        ),
      ),
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

class _CommunityCard extends ConsumerWidget {
  const _CommunityCard({required this.community, this.showWhy = false});

  final Community community;
  final bool showWhy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = Palette.of(context);
    final text = Theme.of(context).textTheme;
    final accent = community.domain == null
        ? palette.music
        : palette.domain(community.domain!);

    return Material(
      color: palette.surface,
      borderRadius: BorderRadius.circular(17),
      child: InkWell(
        borderRadius: BorderRadius.circular(17),
        onTap: () => context.push('/communities/${community.slug}'),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(17),
            border: Border.all(
              color: community.joined ? accent.withValues(alpha: 0.4) : palette.stroke,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(community.name, style: text.titleSmall)),
                  _JoinButton(community: community, accent: accent),
                ],
              ),
              if (community.description != null) ...[
                const SizedBox(height: 6),
                Text(community.description!,
                    style: text.bodySmall?.copyWith(color: palette.muted, height: 1.4)),
              ],
              const SizedBox(height: 11),
              Row(
                children: [
                  Icon(Icons.group_rounded, size: 14, color: palette.faint),
                  const SizedBox(width: 6),
                  Text('${community.memberCount}',
                      style: TextStyle(fontSize: 12.5, color: palette.faint)),
                  if (showWhy && community.matchedTags.isNotEmpty) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'matches ${community.matchedTags.take(2).join(", ")}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: accent),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _JoinButton extends ConsumerStatefulWidget {
  const _JoinButton({required this.community, required this.accent});

  final Community community;
  final Color accent;

  @override
  ConsumerState<_JoinButton> createState() => _JoinButtonState();
}

class _JoinButtonState extends ConsumerState<_JoinButton> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final palette = Palette.of(context);
    final joined = widget.community.joined;

    return GestureDetector(
      onTap: _busy
          ? null
          : () async {
              setState(() => _busy = true);
              final controller = ref.read(communitiesControllerProvider.notifier);
              try {
                joined
                    ? await controller.leave(widget.community)
                    : await controller.join(widget.community);
              } finally {
                if (mounted) setState(() => _busy = false);
              }
            },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: joined ? Colors.transparent : widget.accent.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: joined ? palette.stroke : widget.accent),
        ),
        child: _busy
            ? const SizedBox(height: 13, width: 13, child: CircularProgressIndicator(strokeWidth: 2))
            : Text(
                joined ? 'Joined' : 'Join',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: joined ? palette.muted : widget.accent,
                ),
              ),
      ),
    );
  }
}

/// One community: who's in it and what they're dropping.
class CommunityDetailScreen extends ConsumerWidget {
  const CommunityDetailScreen({super.key, required this.slug});

  final String slug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = Palette.of(context);
    final text = Theme.of(context).textTheme;
    final async = ref.watch(communityDetailProvider(slug));

    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      body: SafeArea(
        child: async.when(
          loading: () => const Center(
            child: SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2)),
          ),
          error: (err, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Text('$err',
                  textAlign: TextAlign.center, style: TextStyle(color: palette.muted)),
            ),
          ),
          data: (detail) {
            final community = detail.community;
            final accent = community.domain == null
                ? palette.music
                : palette.domain(community.domain!);

            return PageShell(
              child: ListView(
                children: [
                  Text(community.name, style: text.headlineMedium),
                  if (community.description != null) ...[
                    const SizedBox(height: 8),
                    Text(community.description!,
                        style: text.bodyMedium?.copyWith(color: palette.muted, height: 1.45)),
                  ],
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final tag in community.tags.take(6))
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text('#$tag',
                              style: TextStyle(fontSize: 12, color: accent)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(child: _JoinButton(community: community, accent: accent)),
                      const SizedBox(width: 10),
                      if (community.joined)
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => showModalBottomSheet<void>(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (_) => ComposeDropSheet(
                                communityId: community.id,
                                communityName: community.name,
                              ),
                            ),
                            icon: const Icon(Icons.add_rounded, size: 17),
                            label: const Text('Drop here'),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _SectionLabel('${detail.members.length} MEMBERS'),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 64,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: detail.members.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 12),
                      itemBuilder: (context, i) {
                        final member = detail.members[i];
                        return GestureDetector(
                          onTap: () => context.push('/compatibility/${member.id}'),
                          child: Column(
                            children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundColor: palette.surfaceHigh,
                                backgroundImage: member.photoUrl != null
                                    ? NetworkImage(member.photoUrl!)
                                    : null,
                                child: member.photoUrl == null
                                    ? Text(member.displayName.characters.first.toUpperCase())
                                    : null,
                              ),
                              const SizedBox(height: 5),
                              SizedBox(
                                width: 52,
                                child: Text(
                                  member.displayName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 11, color: palette.muted),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 26),
                  _SectionLabel('DROPS'),
                  const SizedBox(height: 12),
                  if (detail.drops.isEmpty)
                    Text('Nothing dropped here yet.',
                        style: text.bodySmall?.copyWith(color: palette.muted))
                  else
                    for (final drop in detail.drops)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: DropCard(drop: drop),
                      ),
                  const SizedBox(height: 40),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
