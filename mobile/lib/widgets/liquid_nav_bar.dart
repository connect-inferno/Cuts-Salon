import 'package:flutter/material.dart';


/// The bottom bar shared by the owner and employee dashboards.
///
/// A plain bar docked to the bottom edge: white, a hairline on top, the
/// current tab in brand teal and the rest in grey. It used to be a floating
/// "liquid glass" capsule with a stretching, bouncing indicator, blur and a
/// specular highlight - impressive in a demo, but it was the single most
/// "generated-looking" thing in the app and it drew the eye away from the
/// page above it. The class keeps its old name so callers didn't change.
///
/// The slot list is always 5 wide, and [selectedIndex] is the slot index
/// directly - exactly the numbering both dashboards keep their nav state in.
/// If [onCenterTap] is supplied, the entry at [centerSlot] must be null and
/// that slot carries the action button instead.
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

  /// How much vertical space the bar occupies above the safe area.
  ///
  /// The footer is transparent, so page content scrolls underneath the
  /// whole assembly. Any scrollable on a screen that shows this bar wants
  /// this as bottom padding, or its last row is permanently parked behind
  /// the capsule. Add MediaQuery's bottom padding to it on a device with a
  /// home indicator.
  static const double barInset = 72;

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

class _LiquidNavBarState extends State<LiquidNavBar> {
  static const Color _active = Color(0xFF0F766E);
  static const Color _idle = Color(0xFF667085);
  static const double _barHeight = 62;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE4E8EF))),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: _barHeight,
          child: Row(
            children: [
              for (var i = 0; i < widget.items.length; i++)
                Expanded(
                  child: widget.items[i] == null
                      ? _buildCenterAction()
                      : _buildSlot(widget.items[i]!, i == widget.selectedIndex),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSlot(LiquidNavItem item, bool selected) {
    final color = selected ? _active : _idle;
    return Semantics(
      selected: selected,
      button: true,
      label: item.label,
      child: InkResponse(
        onTap: item.onTap,
        onLongPress: item.onLongPress,
        radius: 32,
        highlightColor: Colors.transparent,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // A soft teal pill behind the current tab's icon - enough to find
            // your place at a glance, without the old travelling capsule.
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
              decoration: BoxDecoration(
                color: selected ? const Color(0xFFF0FDFA) : Colors.transparent,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Badge(
                isLabelVisible: item.badgeCount > 0,
                label: Text('${item.badgeCount}', style: const TextStyle(fontSize: 9)),
                backgroundColor: const Color(0xFFDC2626),
                child: Icon(selected ? item.activeIcon : item.icon, size: 22, color: color),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              item.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCenterAction() {
    final onTap = widget.onCenterTap;
    if (onTap == null) return const SizedBox.shrink();
    return Center(
      child: Material(
        color: _active,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(widget.centerIcon, color: Colors.white, size: 22),
          ),
        ),
      ),
    );
  }
}
