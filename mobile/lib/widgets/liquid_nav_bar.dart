import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

/// The floating bottom bar shared by the owner and employee dashboards,
/// animated in the iOS 26 "liquid glass" idiom.
///
/// Three things make that idiom read as liquid rather than as a plain
/// crossfade, and all three are here:
///
///  * **One indicator that travels.** The selection capsule doesn't fade out
///    under the old tab and in under the new one - it slides, and while it's
///    in flight it stretches along the direction of travel and squashes
///    across it (classic squash-and-stretch, scaled by how far it has to
///    go), then settles. That's [_flowController].
///  * **Glass, not paint.** The bar is a translucent capsule over a real
///    backdrop blur with a specular highlight along its top edge, so
///    whatever scrolls underneath tints it.
///  * **Everything reacts to touch.** Each slot and the centre button dip
///    under a press and spring back, and icons morph between their outline
///    and filled weights as the capsule arrives.
///
/// The slot list is always 5 wide, and [selectedIndex] is the slot index
/// directly - exactly the numbering both dashboards keep their nav state in.
///
/// There are two shapes. The plain one (no [onCenterTap]) is five real
/// destinations, which is what both dashboards use now: the protruding "+"
/// used to eat the middle slot to open a "Quick Actions" sheet whose four
/// tiles only jumped to four pages that were already reachable, so it spent
/// a fifth of the bar on a second, redundant way to navigate. If
/// [onCenterTap] is supplied, the entry at [centerSlot] must be null and
/// that gap carries the protruding action button instead.
class LiquidNavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final int badgeCount;

  const LiquidNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.onTap,
    this.onLongPress,
    this.badgeCount = 0,
  });
}

class LiquidNavBar extends StatefulWidget {
  /// Exactly 5 entries. All non-null unless [onCenterTap] is supplied, in
  /// which case the one at [centerSlot] must be null.
  final List<LiquidNavItem?> items;

  /// The selected slot, or null when no slot is current - which is what a
  /// pure-action slot like "Menu" leaves behind, since opening the drawer
  /// doesn't move the user off the page they were on.
  final int? selectedIndex;
  final String centerLabel;
  final VoidCallback? onCenterTap;
  final IconData centerIcon;

  static const int centerSlot = 2;

  const LiquidNavBar({
    super.key,
    required this.items,
    required this.selectedIndex,
    this.onCenterTap,
    this.centerLabel = 'New',
    this.centerIcon = Icons.add_rounded,
    // No assert on items[centerSlot] being null when onCenterTap is set:
    // indexing a list isn't a constant expression, so it can't run in a
    // const constructor. The build below simply draws whatever is in the
    // slot, and the button over it.
  }) : assert(items.length == 5);

  @override
  State<LiquidNavBar> createState() => _LiquidNavBarState();
}

class _LiquidNavBarState extends State<LiquidNavBar> with SingleTickerProviderStateMixin {
  static const Color _accent = Color(0xFF4F46E5);
  // Softer than the old 0xFF334155: four near-black labels beside one
  // indigo one made the unselected items compete with the selected one.
  static const Color _idle = Color(0xFF64748B);
  // 78 left a visible dead band under the labels, and with 16px above and
  // 12px below the bar the whole assembly ate ~106px of a phone screen.
  static const double _barHeight = 62;

  // The selection indicator: a compact pill behind the icon.
  static const double _indicatorWidth = 54;
  static const double _indicatorHeight = 30;
  static const double _labelHeight = 14;
  static const double _iconLabelGap = 3;

  // One number drives both the indicator's y and the slot content's y, so
  // they cannot drift apart the way a hand-tuned `top:` and a separate
  // `Padding` did.
  static const double _contentHeight = _indicatorHeight + _iconLabelGap + _labelHeight;
  static const double _contentTop = (_barHeight - _contentHeight) / 2;

  late final AnimationController _flowController;
  // Fractional, because a redirected flight takes off from a position
  // between two slots.
  late double _fromIndex;
  late int _toIndex;

  @override
  void initState() {
    super.initState();
    _fromIndex = (widget.selectedIndex ?? 0).toDouble();
    _toIndex = widget.selectedIndex ?? 0;
    _flowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 460),
      value: 1,
    );
  }

  @override
  void didUpdateWidget(LiquidNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A null selection leaves the capsule parked where it is: "Menu" opens
    // a drawer over the current page rather than navigating away from it,
    // so the bar should keep pointing at the page underneath.
    final target = widget.selectedIndex;
    if (target != null && target != _toIndex) {
      // Take off from wherever the capsule actually is rather than from the
      // last settled slot, so tapping mid-flight redirects it instead of
      // snapping it back to start the new trip.
      _fromIndex = _currentSlotPosition;
      _toIndex = target;
      _flowController.forward(from: 0);
    }
  }

  double get _currentSlotPosition {
    final t = Curves.easeOutCubic.transform(_flowController.value);
    return _fromIndex + (_toIndex - _fromIndex) * t;
  }

  @override
  void dispose() {
    _flowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Headroom only where something actually protrudes: the centre action
    // button overhangs the bar by 18px, a plain five-slot bar by nothing.
    final topPadding = widget.onCenterTap != null ? 16.0 : 4.0;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(left: 16, right: 16, bottom: 8, top: topPadding),
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            _buildGlassBar(),
            if (widget.onCenterTap != null) Positioned(top: -18, child: _buildCenterButton()),
          ],
        ),
      ),
    );
  }

  Widget _buildGlassBar() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        // The blur is what makes the bar read as glass rather than as a flat
        // white pill: the scaffold sets extendBody, so page content really
        // does pass underneath it.
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          height: _barHeight,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            // Near-opaque with a real border. The page behind it is
            // #F8F9FC and the bar used to be white at 82-92% with a *white*
            // border, so the two washed into each other and the bar read as
            // a strip of the page rather than as something floating over it.
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.white.withValues(alpha: 0.99), Colors.white.withValues(alpha: 0.96)],
            ),
            border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
            boxShadow: [
              // The wide, darker cast is what lifts it off the page.
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.18),
                blurRadius: 34,
                spreadRadius: -4,
                offset: const Offset(0, 14),
              ),
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.07),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final slotWidth = constraints.maxWidth / widget.items.length;
              return Stack(
                children: [
                  _buildFlowingCapsule(slotWidth),
                  _buildSpecularHighlight(),
                  Row(
                    children: [
                      for (var i = 0; i < widget.items.length; i++)
                        Expanded(
                          child:
                              widget.items[i] == null
                                  ? _buildCenterSlotLabel()
                                  : _buildNavSlot(widget.items[i]!, i),
                        ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  /// A single tinted capsule that flows between slots, stretching along its
  /// path and squashing across it while in flight. The stretch scales with
  /// the distance travelled, so a hop to the neighbouring tab barely
  /// deforms while a jump across the bar visibly pulls.
  Widget _buildFlowingCapsule(double slotWidth) {
    return AnimatedBuilder(
      animation: _flowController,
      builder: (context, _) {
        final t = _flowController.value;
        final travel = (_toIndex - _fromIndex).abs();
        // Peaks at mid-flight and returns to 1 at both ends, so the capsule
        // is only ever deformed while it is actually moving.
        final flight = math.sin(math.pi * t) * math.min(travel / 3, 1.0);
        final stretchX = 1 + 0.38 * flight;
        final squashY = 1 - 0.14 * flight;

        // Sits behind the ICON only, not the icon and its label.
        //
        // Wrapping both made the selected slot a tall block roughly the size
        // of the whole bar interior, so one tab carried a heavy filled shape
        // while its four neighbours carried none - the selected item read as
        // a different kind of control rather than as the same control, on.
        // A compact indicator behind the icon keeps every slot the same
        // shape and size, and still travels.
        final indicatorWidth = math.min(_indicatorWidth, slotWidth - 10);
        final left = _currentSlotPosition * slotWidth + (slotWidth - indicatorWidth) / 2;

        return Positioned(
          left: left,
          top: _contentTop,
          width: indicatorWidth,
          height: _indicatorHeight,
          child: Transform.scale(
            scaleX: stretchX,
            scaleY: squashY,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(_indicatorHeight / 2),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [_accent.withValues(alpha: 0.18), _accent.withValues(alpha: 0.11)],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// The thin bright line along the top edge - the cheap trick that makes a
  /// translucent surface look like a lens instead of a sheet of plastic.
  Widget _buildSpecularHighlight() {
    return Positioned(
      left: 22,
      right: 22,
      top: 0,
      height: 1,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.white.withValues(alpha: 0),
              Colors.white,
              Colors.white.withValues(alpha: 0),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavSlot(LiquidNavItem item, int index) {
    final isSelected = widget.selectedIndex == index;
    final color = isSelected ? _accent : _idle;

    // Fixed boxes for both rows. Nothing here changes size with selection -
    // the icon used to swell 12-14% and the label jump two font weights, so
    // the selected slot occupied more room than its neighbours and the whole
    // bar shuffled sideways every time you switched tab.
    return _PressSpring(
      onTap: item.onTap,
      onLongPress: item.onLongPress,
      child: Padding(
        padding: const EdgeInsets.only(top: _contentTop),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: _indicatorHeight,
              child: Center(
                child: Badge(
                  isLabelVisible: item.badgeCount > 0,
                  label: Text('${item.badgeCount}', style: const TextStyle(fontSize: 9)),
                  backgroundColor: const Color(0xFFF04438),
                  // The outline weight cross-fades into the filled one
                  // rather than swapping between frames.
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      AnimatedOpacity(
                        opacity: isSelected ? 0 : 1,
                        duration: const Duration(milliseconds: 240),
                        child: Icon(item.icon, color: color, size: 20),
                      ),
                      AnimatedOpacity(
                        opacity: isSelected ? 1 : 0,
                        duration: const Duration(milliseconds: 240),
                        child: Icon(item.activeIcon, color: color, size: 20),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: _iconLabelGap),
            SizedBox(
              height: _labelHeight,
              child: Center(
                child: AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 240),
                  curve: Curves.easeOut,
                  style: TextStyle(
                    fontSize: 10.5,
                    // w600 both ways: only the colour marks the selection, so
                    // the label's width is identical in either state.
                    fontWeight: FontWeight.w600,
                    color: color,
                    letterSpacing: -0.1,
                    height: 1.2,
                  ),
                  child: Text(
                    item.label,
                    maxLines: 1,
                    softWrap: false,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCenterSlotLabel() {
    return _PressSpring(
      onTap: widget.onCenterTap ?? () {},
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          const SizedBox(height: 38),
          Text(
            widget.centerLabel,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: _idle,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCenterButton() {
    return _PressSpring(
      onTap: widget.onCenterTap ?? () {},
      pressedScale: 0.88,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
          ),
          boxShadow: [
            BoxShadow(
              color: _accent.withValues(alpha: 0.42),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Center(child: Icon(widget.centerIcon, color: Colors.white, size: 26)),
      ),
    );
  }
}

/// Dips under a press and springs back past its resting size on release -
/// the touch response the whole iOS 26 control set shares. Kept as its own
/// widget so each slot owns its press state instead of rebuilding the bar.
class _PressSpring extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final double pressedScale;

  const _PressSpring({
    required this.child,
    required this.onTap,
    this.onLongPress,
    this.pressedScale = 0.92,
  });

  @override
  State<_PressSpring> createState() => _PressSpringState();
}

class _PressSpringState extends State<_PressSpring> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value && mounted) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      child: AnimatedScale(
        scale: _pressed ? widget.pressedScale : 1,
        // easeOutBack on the way back up is the overshoot that reads as a
        // spring rather than as a fade.
        duration: Duration(milliseconds: _pressed ? 110 : 320),
        curve: _pressed ? Curves.easeOut : Curves.easeOutBack,
        child: widget.child,
      ),
    );
  }
}
