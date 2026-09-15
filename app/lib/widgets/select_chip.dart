import 'package:flutter/material.dart';

import '../core/theme.dart';

/// A selectable pill. Shared by onboarding, the drop composer and filters, so
/// every choice in the app looks and animates the same way.
class SelectChip extends StatelessWidget {
  const SelectChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = Palette.of(context);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        decoration: BoxDecoration(
          color: selected ? palette.music.withValues(alpha: 0.15) : palette.surface,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: selected ? palette.music : palette.stroke),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            color: selected ? palette.music : palette.muted,
          ),
        ),
      ),
    );
  }
}
