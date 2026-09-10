import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_theme_palette.dart';
import 'app_theme_registry.dart';

enum AppThemeMode {
  light,
  dark,
  auroraGlass,
}

@immutable
class AuroraThemeExtension extends ThemeExtension<AuroraThemeExtension> {
  final bool isAurora;
  final Color glassCardBackground;
  final Color glassBorderColor;
  final Color primaryBlue;
  final Color secondaryPurple;
  final Color cyanHighlight;
  final LinearGradient primaryGradient;
  final LinearGradient glassCardGradient;

  const AuroraThemeExtension({
    required this.isAurora,
    required this.glassCardBackground,
    required this.glassBorderColor,
    required this.primaryBlue,
    required this.secondaryPurple,
    required this.cyanHighlight,
    required this.primaryGradient,
    required this.glassCardGradient,
  });

  @override
  AuroraThemeExtension copyWith({
    bool? isAurora,
    Color? glassCardBackground,
    Color? glassBorderColor,
    Color? primaryBlue,
    Color? secondaryPurple,
    Color? cyanHighlight,
    LinearGradient? primaryGradient,
    LinearGradient? glassCardGradient,
  }) {
    return AuroraThemeExtension(
      isAurora: isAurora ?? this.isAurora,
      glassCardBackground: glassCardBackground ?? this.glassCardBackground,
      glassBorderColor: glassBorderColor ?? this.glassBorderColor,
      primaryBlue: primaryBlue ?? this.primaryBlue,
      secondaryPurple: secondaryPurple ?? this.secondaryPurple,
      cyanHighlight: cyanHighlight ?? this.cyanHighlight,
      primaryGradient: primaryGradient ?? this.primaryGradient,
      glassCardGradient: glassCardGradient ?? this.glassCardGradient,
    );
  }

  @override
  AuroraThemeExtension lerp(ThemeExtension<AuroraThemeExtension>? other, double t) {
    if (other is! AuroraThemeExtension) return this;
    return AuroraThemeExtension(
      isAurora: t < 0.5 ? isAurora : other.isAurora,
      glassCardBackground: Color.lerp(glassCardBackground, other.glassCardBackground, t)!,
      glassBorderColor: Color.lerp(glassBorderColor, other.glassBorderColor, t)!,
      primaryBlue: Color.lerp(primaryBlue, other.primaryBlue, t)!,
      secondaryPurple: Color.lerp(secondaryPurple, other.secondaryPurple, t)!,
      cyanHighlight: Color.lerp(cyanHighlight, other.cyanHighlight, t)!,
      primaryGradient: primaryGradient,
      glassCardGradient: glassCardGradient,
    );
  }
}

class AppTheme {
  // Brand Colors - Executive Slate & Sapphire Navy Palette
  static const Color primaryBlue = Color(0xFF1E3A8A); // Deep Royal Navy
  static const Color primaryDarkBlue = Color(0xFF0F172A); // Slate Midnight Charcoal
  static const Color primaryLightBlue = Color(0xFFE2E8F0); // Subtle Slate Ice
  static const Color accentIndigo = Color(0xFF3B82F6); // Soft Royal Blue
  static const Color secondaryGreen = Color(0xFF10B981); // Refined Emerald Accent
  static const Color accentOrange = Color(0xFFF59E0B); // Warm Amber Gold
  static const Color warningRed = Color(0xFFEF4444); // Premium Crimson
  
  // Light Theme Colors
  static const Color lightBackground = Color(0xFFF8FAFC);
  static const Color lightSurface = Colors.white;
  static const Color lightCard = Colors.white;
  static const Color lightTextPrimary = Color(0xFF0F172A);
  static const Color lightTextSecondary = Color(0xFF64748B);
  static const Color lightBorder = Color(0xFFE2E8F0);
  
  // Dark Theme Colors - Deep Slate & Charcoal Navy
  static const Color darkBackground = Color(0xFF0B0F17); // Deepest Charcoal Slate
  static const Color darkSurface = Color(0xFF161F30); // Refined Dark Card Surface
  static const Color darkCard = Color(0xFF161F30);
  static const Color darkTextPrimary = Color(0xFFF8FAFC);
  static const Color darkTextSecondary = Color(0xFF94A3B8);
  static const Color darkBorder = Color(0xFF243044); // Subtle Border Lighting

  // Aurora Glass Theme Colors - Deep Midnight Navy & Translucent Glass
  static const Color auroraBackground = Color(0xFF070B14); // Deep Midnight Navy
  static const Color auroraSurface = Color(0xFF0D1527); // Dark Slate Navy Surface
  static const Color auroraGlassCard = Color(0xB8111D35); // 72% Translucent Glass Surface
  static const Color auroraGlassCardOpaque = Color(0xFF111D35); // Fully opaque fallback
  static const Color auroraBorder = Color(0x3338BDF8); // Subtle Cyan-Blue Border (20% alpha)
  static const Color auroraBorderGlowing = Color(0x6638BDF8); // 40% alpha glowing cyan
  static const Color auroraPrimaryBlue = Color(0xFF3B82F6); // Vibrant Royal Blue
  static const Color auroraSecondaryPurple = Color(0xFF8B5CF6); // Electric Purple
  static const Color auroraCyanHighlight = Color(0xFF06B6D4); // Electric Cyan
  static const Color auroraTextPrimary = Color(0xFFF8FAFC); // Crisp High Contrast White
  static const Color auroraTextSecondary = Color(0xFF94A3B8); // Slate Secondary
  static const Color auroraTextTertiary = Color(0xFF64748B); // Muted Slate

  // Gradient Presets - Luxury & Sophisticated
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF0F172A), Color(0xFF1E3A8A), Color(0xFF1E293B)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient accentGradient = LinearGradient(
    colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient successGradient = LinearGradient(
    colors: [Color(0xFF059669), Color(0xFF10B981)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient warningGradient = LinearGradient(
    colors: [Color(0xFFD97706), Color(0xFFF59E0B)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Aurora Glass Gradients
  static const LinearGradient auroraPrimaryGradient = LinearGradient(
    colors: [Color(0xFF070B14), Color(0xFF0F172A), Color(0xFF1E1B4B)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient auroraAccentGradient = LinearGradient(
    colors: [Color(0xFF2563EB), Color(0xFF7C3AED), Color(0xFF06B6D4)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient auroraCardGradient = LinearGradient(
    colors: [Color(0xC013213F), Color(0x990D182E)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient auroraHeaderGradient = LinearGradient(
    colors: [Color(0xFF0A1022), Color(0xFF172545), Color(0xFF1E1B4B)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static AppThemeTokens tokens(BuildContext context) {
    final t = Theme.of(context).extension<AppThemeTokens>();
    if (t != null) return t;
    if (isAurora(context)) return AppThemeRegistry.auroraGlass.tokens;
    if (Theme.of(context).brightness == Brightness.dark) {
      return AppThemeRegistry.classicDark.tokens;
    }
    return AppThemeRegistry.classicLight.tokens;
  }

  static bool isAurora(BuildContext context) {
    final t = Theme.of(context).extension<AppThemeTokens>();
    if (t != null) return t.id == 'aurora_glass' || (t.isGlass && t.isDark);
    final ext = Theme.of(context).extension<AuroraThemeExtension>();
    return ext?.isAurora ?? false;
  }

  static bool isNeumorphic(BuildContext context) {
    return tokens(context).isNeumorphic;
  }

  static bool isGlass(BuildContext context) {
    return tokens(context).isGlass;
  }

  static Color cardColor(BuildContext context) {
    final t = Theme.of(context).extension<AppThemeTokens>();
    if (t != null) return t.card;
    if (isAurora(context)) return auroraGlassCard;
    return Theme.of(context).brightness == Brightness.dark ? darkCard : lightCard;
  }

  static Color borderColor(BuildContext context) {
    final t = Theme.of(context).extension<AppThemeTokens>();
    if (t != null) return t.border;
    if (isAurora(context)) return auroraBorder;
    return Theme.of(context).brightness == Brightness.dark ? darkBorder : lightBorder;
  }

  static LinearGradient headerGradient(BuildContext context) {
    final t = Theme.of(context).extension<AppThemeTokens>();
    if (t != null) return t.headerGradient;
    if (isAurora(context)) return auroraHeaderGradient;
    return primaryGradient;
  }

  static List<BoxShadow> cardShadow(BuildContext context) {
    return tokens(context).cardShadow;
  }

  static ThemeData get lightTheme {
    final baseTextTheme = GoogleFonts.poppinsTextTheme();
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: primaryBlue,
      scaffoldBackgroundColor: lightBackground,
      colorScheme: const ColorScheme.light(
        primary: primaryBlue,
        secondary: accentIndigo,
        tertiary: secondaryGreen,
        error: warningRed,
        surface: lightSurface,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: lightTextPrimary,
      ),
      textTheme: baseTextTheme.copyWith(
        displayLarge: GoogleFonts.poppins(color: lightTextPrimary, fontWeight: FontWeight.bold),
        displayMedium: GoogleFonts.poppins(color: lightTextPrimary, fontWeight: FontWeight.bold),
        titleLarge: GoogleFonts.poppins(color: lightTextPrimary, fontWeight: FontWeight.w600, fontSize: 20),
        titleMedium: GoogleFonts.poppins(color: lightTextPrimary, fontWeight: FontWeight.w600, fontSize: 16),
        bodyLarge: GoogleFonts.poppins(color: lightTextPrimary, fontSize: 16),
        bodyMedium: GoogleFonts.poppins(color: lightTextSecondary, fontSize: 14),
        bodySmall: GoogleFonts.poppins(color: lightTextSecondary, fontSize: 12),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: primaryBlue,
        elevation: 0,
        centerTitle: true,
        scrolledUnderElevation: 0,
        titleTextStyle: GoogleFonts.poppins(
          color: Colors.white,
          fontSize: 19,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      cardTheme: CardThemeData(
        color: lightCard,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: lightBorder, width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryBlue,
          foregroundColor: Colors.white,
          elevation: 2,
          shadowColor: primaryBlue.withValues(alpha: 0.3),
          textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryBlue,
          side: const BorderSide(color: primaryBlue, width: 1.5),
          textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryBlue,
          textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: lightBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: lightBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: primaryBlue, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: warningRed, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: warningRed, width: 2),
        ),
        labelStyle: GoogleFonts.poppins(color: lightTextSecondary),
        hintStyle: GoogleFonts.poppins(color: lightTextSecondary.withValues(alpha: 0.7), fontSize: 14),
        prefixIconColor: lightTextSecondary,
        suffixIconColor: lightTextSecondary,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: primaryBlue,
        unselectedItemColor: lightTextSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: lightCard,
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primaryBlue,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        contentTextStyle: GoogleFonts.poppins(color: Colors.white),
      ),
      extensions: [
        AppThemeRegistry.classicLight.tokens,
      ],
    );
  }

  static ThemeData get darkTheme {
    final baseTextTheme = GoogleFonts.poppinsTextTheme();
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: primaryBlue,
      scaffoldBackgroundColor: darkBackground,
      colorScheme: const ColorScheme.dark(
        primary: primaryBlue,
        secondary: accentIndigo,
        tertiary: secondaryGreen,
        error: warningRed,
        surface: darkSurface,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: darkTextPrimary,
      ),
      textTheme: baseTextTheme.copyWith(
        displayLarge: GoogleFonts.poppins(color: darkTextPrimary, fontWeight: FontWeight.bold),
        displayMedium: GoogleFonts.poppins(color: darkTextPrimary, fontWeight: FontWeight.bold),
        titleLarge: GoogleFonts.poppins(color: darkTextPrimary, fontWeight: FontWeight.w600, fontSize: 20),
        titleMedium: GoogleFonts.poppins(color: darkTextPrimary, fontWeight: FontWeight.w600, fontSize: 16),
        bodyLarge: GoogleFonts.poppins(color: darkTextPrimary, fontSize: 16),
        bodyMedium: GoogleFonts.poppins(color: darkTextSecondary, fontSize: 14),
        bodySmall: GoogleFonts.poppins(color: darkTextSecondary, fontSize: 12),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: darkSurface,
        elevation: 0,
        centerTitle: true,
        scrolledUnderElevation: 0,
        titleTextStyle: GoogleFonts.poppins(
          color: Colors.white,
          fontSize: 19,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      cardTheme: CardThemeData(
        color: darkCard,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: darkBorder, width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryBlue,
          foregroundColor: Colors.white,
          elevation: 2,
          shadowColor: Colors.black.withValues(alpha: 0.5),
          textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: const BorderSide(color: darkBorder, width: 1.5),
          textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkSurface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: darkBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: darkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: primaryBlue, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: warningRed, width: 1.5),
        ),
        labelStyle: GoogleFonts.poppins(color: darkTextSecondary),
        hintStyle: GoogleFonts.poppins(color: darkTextSecondary.withValues(alpha: 0.7), fontSize: 14),
        prefixIconColor: darkTextSecondary,
        suffixIconColor: darkTextSecondary,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: darkSurface,
        selectedItemColor: primaryBlue,
        unselectedItemColor: darkTextSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: darkSurface,
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primaryBlue,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        contentTextStyle: GoogleFonts.poppins(color: Colors.white),
      ),
      extensions: [
        AppThemeRegistry.classicDark.tokens,
      ],
    );
  }

  static ThemeData get auroraGlassTheme {
    final baseTextTheme = GoogleFonts.poppinsTextTheme();
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: auroraPrimaryBlue,
      scaffoldBackgroundColor: auroraBackground,
      colorScheme: const ColorScheme.dark(
        primary: auroraPrimaryBlue,
        secondary: auroraSecondaryPurple,
        tertiary: auroraCyanHighlight,
        error: warningRed,
        surface: auroraSurface,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: auroraTextPrimary,
        outline: auroraBorder,
      ),
      textTheme: baseTextTheme.copyWith(
        displayLarge: GoogleFonts.poppins(color: auroraTextPrimary, fontWeight: FontWeight.bold),
        displayMedium: GoogleFonts.poppins(color: auroraTextPrimary, fontWeight: FontWeight.bold),
        titleLarge: GoogleFonts.poppins(color: auroraTextPrimary, fontWeight: FontWeight.w600, fontSize: 20),
        titleMedium: GoogleFonts.poppins(color: auroraTextPrimary, fontWeight: FontWeight.w600, fontSize: 16),
        bodyLarge: GoogleFonts.poppins(color: auroraTextPrimary, fontSize: 16),
        bodyMedium: GoogleFonts.poppins(color: auroraTextSecondary, fontSize: 14),
        bodySmall: GoogleFonts.poppins(color: auroraTextSecondary, fontSize: 12),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: auroraSurface,
        elevation: 0,
        centerTitle: true,
        scrolledUnderElevation: 0,
        titleTextStyle: GoogleFonts.poppins(
          color: Colors.white,
          fontSize: 19,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      cardTheme: CardThemeData(
        color: auroraGlassCardOpaque,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: auroraBorder, width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: auroraPrimaryBlue,
          foregroundColor: Colors.white,
          elevation: 3,
          shadowColor: auroraPrimaryBlue.withValues(alpha: 0.4),
          textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: const BorderSide(color: auroraBorder, width: 1.5),
          textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: auroraSurface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: auroraBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: auroraBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: auroraCyanHighlight, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: warningRed, width: 1.5),
        ),
        labelStyle: GoogleFonts.poppins(color: auroraTextSecondary),
        hintStyle: GoogleFonts.poppins(color: auroraTextSecondary.withValues(alpha: 0.7), fontSize: 14),
        prefixIconColor: auroraTextSecondary,
        suffixIconColor: auroraTextSecondary,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: auroraSurface,
        selectedItemColor: auroraCyanHighlight,
        unselectedItemColor: auroraTextSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: auroraSurface,
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: auroraBorder, width: 1),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: auroraPrimaryBlue,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: auroraSurface,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: auroraBorder, width: 1),
        ),
        contentTextStyle: GoogleFonts.poppins(color: Colors.white),
      ),
      extensions: [
        AppThemeRegistry.auroraGlass.tokens,
        AuroraThemeExtension(
          isAurora: true,
          glassCardBackground: auroraGlassCard,
          glassBorderColor: auroraBorder,
          primaryBlue: auroraPrimaryBlue,
          secondaryPurple: auroraSecondaryPurple,
          cyanHighlight: auroraCyanHighlight,
          primaryGradient: auroraPrimaryGradient,
          glassCardGradient: auroraCardGradient,
        ),
      ],
    );
  }
}
