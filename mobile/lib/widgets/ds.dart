import 'package:flutter/material.dart';

import '../theme.dart';

/// The design system's building blocks for the deep-teal look the whole
/// app is moving to (see the palette notes in theme.dart).
///
/// Rules these encode, so screens don't each reinvent them:
///  * one card style - white, 1px border, 14 radius, no shadow;
///  * teal for anything you act on (buttons, links, progress, selection);
///  * one soft tinted icon tile per kind of figure (teal / blue / amber /
///    rose), flat - never a gradient, never a glow;
///  * green / amber / red only for status.

/// A plain bordered surface. [onTap] makes the whole card one target.
class DsCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  const DsCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.onTap});

  @override
  Widget build(BuildContext context) {
    final body = Padding(padding: padding, child: child);
    return Material(
      color: AppTheme.cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppTheme.borderSubtle),
      ),
      clipBehavior: Clip.antiAlias,
      child: onTap == null ? body : InkWell(onTap: onTap, child: body),
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
              width: 32,
              height: 32,
              decoration: BoxDecoration(color: tintBg, borderRadius: BorderRadius.circular(9)),
              child: Icon(icon, size: 17, color: tint),
            ),
            const SizedBox(height: 12),
          ],
          Text(label, style: const TextStyle(fontSize: 12.5, color: AppTheme.slateLight)),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: tone ?? AppTheme.slateDark,
              letterSpacing: -0.5,
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
