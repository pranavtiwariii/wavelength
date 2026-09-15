import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/theme.dart';

/// The signed-in frame: Discover / Matches / Taste (spec section 8).
/// Taste Rooms will slot in here as a fourth tab.
class TabShell extends StatelessWidget {
  const TabShell({super.key, required this.child, required this.location});

  final Widget child;
  final String location;

  static const _tabs = [
    (path: '/discover', icon: Icons.auto_awesome_rounded, label: 'Discover'),
    (path: '/drops', icon: Icons.bolt_rounded, label: 'Drops'),
    (path: '/communities', icon: Icons.group_work_rounded, label: 'Rooms'),
    (path: '/matches', icon: Icons.forum_rounded, label: 'Matches'),
    (path: '/taste', icon: Icons.equalizer_rounded, label: 'Taste'),
  ];

  int get _index {
    final i = _tabs.indexWhere((t) => location.startsWith(t.path));
    return i < 0 ? 0 : i;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: Builder(builder: (context) {
        final palette = Palette.of(context);
        return Container(
        decoration: BoxDecoration(
          color: palette.ink,
          border: Border(top: BorderSide(color: palette.stroke)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                for (var i = 0; i < _tabs.length; i++)
                  _Tab(
                    icon: _tabs[i].icon,
                    label: _tabs[i].label,
                    selected: _index == i,
                    onTap: () => context.go(_tabs[i].path),
                  ),
              ],
            ),
          ),
        ),
      );
      }),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = Palette.of(context);
    final color = selected ? palette.text : palette.faint;

    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // The icon lifts and the dot appears on selection, so the tab
                // change reads as a movement rather than a colour swap.
                AnimatedSlide(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                  offset: Offset(0, selected ? -0.08 : 0),
                  child: Icon(icon, size: 22, color: color),
                ),
                const SizedBox(height: 4),
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 200),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: color,
                  ),
                  child: Text(label),
                ),
                const SizedBox(height: 3),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                  height: 3,
                  width: selected ? 16 : 0,
                  decoration: BoxDecoration(
                    color: palette.music,
                    borderRadius: BorderRadius.circular(999),
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
