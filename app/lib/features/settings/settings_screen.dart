import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/settings_controller.dart';
import '../../core/theme.dart';
import '../../widgets/page_shell.dart';
import '../../core/api/api_exception.dart';
import '../auth/auth_controller.dart';
import '../discovery/discovery_controller.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = Palette.of(context);
    final text = Theme.of(context).textTheme;
    final mode = ref.watch(settingsControllerProvider).value?.themeMode ?? ThemeMode.dark;
    final authState = ref.watch(authControllerProvider).value;
    final user = authState is SignedIn ? authState.user : null;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Settings', style: text.titleMedium),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: PageShell(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (user != null) ...[
                  _Card(
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 26,
                          backgroundColor: palette.surfaceHigh,
                          backgroundImage:
                              user.photoUrl != null ? NetworkImage(user.photoUrl!) : null,
                          child: user.photoUrl == null
                              ? Text(user.displayName.characters.first.toUpperCase())
                              : null,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(user.displayName, style: text.titleSmall),
                              const SizedBox(height: 3),
                              Text(
                                [user.age?.toString(), user.city].whereType<String>().join(' · '),
                                style: text.bodySmall?.copyWith(color: palette.muted),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                ],

                _Label('APPEARANCE'),
                const SizedBox(height: 10),
                _Card(
                  padding: const EdgeInsets.all(5),
                  child: Row(
                    children: [
                      for (final option in const [
                        (ThemeMode.dark, 'Dark', Icons.dark_mode_rounded),
                        (ThemeMode.light, 'Light', Icons.light_mode_rounded),
                        (ThemeMode.system, 'System', Icons.brightness_auto_rounded),
                      ])
                        Expanded(
                          child: _ModeTab(
                            label: option.$2,
                            icon: option.$3,
                            selected: mode == option.$1,
                            onTap: () => ref
                                .read(settingsControllerProvider.notifier)
                                .setThemeMode(option.$1),
                          ),
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 22),
                _Label('CONTENT'),
                const SizedBox(height: 10),
                _Row(
                  icon: Icons.bookmark_rounded,
                  title: 'Saved drops',
                  subtitle: 'Everything you bookmarked',
                  onTap: () => context.push('/saved'),
                ),
                const SizedBox(height: 9),
                const _ExpandPoolRow(),

                const SizedBox(height: 22),
                _Label('ACCOUNT'),
                const SizedBox(height: 10),
                _Row(
                  icon: Icons.logout_rounded,
                  title: 'Sign out',
                  danger: true,
                  onTap: () => ref.read(authControllerProvider.notifier).signOut(),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
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

class _Card extends StatelessWidget {
  const _Card({required this.child, this.padding = const EdgeInsets.all(16)});

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final palette = Palette.of(context);
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.stroke),
      ),
      child: child,
    );
  }
}

class _ModeTab extends StatelessWidget {
  const _ModeTab({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = Palette.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? palette.surfaceHigh : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, size: 18, color: selected ? palette.music : palette.muted),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: selected ? palette.text : palette.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.danger = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final palette = Palette.of(context);
    final color = danger ? MateColors.danger : palette.text;

    return Material(
      color: palette.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: palette.stroke),
          ),
          child: Row(
            children: [
              Icon(icon, size: 19, color: color),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(color: color)),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(subtitle!,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: palette.muted)),
                    ],
                  ],
                ),
              ),
              if (!danger)
                Icon(Icons.chevron_right_rounded, size: 20, color: palette.faint),
            ],
          ),
        ),
      ),
    );
  }
}


/// Generates more people shaped by your taste. The pool is built for you rather
/// than typed in by hand, so this is how it grows.
class _ExpandPoolRow extends ConsumerStatefulWidget {
  const _ExpandPoolRow();

  @override
  ConsumerState<_ExpandPoolRow> createState() => _ExpandPoolRowState();
}

class _ExpandPoolRowState extends ConsumerState<_ExpandPoolRow> {
  bool _busy = false;

  Future<void> _expand() async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final result =
          await ref.read(authRepositoryProvider).client.post('/me/pool/expand');
      ref.invalidate(discoveryControllerProvider);
      messenger.showSnackBar(
        SnackBar(content: Text('Added ${result['created']} people to your pool')),
      );
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

    return Material(
      color: palette.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: _busy ? null : _expand,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: palette.stroke),
          ),
          child: Row(
            children: [
              Icon(Icons.group_add_rounded, size: 19, color: palette.text),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Expand the pool', style: text.titleSmall),
                    const SizedBox(height: 2),
                    Text('Add more people who share your taste',
                        style: text.bodySmall?.copyWith(color: palette.muted)),
                  ],
                ),
              ),
              if (_busy)
                const SizedBox(
                    height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
              else
                Icon(Icons.chevron_right_rounded, size: 20, color: palette.faint),
            ],
          ),
        ),
      ),
    );
  }
}
