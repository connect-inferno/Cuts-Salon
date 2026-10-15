import 'package:flutter/material.dart';

import '../theme.dart';

/// The design system's building blocks for the deep-navy look (see the
/// palette notes in theme.dart).
///
/// Rules these encode, so screens don't each reinvent them:
///  * one card style - white, hairline border, 16 radius, the barely-there
///    AppTheme.cardShadow;
///  * navy for anything you act on (buttons, links, progress, selection);
///  * icon tiles in one quiet navy tint - flat, never a gradient or glow;
///  * amber / red (and muted green for "paid") only for status;
///  * small uppercase section labels (DsSectionLabel) to group cards.

/// A plain bordered surface. [onTap] makes the whole card one target, and
/// then it lifts slightly under the pointer so it reads as pressable.
class DsCard extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  const DsCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.onTap});

  @override
  State<DsCard> createState() => _DsCardState();
}

class _DsCardState extends State<DsCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final padding = widget.padding;
    final child = widget.child;
    final onTap = widget.onTap;
    final body = Padding(padding: padding, child: child);
    final lifted = _hover && onTap != null;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      transform: Matrix4.translationValues(0, lifted ? -1.5 : 0, 0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: lifted
            ? [
                BoxShadow(color: const Color(0xFF101828).withValues(alpha: 0.06), blurRadius: 4, offset: const Offset(0, 2)),
                BoxShadow(color: const Color(0xFF101828).withValues(alpha: 0.08), blurRadius: 18, offset: const Offset(0, 8)),
              ]
            : AppTheme.cardShadow,
      ),
      child: Material(
        color: AppTheme.cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppTheme.borderSubtle),
        ),
        clipBehavior: Clip.antiAlias,
        child: onTap == null
            ? body
            : InkWell(
                onTap: onTap,
                hoverColor: Colors.transparent,
                highlightColor: AppTheme.primaryLight.withValues(alpha: 0.7),
                splashColor: Colors.transparent,
                child: body,
              ),
      ),
      ),
    );
  }
}

/// A small uppercase label above a group of cards ("TODAY", "OVERVIEW") -
/// gives a long page a structure you can scan without adding more boxes.
class DsSectionLabel extends StatelessWidget {
  final String text;
  final Widget? trailing;

  const DsSectionLabel(this.text, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text.toUpperCase(),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppTheme.slateLight,
                letterSpacing: 0.9,
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// One row of a list inside a DsCard: leading avatar/icon, title, subtitle
/// and an optional trailing value, with a chevron when tappable.
class DsListRow extends StatelessWidget {
  final Widget? leading;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  /// Rows whose trailing area already holds buttons can drop the chevron.
  final bool showChevron;

  const DsListRow({
    super.key,
    this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.showChevron = true,
  });

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 12)],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.slateDark)),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12.5, color: AppTheme.slateLight)),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 10), trailing!],
          if (onTap != null && showChevron) ...[
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right_rounded, size: 20, color: AppTheme.textMuted),
          ],
        ],
      ),
    );
    return onTap == null
        ? row
        : InkWell(
            onTap: onTap,
            hoverColor: AppTheme.primaryLight.withValues(alpha: 0.5),
            highlightColor: AppTheme.primaryLight,
            splashColor: Colors.transparent,
            child: row,
          );
  }
}

/// Initials in a soft coloured circle - the avatar for people across the app.
class DsAvatar extends StatelessWidget {
  final String name;
  final double size;

  const DsAvatar(this.name, {super.key, this.size = 38});

  @override
  Widget build(BuildContext context) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    final initials = parts.isEmpty ? '?' : parts.take(2).map((p) => p[0].toUpperCase()).join();
    // Same name -> same colour, everywhere in the app.
    final (bg, fg) = AppTheme.avatarColorsFor(name);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      child: Text(initials, style: TextStyle(fontSize: size * 0.34, fontWeight: FontWeight.w700, color: fg)),
    );
  }
}

/// A card's or section's title, with an optional text action on the right.
class DsSectionTitle extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  const DsSectionTitle(this.title, {super.key, this.actionLabel, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppTheme.slateDark,
              letterSpacing: -0.2,
            ),
          ),
        ),
        if (actionLabel != null)
          InkWell(
            onTap: onAction,
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Text(
                actionLabel!,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.primaryBlue),
              ),
            ),
          ),
      ],
    );
  }
}

/// A label over a number, with an optional soft icon tile ([icon] on
/// [tintBg], drawn in [tint]). [tone] colours the number itself only when it
/// means something (e.g. red for "3 items low on stock").
class DsStat extends StatelessWidget {
  final String label;
  final String value;
  final String? caption;
  final Color? tone;
  final IconData? icon;
  final Color tint;
  final Color tintBg;
  final VoidCallback? onTap;

  const DsStat({
    super.key,
    required this.label,
    required this.value,
    this.caption,
    this.tone,
    this.icon,
    this.tint = AppTheme.tintTeal,
    this.tintBg = AppTheme.tintTealBg,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(color: tintBg, borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, size: 18, color: tint),
            ),
            const SizedBox(height: 14),
          ],
          Text(label, style: const TextStyle(fontSize: 12.5, color: AppTheme.slateLight)),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: tone ?? AppTheme.slateDark,
              letterSpacing: -0.6,
              fontFeatures: const [FontFeature.tabularFigures()],
              height: 1.1,
            ),
          ),
          if (caption != null) ...[
            const SizedBox(height: 4),
            Text(caption!, style: const TextStyle(fontSize: 11.5, color: AppTheme.textMuted)),
          ],
        ],
      ),
    );
    if (onTap == null) return content;
    return InkWell(onTap: onTap, child: content);
  }
}

/// One line of a key/value list: label on the left, value on the right.
class DsValueRow extends StatelessWidget {
  final String label;
  final String value;
  final bool emphasise;
  final Color? valueColor;
  /// A small coloured dot before the label, for lists where each row is a
  /// different kind of thing (payment methods, categories).
  final Color? dot;

  const DsValueRow({
    super.key,
    required this.label,
    required this.value,
    this.emphasise = false,
    this.valueColor,
    this.dot,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          if (dot != null) ...[
            Container(width: 8, height: 8, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: emphasise ? FontWeight.w600 : FontWeight.w400,
                color: emphasise ? AppTheme.slateDark : AppTheme.slateMedium,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: valueColor ?? AppTheme.slateDark,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

/// A thin progress line - teal on light teal, green once complete.
class DsProgressBar extends StatelessWidget {
  final double value;

  const DsProgressBar({super.key, required this.value});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: LinearProgressIndicator(
        value: value.clamp(0.0, 1.0),
        minHeight: 5,
        backgroundColor: AppTheme.primaryLight,
        color: value >= 1 ? AppTheme.accentGreen : AppTheme.primaryBlue,
      ),
    );
  }
}

/// A compact figure: icon tile on the left, label over value on the right.
/// Half the height of DsStat, for a grid of several figures in one card.
class DsStatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? caption;
  /// Colours the value (and icon) when the number itself is a warning.
  final Color? tone;
  /// The icon tile's colour pair - one per kind of figure.
  final Color tint;
  final Color tintBg;
  final VoidCallback? onTap;

  const DsStatTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.caption,
    this.tone,
    this.tint = AppTheme.primaryBlue,
    this.tintBg = AppTheme.primaryLight,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: tone == null ? tintBg : tone!.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: tone ?? tint),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: AppTheme.slateLight)),
                const SizedBox(height: 2),
                Text.rich(
                  TextSpan(children: [
                    TextSpan(
                      text: value,
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        color: tone ?? AppTheme.slateDark,
                        letterSpacing: -0.4,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    if (caption != null)
                      TextSpan(
                        text: '  $caption',
                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500, color: AppTheme.textMuted),
                      ),
                  ]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return content;
    // A light navy wash on hover, not Material's grey - grey on one cell of
    // a white card read as a stuck or disabled state.
    return InkWell(
      onTap: onTap,
      hoverColor: AppTheme.primaryLight.withValues(alpha: 0.6),
      highlightColor: AppTheme.primaryLight,
      splashColor: Colors.transparent,
      child: content,
    );
  }
}

/// A small status pill ("Paid", "Due ₹200", "In since 9:40").
class DsPill extends StatelessWidget {
  final String text;
  final Color color;

  const DsPill(this.text, {super.key, this.color = AppTheme.slateLight});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.09), borderRadius: BorderRadius.circular(20)),
      child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }
}
