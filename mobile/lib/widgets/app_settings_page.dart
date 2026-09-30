import 'package:flutter/material.dart';
import '../router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../theme.dart';
import 'app_page_header.dart';

/// One section inside a page's settings.
///
/// [builder] is lazy so a section that loads a long list (dues, discount
/// requests) isn't built until it's actually looked at.
class AppSettingsSection {
  final IconData icon;
  final String label;

  /// Shown under the tab strip as the section's one-line explanation.
  final String description;
  final int badgeCount;
  final WidgetBuilder builder;

  const AppSettingsSection({
    required this.icon,
    required this.label,
    required this.description,
    required this.builder,
    this.badgeCount = 0,
  });
}

/// A page's settings: one surface holding everything that belongs to that
/// section of the app.
///
/// The rule this exists to enforce is that a section's settings are *one
/// place*, not a signpost to several. Billing's tax rate, price list,
/// outstanding dues and discount approvals were four separate top-level
/// pages; they are now four sections of this single screen, switched with
/// the strip at the top. Opening one doesn't navigate anywhere, so there is
/// never a stack of pages to unwind - one back arrow returns to the section
/// you came from, from anywhere inside.
class AppSettingsPage extends StatefulWidget {
  final String title;
  final String? subtitle;
  final List<AppSettingsSection> sections;
  final int initialSection;

  const AppSettingsPage({
    super.key,
    required this.title,
    this.subtitle,
    required this.sections,
    this.initialSection = 0,
  }) : assert(sections.length > 0);

  @override
  State<AppSettingsPage> createState() => _AppSettingsPageState();
}

/// The description line under the tab strip is reserved at exactly this many
/// lines so the strip's height never depends on which section is selected.
/// Two is enough for every description in the app at phone width; anything
/// longer is a description that should be shortened at the call site rather
/// than allowed to move the page.
const int _kDescriptionLines = 2;
const double _kDescriptionFontSize = 11.5;
const double _kDescriptionLineHeight = _kDescriptionFontSize * 1.35;

class _AppSettingsPageState extends State<AppSettingsPage> {
  late int _active;

  @override
  void initState() {
    super.initState();
    _active = widget.initialSection.clamp(0, widget.sections.length - 1);
  }

  @override
  Widget build(BuildContext context) {
    final section = widget.sections[_active];

    return Scaffold(
      backgroundColor: AppTheme.bgSurface,
      body: Column(
        children: [
          AppPageHeader(
            title: widget.title,
            subtitle: widget.subtitle,
            leading: AppPageLeading.back,
            showDivider: false,
          ),
          Container(
            color: Colors.white,
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Row(
                    children: [
                      for (var i = 0; i < widget.sections.length; i++)
                        Padding(
                          // Trailing gap on the last pill too, so a strip
                          // that scrolls does not come to rest with the final
                          // pill flush against the edge of the screen.
                          padding: EdgeInsets.only(
                            right: i == widget.sections.length - 1 ? 14.0 : 8.0,
                          ),
                          child: _buildTab(widget.sections[i], i),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
                  // Fixed at two lines, always.
                  //
                  // This used to size to whatever the selected section's
                  // description happened to need. Descriptions carry live
                  // numbers ("₹12,450 billed but not collected, across 7
                  // clients"), so one section wrapped to two lines and
                  // another did not - and switching tabs moved the divider,
                  // the content below it and the scroll position underneath
                  // the finger that had just tapped. Reserving the taller of
                  // the two makes the strip a fixed height whatever is
                  // selected, so only the content below it changes.
                  child: SizedBox(
                    height: _kDescriptionLines * _kDescriptionLineHeight,
                    width: double.infinity,
                    child: Text(
                      section.description,
                      maxLines: _kDescriptionLines,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: _kDescriptionFontSize,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.slateLight,
                        height: 1.35,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppTheme.borderSubtle),
          Expanded(
            // Keyed so switching sections rebuilds from scratch rather than
            // letting one section's scroll position or filter state bleed
            // into the next.
            child: KeyedSubtree(
              key: ValueKey(_active),
              child: Builder(builder: section.builder),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(AppSettingsSection section, int index) {
    final selected = _active == index;

    return InkWell(
      onTap: () => setState(() => _active = index),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primaryBlue : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              section.icon,
              size: 15,
              color: selected ? Colors.white : AppTheme.slateLight,
            ),
            const SizedBox(width: 6),
            Text(
              section.label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : AppTheme.slateMedium,
              ),
            ),
            if (section.badgeCount > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: selected ? Colors.white.withValues(alpha: 0.25) : AppTheme.accentRed,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${section.badgeCount}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Opens a section's settings. Every gear button in the app calls this, so
/// the shape is the same wherever you press it.
Future<void> openAppSettings(
  BuildContext context, {
  required String title,
  String? subtitle,
  required List<AppSettingsSection> sections,
  int initialSection = 0,
}) {
  return pushAppRoute<void>(
    context,
    AppSettingsPage(
      title: title,
      subtitle: subtitle,
      sections: sections,
      initialSection: initialSection,
    ),
  );
}

/// The gear icon itself, so every page hangs its settings off an identical
/// control rather than each inventing its own affordance.
AppPageAction appSettingsAction({
  required VoidCallback onTap,
  int badgeCount = 0,
  String tooltip = 'Settings',
}) {
  return AppPageAction(
    icon: PhosphorIconsRegular.gearSix,
    tooltip: tooltip,
    onTap: onTap,
    badgeCount: badgeCount,
  );
}
