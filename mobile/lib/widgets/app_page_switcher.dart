import 'package:flutter/material.dart';

/// Wraps in-app tab/screen content so every switch (bottom nav taps,
/// sidebar taps, drill-downs like a list -> detail view) cross-fades
/// with a subtle upward slide instead of jumping instantly. Different
/// widget types passed in are enough to trigger the transition - no
/// manual keys needed since each tab/screen already returns a distinct
/// widget class.
class AppPageSwitcher extends StatelessWidget {
  final Widget child;
  final Duration duration;

  const AppPageSwitcher({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 280),
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: duration,
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (widget, animation) {
        final slide = Tween<Offset>(
          begin: const Offset(0, 0.02),
          end: Offset.zero,
        ).animate(animation);
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(position: slide, child: widget),
        );
      },
      layoutBuilder: (currentChild, previousChildren) {
        return Stack(
          alignment: Alignment.topCenter,
          children: [
            ...previousChildren,
            if (currentChild != null) currentChild,
          ],
        );
      },
      child: child,
    );
  }
}
