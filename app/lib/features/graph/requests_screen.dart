import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_exception.dart';
import '../../core/theme.dart';
import '../../widgets/entrance.dart';
import '../../widgets/page_shell.dart';
import '../../widgets/score_badge.dart';
import 'graph_controller.dart';
import 'graph_models.dart';

/// Proposal 4.1: connections are opt-in. Nobody is connected to you until you
/// accept, so this inbox is the gate.
class RequestsScreen extends ConsumerWidget {
  const RequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = Palette.of(context);
    final text = Theme.of(context).textTheme;
    final async = ref.watch(requestsControllerProvider);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Requests', style: text.titleMedium),
      ),
      body: SafeArea(
        child: PageShell(
          child: async.when(
            loading: () => const Center(
              child: SizedBox(
                  height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2)),
            ),
            error: (err, _) =>
                Center(child: Text('$err', style: TextStyle(color: palette.muted))),
            data: (requests) => requests.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(28),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('No requests right now', style: text.titleLarge),
                          const SizedBox(height: 9),
                          Text(
                            'When someone asks to connect, they land here first — you decide.',
                            textAlign: TextAlign.center,
                            style: text.bodySmall?.copyWith(color: palette.muted),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.only(top: 8, bottom: 30),
                    itemCount: requests.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, i) => Entrance(
                      delay: Duration(milliseconds: i * 55),
                      child: _RequestCard(request: requests[i]),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _RequestCard extends ConsumerStatefulWidget {
  const _RequestCard({required this.request});

  final ConnectionRequest request;

  @override
  ConsumerState<_RequestCard> createState() => _RequestCardState();
}

class _RequestCardState extends ConsumerState<_RequestCard> {
  bool _busy = false;

  Future<void> _act({required bool accept}) async {
    setState(() => _busy = true);
    final controller = ref.read(requestsControllerProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);

    try {
      if (accept) {
        final matchId = await controller.accept(widget.request);
        messenger.showSnackBar(
          SnackBar(
            content: Text('Connected with ${widget.request.user.displayName}'),
            action: SnackBarAction(
              label: 'Say hi',
              onPressed: () => router.push('/chat/$matchId'),
            ),
          ),
        );
      } else {
        await controller.decline(widget.request);
      }
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
    final user = widget.request.user;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.stroke),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: palette.surfaceHigh,
                backgroundImage: user.photoUrl != null ? NetworkImage(user.photoUrl!) : null,
                child: user.photoUrl == null
                    ? Text(user.displayName.characters.first.toUpperCase())
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.age != null
                          ? '${user.displayName}, ${user.age}'
                          : user.displayName,
                      style: text.titleSmall,
                    ),
                    if (user.city != null) ...[
                      const SizedBox(height: 2),
                      Text(user.city!,
                          style: text.bodySmall?.copyWith(color: palette.muted)),
                    ],
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => context.push('/compatibility/${user.id}'),
                child: ScoreBadge(
                  score: widget.request.overallScore,
                  size: 48,
                  showLabel: false,
                ),
              ),
            ],
          ),
          if (widget.request.message != null) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Text('“${widget.request.message}”',
                  style: text.bodyMedium?.copyWith(fontStyle: FontStyle.italic)),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _busy ? null : () => _act(accept: false),
                  child: const Text('Decline'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: _busy ? null : () => _act(accept: true),
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                  child: _busy
                      ? const SizedBox(
                          height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Accept'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
