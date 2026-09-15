import 'package:flutter/material.dart';

/// MATES is a phone app. On a wide window an unconstrained mobile layout
/// flings its content to both edges and reads as broken, so every screen goes
/// through this: a centred column that never grows past a comfortable reading
/// measure, with the gutter scaling down on genuinely small screens.
class PageShell extends StatelessWidget {
  const PageShell({
    super.key,
    required this.child,
    this.maxWidth = 460,
    this.padding = const EdgeInsets.symmetric(horizontal: 24),
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}
