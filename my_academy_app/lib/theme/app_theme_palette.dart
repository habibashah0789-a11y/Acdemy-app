import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Design tokens provided by the active theme palette via Flutter's ThemeExtension.
class AppThemeTokens extends ThemeExtension<AppThemeTokens> {
  final String id;
  final String name;
  final bool isDark;
  final bool isNeumorphic;
  final bool isGlass;

  final Color primary;
  final Color secondary;
  final Color accent;
  final Color background;
  final Color surface;
  final Color card;
  final Color textPrimary;
  final Color textSecondary;
  final Color border;
  final Color divider;
  final Color iconColor;
  final Color success;
  final Color warning;
  final Color error;
  final Color button;
  final Color buttonText;
  final Color inputFill;
  final Color inputBorder;
  final Color navBar;
  final Color navBarSelected;
  final Color navBarUnselected;
  final Color appBar;
  final Color appBarText;

  final LinearGradient primaryGradient;
  final LinearGradient accentGradient;
  final LinearGradient headerGradient;
  final List<BoxShadow> cardShadow;

  const AppThemeTokens({
    required this.id,
    required this.name,
    required this.isDark,
    this.isNeumorphic = false,
    this.isGlass = false,
    required this.primary,
    required this.secondary,
    required this.accent,
    required this.background,
    required this.surface,
    required this.card,
    required this.textPrimary,
    required this.textSecondary,
    required this.border,
    required this.divider,
    required this.iconColor,
    required this.success,
    required this.warning,
    required this.error,
    required this.button,
    required this.buttonText,
    required this.inputFill,
    required this.inputBorder,
    required this.navBar,
    required this.navBarSelected,
    required this.navBarUnselected,
    required this.appBar,
    required this.appBarText,
    required this.primaryGradient,
    required this.accentGradient,
    required this.headerGradient,
    required this.cardShadow,
  });

  @override
  ThemeExtension<AppThemeTokens> copyWith({
    String? id,
    String? name,
    bool? isDark,
    bool? isNeumorphic,
    bool? isGlass,
    Color? primary,
    Color? secondary,
    Color? accent,
    Color? background,
    Color? surface,
    Color? card,
    Color? textPrimary,
    Color? textSecondary,
    Color? border,
    Color? divider,
    Color? iconColor,
    Color? success,
    Color? warning,
    Color? error,
    Color? button,
    Color? buttonText,
    Color? inputFill,
    Color? inputBorder,
    Color? navBar,
    Color? navBarSelected,
    Color? navBarUnselected,
    Color? appBar,
    Color? appBarText,
    LinearGradient? primaryGradient,
    LinearGradient? accentGradient,
    LinearGradient? headerGradient,
    List<BoxShadow>? cardShadow,
  }) {
    return AppThemeTokens(
      id: id ?? this.id,
      name: name ?? this.name,
      isDark: isDark ?? this.isDark,
      isNeumorphic: isNeumorphic ?? this.isNeumorphic,
      isGlass: isGlass ?? this.isGlass,
      primary: primary ?? this.primary,
      secondary: secondary ?? this.secondary,
      accent: accent ?? this.accent,
      background: background ?? this.background,
      surface: surface ?? this.surface,
      card: card ?? this.card,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      border: border ?? this.border,
      divider: divider ?? this.divider,
      iconColor: iconColor ?? this.iconColor,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      error: error ?? this.error,
      button: button ?? this.button,
      buttonText: buttonText ?? this.buttonText,
      inputFill: inputFill ?? this.inputFill,
      inputBorder: inputBorder ?? this.inputBorder,
      navBar: navBar ?? this.navBar,
      navBarSelected: navBarSelected ?? this.navBarSelected,
      navBarUnselected: navBarUnselected ?? this.navBarUnselected,
      appBar: appBar ?? this.appBar,
      appBarText: appBarText ?? this.appBarText,
      primaryGradient: primaryGradient ?? this.primaryGradient,
      accentGradient: accentGradient ?? this.accentGradient,
      headerGradient: headerGradient ?? this.headerGradient,
      cardShadow: cardShadow ?? this.cardShadow,
    );
  }

  @override
  ThemeExtension<AppThemeTokens> lerp(
    covariant ThemeExtension<AppThemeTokens>? other,
    double t,
  ) {
    if (other is! AppThemeTokens) return this;
    return AppThemeTokens(
      id: t < 0.5 ? id : other.id,
      name: t < 0.5 ? name : other.name,
      isDark: t < 0.5 ? isDark : other.isDark,
      isNeumorphic: t < 0.5 ? isNeumorphic : other.isNeumorphic,
      isGlass: t < 0.5 ? isGlass : other.isGlass,
      primary: Color.lerp(primary, other.primary, t) ?? primary,
      secondary: Color.lerp(secondary, other.secondary, t) ?? secondary,
      accent: Color.lerp(accent, other.accent, t) ?? accent,
      background: Color.lerp(background, other.background, t) ?? background,
      surface: Color.lerp(surface, other.surface, t) ?? surface,
      card: Color.lerp(card, other.card, t) ?? card,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t) ?? textPrimary,
      textSecondary:
          Color.lerp(textSecondary, other.textSecondary, t) ?? textSecondary,
      border: Color.lerp(border, other.border, t) ?? border,
      divider: Color.lerp(divider, other.divider, t) ?? divider,
      iconColor: Color.lerp(iconColor, other.iconColor, t) ?? iconColor,
      success: Color.lerp(success, other.success, t) ?? success,
      warning: Color.lerp(warning, other.warning, t) ?? warning,
      error: Color.lerp(error, other.error, t) ?? error,
      button: Color.lerp(button, other.button, t) ?? button,
      buttonText: Color.lerp(buttonText, other.buttonText, t) ?? buttonText,
      inputFill: Color.lerp(inputFill, other.inputFill, t) ?? inputFill,
      inputBorder: Color.lerp(inputBorder, other.inputBorder, t) ?? inputBorder,
      navBar: Color.lerp(navBar, other.navBar, t) ?? navBar,
      navBarSelected:
          Color.lerp(navBarSelected, other.navBarSelected, t) ?? navBarSelected,
      navBarUnselected:
          Color.lerp(navBarUnselected, other.navBarUnselected, t) ??
              navBarUnselected,
      appBar: Color.lerp(appBar, other.appBar, t) ?? appBar,
      appBarText: Color.lerp(appBarText, other.appBarText, t) ?? appBarText,
      primaryGradient:
          LinearGradient.lerp(primaryGradient, other.primaryGradient, t) ??
              primaryGradient,
      accentGradient:
          LinearGradient.lerp(accentGradient, other.accentGradient, t) ??
              accentGradient,
      headerGradient:
          LinearGradient.lerp(headerGradient, other.headerGradient, t) ??
              headerGradient,
      cardShadow: t < 0.5 ? cardShadow : other.cardShadow,
    );
  }

  static AppThemeTokens fallback = AppThemeTokens(
    id: 'classic_light',
    name: 'Classic Light',
    isDark: false,
    primary: const Color(0xFF2563EB),
    secondary: const Color(0xFF1E3A8A),
    accent: const Color(0xFF10B981),
    background: const Color(0xFFF8FAFC),
    surface: Colors.white,
    card: Colors.white,
    textPrimary: const Color(0xFF0F172A),
    textSecondary: const Color(0xFF64748B),
    border: const Color(0xFFE2E8F0),
    divider: const Color(0xFFE2E8F0),
    iconColor: const Color(0xFF2563EB),
    success: const Color(0xFF10B981),
    warning: const Color(0xFFF59E0B),
    error: const Color(0xFFEF4444),
    button: const Color(0xFF2563EB),
    buttonText: Colors.white,
    inputFill: Colors.white,
    inputBorder: const Color(0xFFE2E8F0),
    navBar: Colors.white,
    navBarSelected: const Color(0xFF2563EB),
    navBarUnselected: const Color(0xFF64748B),
    appBar: const Color(0xFF1E3A8A),
    appBarText: Colors.white,
    primaryGradient: const LinearGradient(
      colors: [Color(0xFF2563EB), Color(0xFF1E3A8A)],
    ),
    accentGradient: const LinearGradient(
      colors: [Color(0xFF10B981), Color(0xFF059669)],
    ),
    headerGradient: const LinearGradient(
      colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
    ),
    cardShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.04),
        blurRadius: 10,
        offset: const Offset(0, 4),
      ),
    ],
  );
}

/// Rich palette defining metadata and dynamic generation of ThemeData for any theme.
class AppThemePalette {
  final String id;
  final String name;
  final String description;
  final String emoji;
  final IconData icon;
  final List<Color> previewColors;
  final bool isDark;
  final bool isNeumorphic;
  final bool isGlass;

  final AppThemeTokens tokens;

  const AppThemePalette({
    required this.id,
    required this.name,
    required this.description,
    required this.emoji,
    required this.icon,
    required this.previewColors,
    required this.isDark,
    this.isNeumorphic = false,
    this.isGlass = false,
    required this.tokens,
  });

  /// Translates this palette into a full Material 3 ThemeData with extensions.
  ThemeData toThemeData() {
    final brightness = isDark ? Brightness.dark : Brightness.light;
    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: tokens.primary,
      onPrimary: tokens.buttonText,
      secondary: tokens.secondary,
      onSecondary: tokens.buttonText,
      error: tokens.error,
      onError: Colors.white,
      surface: tokens.surface,
      onSurface: tokens.textPrimary,
    );

    final textTheme = GoogleFonts.poppinsTextTheme().copyWith(
      displayLarge: GoogleFonts.poppins(
        color: tokens.textPrimary,
        fontWeight: FontWeight.bold,
      ),
      displayMedium: GoogleFonts.poppins(
        color: tokens.textPrimary,
        fontWeight: FontWeight.bold,
      ),
      titleLarge: GoogleFonts.poppins(
        color: tokens.textPrimary,
        fontWeight: FontWeight.bold,
      ),
      titleMedium: GoogleFonts.poppins(
        color: tokens.textPrimary,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: GoogleFonts.poppins(
        color: tokens.textPrimary,
        fontWeight: FontWeight.normal,
      ),
      bodyMedium: GoogleFonts.poppins(
        color: tokens.textSecondary,
        fontWeight: FontWeight.normal,
      ),
      bodySmall: GoogleFonts.poppins(
        color: tokens.textSecondary,
        fontSize: 12,
      ),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: tokens.background,
      cardColor: tokens.card,
      dividerColor: tokens.divider,
      textTheme: textTheme,
      cardTheme: CardThemeData(
        color: tokens.card,
        elevation: isNeumorphic ? 2 : 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: tokens.border, width: 1),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: tokens.appBar,
        foregroundColor: tokens.appBarText,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: tokens.appBarText,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: tokens.button,
          foregroundColor: tokens.buttonText,
          elevation: isNeumorphic ? 3 : 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: tokens.inputFill,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: tokens.inputBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: tokens.inputBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: tokens.primary, width: 2),
        ),
        hintStyle: GoogleFonts.poppins(color: tokens.textSecondary, fontSize: 13),
        labelStyle: GoogleFonts.poppins(color: tokens.textSecondary, fontSize: 14),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: tokens.navBar,
        indicatorColor: tokens.primary.withValues(alpha: 0.16),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: tokens.navBarSelected,
            );
          }
          return GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: tokens.navBarUnselected,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: tokens.navBarSelected, size: 24);
          }
          return IconThemeData(color: tokens.navBarUnselected, size: 22);
        }),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: tokens.navBar,
        selectedItemColor: tokens.navBarSelected,
        unselectedItemColor: tokens.navBarUnselected,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold),
        unselectedLabelStyle: GoogleFonts.poppins(fontSize: 11),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: tokens.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: tokens.border),
        ),
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: tokens.textPrimary,
        ),
      ),
      extensions: [
        tokens,
      ],
    );
  }
}
