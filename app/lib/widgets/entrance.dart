import 'package:flutter/material.dart';

/// Fades and lifts a widget into place. Used to stagger lists and card content
/// so screens assemble rather than snap.
class Entrance extends StatefulWidget {
  const Entrance({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.offset = 14,
    this.duration = const Duration(milliseconds: 380),
  });

  final Widget child;
  final Duration delay;
  final double offset;
  final Duration duration;

  @override
  State<Entrance> createState() => _EntranceState();
}

class _EntranceState extends State<Entrance> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: widget.duration);

  @override
  void initState() {
    super.initState();
    if (widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      Future<void>.delayed(widget.delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curve = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);

    return AnimatedBuilder(
      animation: curve,
      builder: (context, child) => Opacity(
        opacity: curve.value,
        child: Transform.translate(
          offset: Offset(0, widget.offset * (1 - curve.value)),
          child: child,
        ),
      ),
      child: widget.child,
    );
  }
}

/// Staggers a list of children by a fixed step.
List<Widget> staggered(List<Widget> children, {int stepMs = 55}) => [
      for (var i = 0; i < children.length; i++)
        Entrance(delay: Duration(milliseconds: i * stepMs), child: children[i]),
    ];
