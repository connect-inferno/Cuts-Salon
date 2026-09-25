import 'package:flutter/material.dart';

/// The push transition for every screen that opens on top of another.
///
/// [MaterialPageRoute] on web uses the "zoom/fade up" transition, which
/// reads as a page appearing *in front of* the current one with no sense of
/// where it came from or how to get back. A horizontal slide says it plainly:
/// the new screen comes in from the right, the old one eases left behind it,
/// and the back arrow reverses exactly that.
///
/// The outgoing page moves a fraction of the distance rather than the full
/// width - that parallax is what makes the two read as a stack with depth
/// instead of two slides on a conveyor belt.
class AppSlidePageRoute<T> extends PageRouteBuilder<T> {
  final Widget page;

  AppSlidePageRoute({required this.page, super.settings})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionDuration: const Duration(milliseconds: 320),
          reverseTransitionDuration: const Duration(milliseconds: 260),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final incoming = Tween<Offset>(
              begin: const Offset(1, 0),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            ));

            // Where the page *underneath* goes while this one covers it.
            final outgoing = Tween<Offset>(
              begin: Offset.zero,
              end: const Offset(-0.25, 0),
            ).animate(CurvedAnimation(
              parent: secondaryAnimation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            ));

            return SlideTransition(
              position: outgoing,
              child: SlideTransition(
                position: incoming,
                child: child,
              ),
            );
          },
        );
}
