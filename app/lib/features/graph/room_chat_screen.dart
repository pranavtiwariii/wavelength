import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_exception.dart';
import '../../core/theme.dart';
import '../../widgets/page_shell.dart';
import 'graph_controller.dart';
import 'graph_models.dart';

/// Group chat for a community you've joined.
class RoomChatScreen extends ConsumerStatefulWidget {
  const RoomChatScreen({super.key, required this.communityId, this.communityName});

  final String communityId;
  final String? communityName;

  @override
  ConsumerState<RoomChatScreen> createState() => _RoomChatScreenState();
}

class _RoomChatScreenState extends ConsumerState<RoomChatScreen> {
  final _controller = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final content = _controller.text.trim();
    if (content.isEmpty || _sending) return;

    setState(() => _sending = true);
    try {
      await ref.read(graphRepositoryProvider).sendRoomMessage(widget.communityId, content);
      _controller.clear();
      ref.invalidate(roomMessagesProvider(widget.communityId));
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
    final palette = Palette.of(context);
    final text = Theme.of(context).textTheme;
    final async = ref.watch(roomMessagesProvider(widget.communityId));

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(widget.communityName ?? 'Room', style: text.titleMedium),
      ),
      body: SafeArea(
        child: PageShell(
          child: Column(
            children: [
              Expanded(
                child: async.when(
                  loading: () => const Center(
                    child: SizedBox(
                        height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                  ),
                  error: (err, _) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text('$err',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: palette.muted)),
                    ),
                  ),
                  data: (messages) => messages.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              'Nobody has said anything yet. Go first.',
                              textAlign: TextAlign.center,
                              style: text.bodyMedium?.copyWith(color: palette.muted),
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          itemCount: messages.length,
                          itemBuilder: (context, i) => _RoomBubble(
                            message: messages[i],
                            // Group consecutive messages from one person.
                            showSender: i == 0 ||
                                messages[i - 1].senderName != messages[i].senderName,
                          ),
                        ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 10, top: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        minLines: 1,
                        maxLines: 4,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _send(),
                        decoration: const InputDecoration(
                          hintText: 'Message the room',
                          contentPadding:
                              EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                        ),
                      ),
                    ),
                    const SizedBox(width: 9),
                    Material(
                      color: palette.text,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: _sending ? null : _send,
                        child: SizedBox(
                          height: 48,
                          width: 48,
                          child: _sending
                              ? const Padding(
                                  padding: EdgeInsets.all(15),
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : Icon(Icons.arrow_upward_rounded,
                                  color: palette.ink, size: 21),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoomBubble extends StatelessWidget {
  const _RoomBubble({required this.message, required this.showSender});

  final RoomMessage message;
  final bool showSender;

  @override
  Widget build(BuildContext context) {
    final palette = Palette.of(context);
    final mine = message.mine;

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (showSender && !mine)
            Padding(
              padding: const EdgeInsets.only(left: 6, top: 8, bottom: 3),
              child: Text(
                message.senderName,
                style: TextStyle(fontSize: 11.5, color: palette.faint, fontWeight: FontWeight.w600),
              ),
            ),
          Container(
            constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.7),
            margin: const EdgeInsets.symmetric(vertical: 2),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: mine ? palette.music.withValues(alpha: 0.16) : palette.surface,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(mine ? 16 : 5),
                bottomRight: Radius.circular(mine ? 5 : 16),
              ),
              border: Border.all(
                color: mine ? palette.music.withValues(alpha: 0.3) : palette.stroke,
              ),
            ),
            child: Text(message.content,
                style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}
