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
/// The slot list is always 5 wide and the entry at index [centerSlot] is
/// left null: that's the gap the protruding action button is drawn over. So
/// [selectedIndex] is the slot index directly (0, 1, 3, 4) - exactly the
/// numbering both dashboards already keep their nav state in.
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
  /// Exactly 5 entries; the one at [centerSlot] must be null.
  final List<LiquidNavItem?> items;
  final int selectedIndex;
  final String centerLabel;
  final VoidCallback onCenterTap;
  final IconData centerIcon;

  static const int centerSlot = 2;

  const LiquidNavBar({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onCenterTap,
    this.centerLabel = 'New',
    this.centerIcon = Icons.add_rounded,
  }) : assert(items.length == 5);

  @override
  State<LiquidNavBar> createState() => _LiquidNavBarState();
}

class _LiquidNavBarState extends State<LiquidNavBar> with SingleTickerProviderStateMixin {
  static const Color _accent = Color(0xFF4F46E5);
  static const Color _idle = Color(0xFF334155);
  static const double _barHeight = 78;

  late final AnimationController _flowController;
  // Fractional, because a redirected flight takes off from a position
  // between two slots.
  late double _fromIndex;
  late int _toIndex;

  @override
  void initState() {
    super.initState();
    _fromIndex = widget.selectedIndex.toDouble();
    _toIndex = widget.selectedIndex;
    _flowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 460),
      value: 1,
    );
  }

  @override
  void didUpdateWidget(LiquidNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedIndex != _toIndex) {
      // Take off from wherever the capsule actually is rather than from the
      // last settled slot, so tapping mid-flight redirects it instead of
      // snapping it back to start the new trip.
      _fromIndex = _currentSlotPosition;
      _toIndex = widget.selectedIndex;
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
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.only(left: 18, right: 18, bottom: 12, top: 16),
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            _buildGlassBar(),
            Positioned(top: -18, child: _buildCenterButton()),
          ],
        ),
      ),
    );
  }

  Widget _buildGlassBar() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: BackdropFilter(
        // The blur is what makes the bar read as glass rather than as a flat
        // white pill: the scaffold sets extendBody, so page content really
        // does pass underneath it.
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          height: _barHeight,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(32),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.white.withValues(alpha: 0.92),
                Colors.white.withValues(alpha: 0.82),
              ],
            ),
            border: Border.all(color: Colors.white.withValues(alpha: 0.75), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.10),
                blurRadius: 28,
                offset: const Offset(0, 10),
              ),
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                blurRadius: 6,
                offset: const Offset(0, 2),
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
                          child: widget.items[i] == null
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

        final capsuleWidth = slotWidth - 10;
        final left = _currentSlotPosition * slotWidth + 5;

        return Positioned(
          left: left,
          top: 9,
          width: capsuleWidth,
          height: _barHeight - 20,
          child: Transform.scale(
            scaleX: stretchX,
            scaleY: squashY,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    _accent.withValues(alpha: 0.14),
                    _accent.withValues(alpha: 0.07),
                  ],
                ),
                border: Border.all(color: _accent.withValues(alpha: 0.16)),
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

    return _PressSpring(
      onTap: item.onTap,
      onLongPress: item.onLongPress,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // The icon lifts and swells as the capsule arrives under it, and
            // its outline weight cross-fades into the filled one rather than
            // swapping between frames.
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: isSelected ? 1 : 0),
              duration: const Duration(milliseconds: 420),
              curve: Curves.easeOutBack,
              builder: (context, v, child) => Transform.translate(
                offset: Offset(0, -2.5 * v),
                child: Transform.scale(scale: 1 + 0.14 * v, child: child),
              ),
              child: Badge(
                isLabelVisible: item.badgeCount > 0,
                label: Text('${item.badgeCount}', style: const TextStyle(fontSize: 10)),
                backgroundColor: const Color(0xFFF04438),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    AnimatedOpacity(
                      opacity: isSelected ? 0 : 1,
                      duration: const Duration(milliseconds: 260),
                      child: Icon(item.icon, color: color, size: 23),
                    ),
                    AnimatedOpacity(
                      opacity: isSelected ? 1 : 0,
                      duration: const Duration(milliseconds: 260),
                      child: Icon(item.activeIcon, color: color, size: 23),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 4),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOut,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: color,
                letterSpacing: -0.2,
              ),
              child: Text(item.label),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCenterSlotLabel() {
    return _PressSpring(
      onTap: widget.onCenterTap,
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
      onTap: widget.onCenterTap,
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
        child: Center(
          child: Icon(widget.centerIcon, color: Colors.white, size: 26),
        ),
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
