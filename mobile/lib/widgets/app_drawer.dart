import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../theme.dart';

/// One destination in the drawer.
class AppDrawerItem {
  final IconData icon;
  final String label;
  final String? trailingText;
  final int badgeCount;
  final bool selected;
  final VoidCallback onTap;

  const AppDrawerItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.trailingText,
    this.badgeCount = 0,
    this.selected = false,
  });
}

/// A labelled group of destinations. Grouping is the point: the old sidebar
/// was a flat list of twelve equally-weighted rows, which gives no hint that
/// "Attendance" and "Expenses" are different kinds of thing, or that most of
/// the list is visited once a month rather than once an hour.
class AppDrawerSection {
  final String title;
  final List<AppDrawerItem> items;

  const AppDrawerSection({required this.title, required this.items});
}

/// The app's single drawer, shared by the owner and employee shells.
///
/// It is reached one way only - the "Menu" slot at the end of the bottom bar
/// - so there is no question of whether a given screen has a drawer, a
/// hamburger, or a bottom sheet with the same contents. It previously had
/// all three: the owner got a bottom-sheet grid, the employee got a drawer,
/// and the desktop layout got a permanent sidebar with a different ordering
/// again.
class AppDrawer extends StatelessWidget {
  final String title;
  final String subtitle;
  final String avatarInitials;
  final List<AppDrawerSection> sections;
  final VoidCallback onLogout;

  /// Shown above the sections - the account row, tapped to open the profile.
  final VoidCallback? onProfileTap;

  /// When false the drawer renders as a plain panel for the desktop layout,
  /// where it is pinned beside the content instead of sliding over it.
  final bool isModal;

  const AppDrawer({
    super.key,
    required this.title,
    required this.subtitle,
    required this.avatarInitials,
    required this.sections,
    required this.onLogout,
    this.onProfileTap,
    this.isModal = true,
  });

  @override
  Widget build(BuildContext context) {
    final panel = Container(
      width: 292,
      decoration: BoxDecoration(
        color: Colors.white,
        border: isModal
            ? null
            : const Border(right: BorderSide(color: AppTheme.borderSubtle, width: 1)),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildAccountRow(),
            const Divider(height: 1, color: AppTheme.borderSubtle),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 14, 12, 8),
                children: [
                  for (final section in sections) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
                      child: Text(
                        section.title.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textMuted,
                          letterSpacing: 0.9,
                        ),
                      ),
                    ),
                    for (final item in section.items) _buildItem(item),
                    const SizedBox(height: 10),
                  ],
                ],
              ),
            ),
            const Divider(height: 1, color: AppTheme.borderSubtle),
            Padding(
              padding: const EdgeInsets.all(14.0),
              child: SizedBox(
                width: double.infinity,
                height: 44,
                child: OutlinedButton.icon(
                  onPressed: onLogout,
                  icon: const Icon(PhosphorIconsRegular.signOut, size: 17, color: AppTheme.accentRed),
                  label: const Text(
                    'Log Out',
                    style: TextStyle(
                      color: AppTheme.accentRed,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFFECDCA)),
                    backgroundColor: AppTheme.accentRedBg,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    return isModal ? Drawer(width: 292, child: panel) : panel;
  }

  Widget _buildAccountRow() {
    final row = Padding(
      padding: const EdgeInsets.fromLTRB(18, 18, 14, 18),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: Color(0xFF1E1B4B),
              shape: BoxShape.circle,
            ),
            child: Text(
              avatarInitials,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: AppTheme.slateDark,
                    letterSpacing: -0.3,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppTheme.slateLight,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (onProfileTap != null)
            const Icon(PhosphorIconsBold.caretRight, size: 15, color: AppTheme.textMuted),
        ],
      ),
    );

    if (onProfileTap == null) return row;
    return InkWell(onTap: onProfileTap, child: row);
  }

  Widget _buildItem(AppDrawerItem item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3.0),
      child: InkWell(
        onTap: item.onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
          decoration: BoxDecoration(
            color: item.selected ? AppTheme.primaryLight : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                item.icon,
                size: 19,
                color: item.selected ? AppTheme.primaryBlue : AppTheme.slateLight,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  item.label,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: item.selected ? FontWeight.w700 : FontWeight.w600,
                    color: item.selected ? AppTheme.primaryBlue : AppTheme.slateMedium,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (item.trailingText != null && item.badgeCount == 0)
                Text(
                  item.trailingText!,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textMuted,
                  ),
                ),
              if (item.badgeCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.accentRed,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${item.badgeCount}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
