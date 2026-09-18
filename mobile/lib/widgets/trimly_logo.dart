import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme.dart';

enum TrimlyLogoVariant {
  /// Horizontal: [Icon] Trimly (with optional subtitle beneath)
  inline,

  /// Vertical centered: [Icon] \n Trimly \n Subtitle
  stacked,

  /// Just the icon mark / badge
  iconOnly,
}

class TrimlyLogo extends StatelessWidget {
  final TrimlyLogoVariant variant;
  final double iconSize;
  final double? fontSize;
  final String? subtitle;
  final Color? textColor;
  final Color? subtitleColor;
  final bool isDark;
  final VoidCallback? onTap;

  const TrimlyLogo({
    super.key,
    this.variant = TrimlyLogoVariant.inline,
    this.iconSize = 32,
    this.fontSize,
    this.subtitle,
    this.textColor,
    this.subtitleColor,
    this.isDark = false,
    this.onTap,
  });

  /// Standard compact header/appbar logo
  factory TrimlyLogo.appBar({
    Key? key,
    String? subtitle,
    Color? textColor,
  }) {
    return TrimlyLogo(
      key: key,
      variant: TrimlyLogoVariant.inline,
      iconSize: 28,
      fontSize: 18,
      subtitle: subtitle,
      textColor: textColor,
    );
  }

  /// Sidebar top branding logo
  factory TrimlyLogo.sidebar({
    Key? key,
    String? subtitle = 'Salon OS',
    Color? textColor,
  }) {
    return TrimlyLogo(
      key: key,
      variant: TrimlyLogoVariant.inline,
      iconSize: 34,
      fontSize: 17,
      subtitle: subtitle,
      textColor: textColor,
    );
  }

  /// Large hero logo for login/splash
  factory TrimlyLogo.hero({
    Key? key,
    String? subtitle = 'Salon Management Made Simple',
  }) {
    return TrimlyLogo(
      key: key,
      variant: TrimlyLogoVariant.stacked,
      iconSize: 64,
      fontSize: 28,
      subtitle: subtitle,
    );
  }

  @override
  Widget build(BuildContext context) {
    final effectiveTextColor = textColor ?? (isDark ? Colors.white : AppTheme.slateDark);
    final effectiveSubtitleColor =
        subtitleColor ?? (isDark ? Colors.white70 : AppTheme.slateLight);
    final calculatedFontSize = fontSize ?? (iconSize * 0.58).clamp(14.0, 32.0);

    Widget iconWidget = ClipRRect(
      borderRadius: BorderRadius.circular(iconSize * 0.28),
      child: Image.asset(
        'assets/images/trimly_icon.png',
        width: iconSize,
        height: iconSize,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          // Fallback vector container with styling
          return Container(
            width: iconSize,
            height: iconSize,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(iconSize * 0.28),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF4F46E5).withValues(alpha: 0.25),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: Text(
                'T',
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: iconSize * 0.55,
                ),
              ),
            ),
          );
        },
      ),
    );

    if (variant == TrimlyLogoVariant.iconOnly) {
      return iconWidget;
    }

    final textColumn = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: variant == TrimlyLogoVariant.stacked
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        Text(
          'Trimly',
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.plusJakartaSans(
            fontSize: calculatedFontSize,
            fontWeight: FontWeight.w800,
            color: effectiveTextColor,
            letterSpacing: -0.6,
          ),
        ),
        if (subtitle != null && subtitle!.isNotEmpty) ...[
          const SizedBox(height: 1),
          Text(
            subtitle!,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.plusJakartaSans(
              fontSize: (calculatedFontSize * 0.60).clamp(9.5, 14.0),
              fontWeight: FontWeight.w600,
              color: effectiveSubtitleColor,
              letterSpacing: -0.1,
            ),
          ),
        ],
      ],
    );

    Widget content;
    if (variant == TrimlyLogoVariant.stacked) {
      content = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          iconWidget,
          const SizedBox(height: 12),
          textColumn,
        ],
      );
    } else {
      content = Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          iconWidget,
          SizedBox(width: iconSize * 0.28),
          Flexible(child: textColumn),
        ],
      );
    }

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: content,
      );
    }

    return content;
  }
}
