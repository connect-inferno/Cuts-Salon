import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../theme.dart';

/// The one header every page in the app wears.
///
/// Before this existed each screen drew its own top bar: Billing had a bare
/// back arrow and a title, Customers and Inventory each carried their own
/// copy of a "salon name + bell + avatar" row, Settings had a third variant
/// with a hardcoded subtitle. They disagreed on height, on what the leading
/// slot meant, and on which actions were even present - which is most of
/// why moving between pages felt like moving between different apps.
///
/// The contract is deliberately narrow so the pages can't drift again:
///
///  * **Leading** is the page's relationship to the rest of the app, not a
///    free slot. A top-level page shows the salon mark ([AppPageLeading.mark]);
///    anything pushed on top of one shows a back arrow
///    ([AppPageLeading.back]). There is no third option.
///  * **Title + subtitle** is where the page says what it is and what
///    scope it's showing (branch, filter, count).
///  * **Actions** are capped at two, and by convention they are the bell
///    and the section gear - in that order. Everything else a page can do
///    belongs *inside* the gear sheet, not spread across the header.
enum AppPageLeading { mark, back, none }

class AppPageAction {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final int badgeCount;

  const AppPageAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.badgeCount = 0,
  });
}

class AppPageHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final AppPageLeading leading;
  final VoidCallback? onLeadingTap;
  final List<AppPageAction> actions;

  /// Draws the hairline under the header. Pages that scroll their own
  /// content under a pinned header want it; pages where the header is the
  /// first item of a scroll view generally don't.
  final bool showDivider;

  const AppPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.leading = AppPageLeading.mark,
    this.onLeadingTap,
    this.actions = const [],
    this.showDivider = true,
  }) : assert(actions.length <= 2, 'Move extra actions into the section gear sheet');

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: showDivider
            ? const Border(bottom: BorderSide(color: AppTheme.borderSubtle, width: 1))
            : null,
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
          child: Row(
            children: [
              _buildLeading(context),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.slateDark,
                        letterSpacing: -0.3,
                        height: 1.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitle != null && subtitle!.isNotEmpty)
                      Text(
                        subtitle!,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: AppTheme.slateLight,
                          height: 1.35,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              for (final action in actions) ...[
                const SizedBox(width: 4),
                _AppHeaderIconButton(action: action),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLeading(BuildContext context) {
    switch (leading) {
      case AppPageLeading.none:
        return const SizedBox(width: 4);
      case AppPageLeading.back:
        return _AppHeaderIconButton(
          action: AppPageAction(
            icon: PhosphorIconsBold.arrowLeft,
            tooltip: 'Back',
            onTap: onLeadingTap ?? () => Navigator.of(context).maybePop(),
          ),
        );
      case AppPageLeading.mark:
        // A top-level page leads with its title alone. The tinted shop badge
        // that used to sit here repeated on every page and said nothing the
        // title didn't. Kept as a quiet icon only when a page makes it do
        // something (onLeadingTap).
        if (onLeadingTap == null) return const SizedBox(width: 4);
        return _AppHeaderIconButton(
          action: AppPageAction(
            icon: PhosphorIconsRegular.storefront,
            tooltip: 'Salon',
            onTap: onLeadingTap!,
          ),
        );
    }
  }
}

class _AppHeaderIconButton extends StatelessWidget {
  final AppPageAction action;

  const _AppHeaderIconButton({required this.action});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: action.tooltip,
      child: InkWell(
        onTap: action.onTap,
        borderRadius: BorderRadius.circular(10),
        // Plain icon, no grey tile behind it - the tiles made every header
        // read as a row of buttons competing with the title.
        child: SizedBox(
          width: 40,
          height: 40,
          child: Badge(
            isLabelVisible: action.badgeCount > 0,
            label: Text('${action.badgeCount}', style: const TextStyle(fontSize: 9)),
            backgroundColor: AppTheme.accentRed,
            alignment: const AlignmentDirectional(0.5, -0.5),
            child: Center(child: Icon(action.icon, size: 21, color: AppTheme.slateDark)),
          ),
        ),
      ),
    );
  }
}
