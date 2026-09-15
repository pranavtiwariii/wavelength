import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../widgets/entrance.dart';
import '../../widgets/page_shell.dart';
import 'drops_screen.dart';
import 'graph_controller.dart';

/// Drops you saved — the proposal's "likes and saves" half of engagement.
class SavedScreen extends ConsumerWidget {
  const SavedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = Palette.of(context);
    final text = Theme.of(context).textTheme;
    final async = ref.watch(savedDropsProvider);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Saved', style: text.titleMedium),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: palette.music,
          backgroundColor: palette.surface,
          onRefresh: () async => ref.invalidate(savedDropsProvider),
          child: PageShell(
            child: async.when(
              loading: () => const Center(
                child: SizedBox(
                    height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2)),
              ),
              error: (err, _) =>
                  Center(child: Text('$err', style: TextStyle(color: palette.muted))),
              data: (drops) => drops.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        const SizedBox(height: 80),
                        Icon(Icons.bookmark_border_rounded, size: 34, color: palette.faint),
                        const SizedBox(height: 14),
                        Text('Nothing saved yet',
                            textAlign: TextAlign.center, style: text.titleMedium),
                        const SizedBox(height: 8),
                        Text(
                          'Tap the bookmark on a drop to keep it here.',
                          textAlign: TextAlign.center,
                          style: text.bodySmall?.copyWith(color: palette.muted),
                        ),
                      ],
                    )
                  : ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      itemCount: drops.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, i) => Entrance(
                        delay: Duration(milliseconds: (i.clamp(0, 8)) * 45),
                        child: DropCard(drop: drops[i]),
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
