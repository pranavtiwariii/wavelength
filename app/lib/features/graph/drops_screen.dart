import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_exception.dart';
import '../../core/theme.dart';
import '../../widgets/entrance.dart';
import '../../widgets/page_shell.dart';
import '../profiles/create_profile_screen.dart' show SelectChip;
import '../taste/taste_controller.dart';
import '../taste/taste_models.dart';
import 'graph_controller.dart';
import 'graph_models.dart';

/// Proposal 4.1: Content Drops — the shared feed of things people are into.
class DropsScreen extends ConsumerWidget {
  const DropsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = Palette.of(context);
    final text = Theme.of(context).textTheme;
    final drops = ref.watch(dropsControllerProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _compose(context, ref),
        backgroundColor: palette.text,
        foregroundColor: palette.ink,
        icon: const Icon(Icons.add_rounded, size: 20),
        label: const Text('Drop'),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: palette.music,
          backgroundColor: palette.surface,
          onRefresh: () => ref.read(dropsControllerProvider.notifier).refresh(),
          child: PageShell(
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 14, bottom: 6),
                    child: Text('Drops', style: text.headlineMedium),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      'What people are into right now.',
                      style: text.bodySmall?.copyWith(color: palette.muted),
                    ),
                  ),
                ),
                drops.when(
                  loading: () => const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: SizedBox(
                          height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2)),
                    ),
                  ),
                  error: (err, _) => SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                        child: Text('$err',
                            style: TextStyle(color: palette.muted))),
                  ),
                  data: (list) => list.isEmpty
                      ? SliverFillRemaining(
                          hasScrollBody: false,
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.all(28),
                              child: Text(
                                'Nothing dropped yet. Share something you love.',
                                textAlign: TextAlign.center,
                                style: text.bodyMedium?.copyWith(color: palette.muted),
                              ),
                            ),
                          ),
                        )
                      : SliverList.separated(
                          itemCount: list.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 10),
                          itemBuilder: (context, i) => Entrance(
                            delay: Duration(milliseconds: (i.clamp(0, 8)) * 45),
                            child: DropCard(drop: list[i]),
                          ),
                        ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 90)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Future<void> _compose(BuildContext context, WidgetRef ref) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const ComposeDropSheet(),
    );
  }
}

/// One drop. Also used inside a community feed.
class DropCard extends ConsumerWidget {
  const DropCard({super.key, required this.drop});

  final Drop drop;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = Palette.of(context);
    final text = Theme.of(context).textTheme;
    final accent = palette.domain(drop.domain.id);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: drop.sharedWithMe ? accent.withValues(alpha: 0.4) : palette.stroke,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 15,
                backgroundColor: palette.surfaceHigh,
                backgroundImage:
                    drop.authorPhotoUrl != null ? NetworkImage(drop.authorPhotoUrl!) : null,
                child: drop.authorPhotoUrl == null
                    ? Text(drop.authorName.characters.first.toUpperCase(),
                        style: const TextStyle(fontSize: 12))
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(drop.authorName, style: text.titleSmall),
              ),
              if (drop.communityName != null)
                GestureDetector(
                  onTap: drop.communitySlug == null
                      ? null
                      : () => context.push('/communities/${drop.communitySlug}'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: palette.surfaceHigh,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(drop.communityName!,
                        style: TextStyle(fontSize: 11.5, color: palette.muted)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 13),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                height: 46,
                width: 46,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(11),
                  image: drop.itemImage == null
                      ? null
                      : DecorationImage(
                          image: NetworkImage(drop.itemImage!), fit: BoxFit.cover),
                ),
                child: drop.itemImage != null
                    ? null
                    : Icon(drop.domain.icon, size: 20, color: accent),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(drop.itemLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.titleSmall),
                    if (drop.itemSubtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(drop.itemSubtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.bodySmall?.copyWith(color: palette.muted)),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (drop.caption != null) ...[
            const SizedBox(height: 12),
            Text(drop.caption!, style: text.bodyMedium?.copyWith(height: 1.4)),
          ],
          if (drop.sharedWithMe) ...[
            const SizedBox(height: 11),
            Row(
              children: [
                Icon(Icons.bolt_rounded, size: 14, color: accent),
                const SizedBox(width: 5),
                Text('You have this too',
                    style: TextStyle(fontSize: 12, color: accent, fontWeight: FontWeight.w600)),
              ],
            ),
          ],
          const SizedBox(height: 13),
          Row(
            children: [
              _ReactButton(
                icon: drop.likedByMe ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                count: drop.likeCount,
                active: drop.likedByMe,
                activeColor: MateColors.danger,
                onTap: () =>
                    ref.read(dropsControllerProvider.notifier).toggle(drop, 'like'),
              ),
              const SizedBox(width: 16),
              _ReactButton(
                icon: drop.savedByMe ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                count: drop.saveCount,
                active: drop.savedByMe,
                activeColor: accent,
                onTap: () =>
                    ref.read(dropsControllerProvider.notifier).toggle(drop, 'save'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReactButton extends StatelessWidget {
  const _ReactButton({
    required this.icon,
    required this.count,
    required this.active,
    required this.activeColor,
    required this.onTap,
  });

  final IconData icon;
  final int count;
  final bool active;
  final Color activeColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = Palette.of(context);
    final color = active ? activeColor : palette.muted;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        children: [
          // A small pop on activation, so the tap registers physically.
          AnimatedScale(
            scale: active ? 1.15 : 1,
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOut,
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 6),
          Text('$count', style: TextStyle(fontSize: 13, color: color)),
        ],
      ),
    );
  }
}

/// Compose sheet: pick something from your taste, optionally post it into a
/// community you're in.
class ComposeDropSheet extends ConsumerStatefulWidget {
  const ComposeDropSheet({super.key, this.communityId, this.communityName});

  final String? communityId;
  final String? communityName;

  @override
  ConsumerState<ComposeDropSheet> createState() => _ComposeDropSheetState();
}

class _ComposeDropSheetState extends ConsumerState<ComposeDropSheet> {
  final _caption = TextEditingController();
  TasteDomain _domain = TasteDomain.music;
  TasteItem? _item;
  String? _communityId;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _communityId = widget.communityId;
  }

  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_item == null) {
      setState(() => _error = 'Pick something to drop first.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await ref.read(graphRepositoryProvider).createDrop(
            domain: _domain,
            item: _item!,
            caption: _caption.text.trim(),
            communityId: _communityId,
          );
      await ref.read(dropsControllerProvider.notifier).refresh();
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = Palette.of(context);
    final text = Theme.of(context).textTheme;
    final taste = ref.watch(tasteControllerProvider).value;
    final items = taste?[_domain].items ?? const <TasteItem>[];

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        decoration: BoxDecoration(
          color: palette.ink,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: palette.stroke),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 22),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  height: 4,
                  width: 40,
                  decoration: BoxDecoration(
                    color: palette.stroke,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                widget.communityName == null
                    ? 'Drop something'
                    : 'Drop into ${widget.communityName}',
                style: text.titleLarge,
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  for (final domain in TasteDomain.values)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 7),
                        child: SelectChip(
                          label: domain.label,
                          selected: _domain == domain,
                          onTap: () => setState(() {
                            _domain = domain;
                            _item = null;
                          }),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              if (items.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: palette.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: palette.stroke),
                  ),
                  child: Text(
                    'Add some ${_domain.noun} to your taste profile first — drops come from what you already love.',
                    style: text.bodySmall?.copyWith(color: palette.muted),
                  ),
                )
              else
                SizedBox(
                  height: 120,
                  child: ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 6),
                    itemBuilder: (context, i) {
                      final item = items[i];
                      final selected = _item?.key == item.key;
                      return GestureDetector(
                        onTap: () => setState(() => _item = item),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
                          decoration: BoxDecoration(
                            color: selected
                                ? palette.domain(_domain.id).withValues(alpha: 0.14)
                                : palette.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: selected
                                  ? palette.domain(_domain.id)
                                  : palette.stroke,
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(item.label,
                                    maxLines: 1, overflow: TextOverflow.ellipsis),
                              ),
                              if (selected)
                                Icon(Icons.check_circle_rounded,
                                    size: 17, color: palette.domain(_domain.id)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 12),
              TextField(
                controller: _caption,
                maxLines: 2,
                maxLength: 200,
                decoration: InputDecoration(
                  hintText: 'Say something about it (optional)',
                  counterStyle: TextStyle(color: palette.faint),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: text.bodySmall?.copyWith(color: MateColors.danger)),
              ],
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _saving ? null : _submit,
                child: _saving
                    ? const SizedBox(
                        height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Post drop'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
