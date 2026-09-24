import 'package:flutter/material.dart';
import '../theme.dart';

enum StyluxLogoVariant {
  /// Icon only without wordmark
  iconOnly,

  /// Horizontal: [Icon] Stylux
  inline,

  /// Vertical centered: [Icon] \n STYLUX (for Splash & Hero screens)
  stacked,
}

/// Clean Minimalist Emblem for Stylux
class StyluxLogoMark extends StatelessWidget {
  final double size;
  final bool hasGlow;

  const StyluxLogoMark({
    super.key,
    this.size = 96,
    this.hasGlow = false,
  });

  @override
  Widget build(BuildContext context) {
    final radius = size * 0.24;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: hasGlow
            ? [
                BoxShadow(
                  color: const Color(0xFF4F46E5).withValues(alpha: 0.35),
                  blurRadius: size * 0.25,
                  offset: Offset(0, size * 0.1),
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Image.asset(
          'assets/images/stylux_icon.png',
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Center(
            child: Text(
              'S',
              style: TextStyle(fontFamily: 'Plus Jakarta Sans', 
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: size * 0.55,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Unified Stylux Brand Logo Widget
class StyluxLogo extends StatelessWidget {
  final StyluxLogoVariant variant;
  final double iconSize;
  final double? fontSize;
  final Color? textColor;
  final Color? subtitleColor;
  final String? subtitle;
  final bool isDark;
  final VoidCallback? onTap;

  const StyluxLogo({
    super.key,
    this.variant = StyluxLogoVariant.inline,
    this.iconSize = 36,
    this.fontSize,
    this.textColor,
    this.subtitleColor,
    this.subtitle,
    this.isDark = false,
    this.onTap,
  });

  /// App bar header variant
  factory StyluxLogo.appBar({bool isDark = false, VoidCallback? onTap}) {
    return StyluxLogo(
      variant: StyluxLogoVariant.inline,
      iconSize: 32,
      fontSize: 18,
      isDark: isDark,
      onTap: onTap,
    );
  }

  /// Splash / Launch screen prominent centered logo
  factory StyluxLogo.splash({
    double iconSize = 96,
    double fontSize = 28,
    String? subtitle = 'SALON MANAGEMENT OS',
  }) {
    return StyluxLogo(
      variant: StyluxLogoVariant.stacked,
      iconSize: iconSize,
      fontSize: fontSize,
      subtitle: subtitle,
      isDark: true,
    );
  }

  /// Hero / Login screen variant
  factory StyluxLogo.hero({
    String? subtitle = 'Salon Management OS',
    bool isDark = false,
  }) {
    return StyluxLogo(
      variant: StyluxLogoVariant.stacked,
      iconSize: 64,
      fontSize: 26,
      subtitle: subtitle,
      isDark: isDark,
    );
  }

  @override
  Widget build(BuildContext context) {
    final titleColor = textColor ?? (isDark ? Colors.white : AppTheme.slateDark);
    final subColor = subtitleColor ?? (isDark ? const Color(0xFF94A3B8) : AppTheme.slateLight);
    final calculatedFontSize = fontSize ?? (variant == StyluxLogoVariant.stacked ? 24.0 : 18.0);

    if (variant == StyluxLogoVariant.iconOnly) {
      return StyluxLogoMark(size: iconSize);
    }

    final wordmark = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: variant == StyluxLogoVariant.stacked
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        Text(
          'STYLUX',
          style: TextStyle(fontFamily: 'Plus Jakarta Sans', 
            fontSize: calculatedFontSize,
            fontWeight: FontWeight.w800,
            letterSpacing: 2.0,
            color: titleColor,
            height: 1.1,
          ),
        ),
        if (subtitle != null && subtitle!.isNotEmpty) ...[
          SizedBox(height: variant == StyluxLogoVariant.stacked ? 6 : 2),
          Text(
            subtitle!,
            style: TextStyle(fontFamily: 'Plus Jakarta Sans', 
              fontSize: (calculatedFontSize * 0.44).clamp(9.0, 13.0),
              fontWeight: FontWeight.w600,
              letterSpacing: 1.4,
              color: subColor,
            ),
          ),
        ],
      ],
    );

    Widget content;
    if (variant == StyluxLogoVariant.stacked) {
      content = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          StyluxLogoMark(size: iconSize),
          SizedBox(height: iconSize * 0.22),
          wordmark,
        ],
      );
    } else {
      content = Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          StyluxLogoMark(size: iconSize),
          const SizedBox(width: 12),
          Flexible(child: wordmark),
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
