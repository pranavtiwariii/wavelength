import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_exception.dart';
import '../../core/theme.dart';
import '../../widgets/page_shell.dart';
import '../discovery/discovery_controller.dart';
import '../discovery/discovery_models.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, required this.matchId, this.match});

  final String matchId;
  final MatchSummary? match;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send([String? preset]) async {
    final content = (preset ?? _controller.text).trim();
    if (content.isEmpty || _sending) return;

    setState(() => _sending = true);
    try {
      await ref.read(discoveryRepositoryProvider).send(widget.matchId, content);
      _controller.clear();
      ref.invalidate(chatProvider(widget.matchId));
      ref.read(matchesControllerProvider.notifier).refresh();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(chatProvider(widget.matchId));
    final name = widget.match?.user.displayName ?? 'Chat';

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(name, style: Theme.of(context).textTheme.titleMedium),
        actions: [
          if (widget.match != null)
            IconButton(
              tooltip: 'Why you matched',
              icon: const Icon(Icons.bar_chart_rounded, size: 20, color: WaveColors.muted),
              onPressed: () => context.push('/compatibility/${widget.match!.user.id}'),
            ),
        ],
      ),
      body: SafeArea(
        child: PageShell(
          child: Column(
            children: [
              Expanded(
                child: async.when(
                  loading: () => const Center(
                    child: SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: WaveColors.muted),
                    ),
                  ),
                  error: (err, _) =>
                      Center(child: Text('$err', style: const TextStyle(color: WaveColors.muted))),
                  data: (messages) => messages.isEmpty
                      ? _Icebreakers(match: widget.match, onPick: _send)
                      : ListView.builder(
                          controller: _scroll,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          itemCount: messages.length,
                          itemBuilder: (context, i) => _Bubble(message: messages[i]),
                        ),
                ),
              ),
              _Composer(
                controller: _controller,
                sending: _sending,
                onSend: _send,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Spec 3.6: openers generated from the actual overlap, so a first message
/// doesn't have to be invented from nothing.
class _Icebreakers extends ConsumerWidget {
  const _Icebreakers({required this.match, required this.onPick});

  final MatchSummary? match;
  final void Function(String) onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    if (match == null) return const SizedBox.shrink();

    final async = ref.watch(compatibilityProvider(match!.user.id));

    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (card) {
        final openers = _buildOpeners(card, match!.user.displayName);
        return ListView(
          padding: const EdgeInsets.symmetric(vertical: 22),
          children: [
            Text('Start with something real', style: text.titleMedium),
            const SizedBox(height: 7),
            Text(
              'Built from what you actually share.',
              style: text.bodySmall?.copyWith(color: WaveColors.muted),
            ),
            const SizedBox(height: 18),
            for (final opener in openers)
              Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: Material(
                  color: WaveColors.surface,
                  borderRadius: BorderRadius.circular(15),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(15),
                    onTap: () => onPick(opener),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: WaveColors.stroke),
                      ),
                      child: Text(opener, style: text.bodyMedium),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  List<String> _buildOpeners(CompatibilityCard card, String name) {
    final openers = <String>[];

    if (card.shared.isNotEmpty) {
      final top = card.shared.first;
      openers.add('Ok, ${top.label}. Where did that start for you?');
    }
    if (card.shared.length > 1) {
      openers.add(
        'We overlap on ${card.shared.take(2).map((h) => h.label).join(' and ')} — what else should I be on?',
      );
    }

    final theirs = card.divergences.where((d) => d.heldBy == card.user.id).toList();
    if (theirs.isNotEmpty) {
      openers.add("I've never gotten into ${theirs.first.label}. Sell me on it.");
    }

    if (openers.length < 3) {
      openers.add('What have you had on repeat this week?');
    }
    return openers.take(3).toList();
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final mine = message.mine;

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.72),
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
        decoration: BoxDecoration(
          color: mine ? WaveColors.music.withValues(alpha: 0.16) : WaveColors.surface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(17),
            topRight: const Radius.circular(17),
            bottomLeft: Radius.circular(mine ? 17 : 5),
            bottomRight: Radius.circular(mine ? 5 : 17),
          ),
          border: Border.all(
            color: mine ? WaveColors.music.withValues(alpha: 0.3) : WaveColors.stroke,
          ),
        ),
        child: Text(message.content, style: Theme.of(context).textTheme.bodyMedium),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({required this.controller, required this.sending, required this.onSend});

  final TextEditingController controller;
  final bool sending;
  final void Function() onSend;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 6),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSend(),
              decoration: const InputDecoration(
                hintText: 'Message',
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              ),
            ),
          ),
          const SizedBox(width: 9),
          Material(
            color: WaveColors.cream,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: sending ? null : onSend,
              child: SizedBox(
                height: 48,
                width: 48,
                child: sending
                    ? const Padding(
                        padding: EdgeInsets.all(15),
                        child: CircularProgressIndicator(strokeWidth: 2, color: WaveColors.ink),
                      )
                    : const Icon(Icons.arrow_upward_rounded, color: WaveColors.ink, size: 21),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
