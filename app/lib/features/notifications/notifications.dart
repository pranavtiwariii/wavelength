import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../widgets/entrance.dart';
import '../../widgets/page_shell.dart';
import '../auth/auth_controller.dart';

/// Proposal 5.2: in-app notifications for connections, likes and new matches.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.kind,
    required this.body,
    required this.createdAt,
    required this.unread,
    this.target,
    this.actorName,
    this.actorPhotoUrl,
  });

  final String id;
  final String kind;
  final String body;
  final String createdAt;
  final bool unread;
  final String? target;
  final String? actorName;
  final String? actorPhotoUrl;

  IconData get icon => switch (kind) {
        'connection_request' => Icons.person_add_alt_1_rounded,
        'connection_accepted' || 'new_match' => Icons.handshake_rounded,
        'message' => Icons.forum_rounded,
        'drop_like' => Icons.favorite_rounded,
        'room_message' => Icons.group_rounded,
        _ => Icons.notifications_rounded,
      };

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    final actor = json['actor'] as Map<String, dynamic>?;
    return AppNotification(
      id: json['id'] as String,
      kind: json['kind'] as String,
      body: json['body'] as String,
      createdAt: json['createdAt'] as String,
      unread: json['readAt'] == null,
      target: json['target'] as String?,
      actorName: actor?['name'] as String?,
      actorPhotoUrl: actor?['photoUrl'] as String?,
    );
  }
}

class NotificationsState {
  const NotificationsState({required this.items, required this.unread});

  final List<AppNotification> items;
  final int unread;
}

class NotificationsController extends AsyncNotifier<NotificationsState> {
  @override
  Future<NotificationsState> build() async {
    final json = await ref.read(authRepositoryProvider).client.get('/notifications');
    return NotificationsState(
      items: (json['notifications'] as List<dynamic>? ?? [])
          .map((e) => AppNotification.fromJson(e as Map<String, dynamic>))
          .toList(),
      unread: json['unread'] as int? ?? 0,
    );
  }

  Future<void> markAllRead() async {
    await ref.read(authRepositoryProvider).client.post('/notifications/read');
    ref.invalidateSelf();
  }

  Future<void> refresh() async => ref.invalidateSelf();
}

final notificationsControllerProvider =
    AsyncNotifierProvider<NotificationsController, NotificationsState>(
        NotificationsController.new);

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    // Opening the inbox is what marks them read.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(notificationsControllerProvider.notifier).markAllRead();
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = Palette.of(context);
    final text = Theme.of(context).textTheme;
    final async = ref.watch(notificationsControllerProvider);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Activity', style: text.titleMedium),
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
            data: (state) => state.items.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(28),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.notifications_none_rounded,
                              size: 34, color: palette.faint),
                          const SizedBox(height: 14),
                          Text('Nothing yet', style: text.titleMedium),
                          const SizedBox(height: 8),
                          Text(
                            'Requests, matches and likes show up here.',
                            textAlign: TextAlign.center,
                            style: text.bodySmall?.copyWith(color: palette.muted),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    itemCount: state.items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, i) => Entrance(
                      delay: Duration(milliseconds: (i.clamp(0, 8)) * 45),
                      child: _NotificationRow(notification: state.items[i]),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _NotificationRow extends StatelessWidget {
  const _NotificationRow({required this.notification});

  final AppNotification notification;

  @override
  Widget build(BuildContext context) {
    final palette = Palette.of(context);
    final text = Theme.of(context).textTheme;

    return Material(
      color: palette.surface,
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: notification.target == null ? null : () => context.push(notification.target!),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: notification.unread
                  ? palette.music.withValues(alpha: 0.4)
                  : palette.stroke,
            ),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 19,
                backgroundColor: palette.surfaceHigh,
                backgroundImage: notification.actorPhotoUrl != null
                    ? NetworkImage(notification.actorPhotoUrl!)
                    : null,
                child: notification.actorPhotoUrl == null
                    ? Icon(notification.icon, size: 17, color: palette.muted)
                    : null,
              ),
              const SizedBox(width: 13),
              Expanded(child: Text(notification.body, style: text.bodyMedium)),
              if (notification.unread)
                Container(
                  height: 7,
                  width: 7,
                  decoration: BoxDecoration(color: palette.music, shape: BoxShape.circle),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
