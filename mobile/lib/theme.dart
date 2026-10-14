import 'package:flutter/material.dart';

// Plus Jakarta Sans is bundled locally (see pubspec.yaml `fonts:`) rather
// than fetched at runtime via the google_fonts package - a slow/blocked
// connection to Google's CDN would otherwise make the whole app silently
// fall back to the platform default font instead of matching the Stitch
// design's weights.
TextStyle _pjs({
  required double fontSize,
  FontWeight fontWeight = FontWeight.w400,
  Color? color,
  double? letterSpacing,
}) {
  return TextStyle(
    fontFamily: 'Plus Jakarta Sans',
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color,
    letterSpacing: letterSpacing,
  );
}

class AppTheme {
  // Deep teal, professional: teal is the brand - buttons, the current tab,
  // links, progress and selection - on slate neutrals, with green / amber /
  // red only for status. Colour is used flat: no gradients and no coloured
  // glows, which were most of what made the old indigo design read as
  // machine-made. The names are kept from that design (primaryBlue is now
  // teal) so every screen picks the palette up from here.
  static const Color primaryBlue = Color(0xFF0F766E);
  static const Color primaryDark = Color(0xFF115E59);
  static const Color primaryDarker = Color(0xFF134E4A);
  static const Color primaryLight = Color(0xFFF0FDFA);
  static const Color primarySoft = Color(0xFFCCFBF1);

  // Neutrals.
  static const Color slateDark = Color(0xFF0F172A);
  static const Color slateMedium = Color(0xFF475467);
  static const Color slateLight = Color(0xFF667085);
  static const Color textMuted = Color(0xFF98A2B3);
  static const Color borderSubtle = Color(0xFFE4E8EF);
  static const Color borderStrong = Color(0xFFD0D5DD);
  static const Color bgSurface = Color(0xFFF6F8FA);
  static const Color cardBg = Color(0xFFFFFFFF);

  // Status.
  static const Color accentGreen = Color(0xFF16A34A);
  static const Color accentGreenBg = Color(0xFFF0FDF4);
  static const Color accentRed = Color(0xFFDC2626);
  static const Color accentRedBg = Color(0xFFFEF2F2);
  static const Color accentAmber = Color(0xFFD97706);
  static const Color accentAmberBg = Color(0xFFFFFBEB);
  static const Color accentGold = Color(0xFFF59E0B);

  // Supporting tints for icons beside figures (see DsStat): one hue per
  // kind of number, always as a soft tile, never as a gradient.
  static const Color statViolet = Color(0xFF2563EB);
  static const Color statTeal = Color(0xFF0D9488);
  static const Color tintTeal = Color(0xFF0F766E);
  static const Color tintTealBg = Color(0xFFF0FDFA);
  static const Color tintBlue = Color(0xFF2563EB);
  static const Color tintBlueBg = Color(0xFFEFF6FF);
  static const Color tintAmber = Color(0xFFD97706);
  static const Color tintAmberBg = Color(0xFFFFF7ED);
  static const Color tintRose = Color(0xFFE11D48);
  static const Color tintRoseBg = Color(0xFFFFF1F2);

  static List<BoxShadow> get shadowSm => [
        BoxShadow(color: slateDark.withValues(alpha: 0.04), blurRadius: 2, offset: const Offset(0, 1)),
        BoxShadow(color: slateDark.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 1)),
      ];

  static List<BoxShadow> get shadowMd => [
        BoxShadow(color: slateDark.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2)),
        BoxShadow(color: slateDark.withValues(alpha: 0.05), blurRadius: 16, offset: const Offset(0, 4)),
      ];

  static ThemeData get lightTheme {
    final baseTextTheme = ThemeData.light().textTheme.apply(
          fontFamily: 'Plus Jakarta Sans',
          bodyColor: slateDark,
          displayColor: slateDark,
        );

    final textTheme = baseTextTheme.copyWith(
      headlineSmall: _pjs(fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: -0.4, color: slateDark),
      titleLarge: _pjs(fontSize: 19, fontWeight: FontWeight.w700, letterSpacing: -0.3, color: slateDark),
      titleMedium: _pjs(fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: -0.1, color: slateDark),
      titleSmall: _pjs(fontSize: 13.5, fontWeight: FontWeight.w600, color: slateDark),
      bodyLarge: _pjs(fontSize: 15, fontWeight: FontWeight.w400, color: slateDark),
      bodyMedium: _pjs(fontSize: 14, fontWeight: FontWeight.w400, color: slateMedium),
      bodySmall: _pjs(fontSize: 12.5, fontWeight: FontWeight.w400, color: slateLight),
      labelLarge: _pjs(fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0.1),
      labelMedium: _pjs(fontSize: 12.5, fontWeight: FontWeight.w600, letterSpacing: 0.1, color: slateMedium),
    );

    final buttonShape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(10));
    const buttonPadding = EdgeInsets.symmetric(horizontal: 22, vertical: 15);

    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: bgSurface,
      splashFactory: InkRipple.splashFactory,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryBlue,
        primary: primaryBlue,
        onPrimary: Colors.white,
        primaryContainer: primaryLight,
        onPrimaryContainer: primaryDarker,
        secondary: slateMedium,
        onSecondary: Colors.white,
        secondaryContainer: bgSurface,
        onSecondaryContainer: slateDark,
        surface: cardBg,
        onSurface: slateDark,
        surfaceContainerHighest: bgSurface,
        outline: borderSubtle,
        outlineVariant: borderSubtle,
        error: accentRed,
        onError: Colors.white,
        errorContainer: accentRedBg,
        onErrorContainer: accentRed,
      ),
      textTheme: textTheme,
      fontFamily: 'Plus Jakarta Sans',
      iconTheme: const IconThemeData(color: slateMedium, size: 22),
      dividerTheme: const DividerThemeData(color: borderSubtle, thickness: 1, space: 1),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: slateDark,
        elevation: 0,
        scrolledUnderElevation: 1,
        shadowColor: slateDark.withValues(alpha: 0.08),
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: _pjs(fontSize: 18, fontWeight: FontWeight.w700, color: slateDark, letterSpacing: -0.2),
        iconTheme: const IconThemeData(color: slateDark),
      ),
      cardTheme: CardThemeData(
        color: cardBg,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: borderSubtle, width: 1),
        ),
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) return borderSubtle;
            if (states.contains(WidgetState.pressed)) return primaryDarker;
            if (states.contains(WidgetState.hovered)) return primaryDark;
            return primaryBlue;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) return textMuted;
            return Colors.white;
          }),
          overlayColor: WidgetStateProperty.all(Colors.white.withValues(alpha: 0.08)),
          // Flat: a solid black button needs no shadow to read as the
          // primary action.
          elevation: WidgetStateProperty.all(0),
          shadowColor: WidgetStateProperty.all(Colors.transparent),
          shape: WidgetStateProperty.all(buttonShape),
          padding: WidgetStateProperty.all(buttonPadding),
          textStyle: WidgetStateProperty.all(_pjs(fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: 0.1)),
          animationDuration: const Duration(milliseconds: 150),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) return borderSubtle;
            if (states.contains(WidgetState.pressed)) return primaryDarker;
            if (states.contains(WidgetState.hovered)) return primaryDark;
            return primaryBlue;
          }),
          foregroundColor: WidgetStateProperty.all(Colors.white),
          shape: WidgetStateProperty.all(buttonShape),
          padding: WidgetStateProperty.all(buttonPadding),
          textStyle: WidgetStateProperty.all(_pjs(fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: 0.1)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed) || states.contains(WidgetState.hovered)) return primaryDark;
            return slateDark;
          }),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.hovered)) return primaryLight;
            return Colors.white;
          }),
          overlayColor: WidgetStateProperty.all(primaryBlue.withValues(alpha: 0.04)),
          side: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.hovered) || states.contains(WidgetState.pressed)) {
              return const BorderSide(color: primaryBlue, width: 1.3);
            }
            return const BorderSide(color: borderSubtle, width: 1.3);
          }),
          shape: WidgetStateProperty.all(buttonShape),
          padding: WidgetStateProperty.all(buttonPadding),
          textStyle: WidgetStateProperty.all(_pjs(fontSize: 14, fontWeight: FontWeight.w600)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.all(primaryBlue),
          overlayColor: WidgetStateProperty.all(primaryLight),
          shape: WidgetStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
          padding: WidgetStateProperty.all(const EdgeInsets.symmetric(horizontal: 14, vertical: 10)),
          textStyle: WidgetStateProperty.all(_pjs(fontSize: 14, fontWeight: FontWeight.w600)),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.all(slateMedium),
          overlayColor: WidgetStateProperty.all(primaryLight),
          shape: WidgetStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFFAFAFA),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: borderSubtle, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: borderSubtle, width: 1),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: borderSubtle.withValues(alpha: 0.6), width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryBlue, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: accentRed, width: 1.3),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: accentRed, width: 1.6),
        ),
        labelStyle: _pjs(fontSize: 14, color: slateMedium, fontWeight: FontWeight.w500),
        floatingLabelStyle: _pjs(fontSize: 13, color: primaryBlue, fontWeight: FontWeight.w600),
        hintStyle: _pjs(fontSize: 14, color: textMuted),
        errorStyle: _pjs(fontSize: 12, color: accentRed, fontWeight: FontWeight.w500),
        prefixIconColor: slateLight,
        suffixIconColor: slateLight,
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        menuStyle: MenuStyle(
          backgroundColor: const WidgetStatePropertyAll(Colors.white),
          elevation: const WidgetStatePropertyAll(6),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          shadowColor: WidgetStatePropertyAll(slateDark.withValues(alpha: 0.15)),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: borderSubtle)),
          ),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: Colors.white,
        elevation: 6,
        surfaceTintColor: Colors.transparent,
        shadowColor: slateDark.withValues(alpha: 0.15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: borderSubtle)),
        textStyle: _pjs(fontSize: 14, color: slateDark),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: bgSurface,
        selectedColor: primaryLight,
        disabledColor: bgSurface,
        labelStyle: _pjs(fontSize: 13, fontWeight: FontWeight.w600, color: slateDark),
        secondaryLabelStyle: _pjs(fontSize: 13, fontWeight: FontWeight.w600, color: primaryDark),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        side: const BorderSide(color: borderSubtle),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        elevation: 3,
        surfaceTintColor: Colors.transparent,
        shadowColor: slateDark.withValues(alpha: 0.12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titleTextStyle: _pjs(fontSize: 18, fontWeight: FontWeight.w700, color: slateDark),
        contentTextStyle: _pjs(fontSize: 14, color: slateMedium),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: slateDark,
        contentTextStyle: _pjs(fontSize: 14, color: Colors.white, fontWeight: FontWeight.w500),
        actionTextColor: primarySoft,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 6,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(color: slateDark, borderRadius: BorderRadius.circular(8)),
        textStyle: _pjs(fontSize: 12, color: Colors.white),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: const WidgetStatePropertyAll(Colors.white),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? primaryBlue : borderStrong,
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? primaryBlue : Colors.white,
        ),
        checkColor: const WidgetStatePropertyAll(Colors.white),
        side: const BorderSide(color: borderStrong, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? primaryBlue : slateLight,
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: primaryBlue,
        linearTrackColor: primaryLight,
        circularTrackColor: primaryLight,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: primaryBlue,
        unselectedLabelColor: slateLight,
        labelStyle: _pjs(fontSize: 14, fontWeight: FontWeight.w600),
        unselectedLabelStyle: _pjs(fontSize: 14, fontWeight: FontWeight.w500),
        indicatorColor: primaryBlue,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: borderSubtle,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: slateLight,
        textColor: slateDark,
        titleTextStyle: _pjs(fontSize: 14.5, fontWeight: FontWeight.w600, color: slateDark),
        subtitleTextStyle: _pjs(fontSize: 13, color: slateLight),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStatePropertyAll(slateLight.withValues(alpha: 0.4)),
        radius: const Radius.circular(8),
        thickness: const WidgetStatePropertyAll(6),
      ),
    );
  }
}
