import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:my_academy_app/theme/app_theme_palette.dart';
import 'package:my_academy_app/theme/app_theme_registry.dart';
import 'package:my_academy_app/theme/app_theme.dart';
import 'package:my_academy_app/provider/theme_provider.dart';
import 'package:my_academy_app/settings/theme_selection_screen.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('AppThemeRegistry - 10 Professional Themes', () {
    test('Registry contains all 13 themes (10 new + 3 classic)', () {
      expect(AppThemeRegistry.allThemes.length, equals(13));
      expect(AppThemeRegistry.newThemes.length, equals(10));

      final allIds = AppThemeRegistry.allThemes.map((t) => t.id).toList();
      expect(allIds, containsAll([
        'sunset_amber',
        'minimal_neumorphism',
        'midnight_cosmos',
        'crystal_frost',
        'academic_classic',
        'ocean_breeze',
        'forest_academic',
        'royal_sapphire',
        'arctic_minimal',
        'warm_gradient',
        'classic_light',
        'classic_dark',
        'aurora_glass',
      ]));
    });

    test('1. Sunset Amber properties', () {
      final t = AppThemeRegistry.sunsetAmber;
      expect(t.name, equals('Sunset Amber'));
      expect(t.emoji, equals('🟠'));
      expect(t.isDark, isFalse);
      expect(t.tokens.primary, equals(const Color(0xFFF59E0B)));
      expect(t.tokens.secondary, equals(const Color(0xFFEA580C)));
      expect(t.toThemeData().brightness, equals(Brightness.light));
    });

    test('2. Minimal Neumorphism properties and dual shadows', () {
      final t = AppThemeRegistry.minimalNeumorphism;
      expect(t.name, equals('Minimal Neumorphism'));
      expect(t.emoji, equals('🧊'));
      expect(t.isNeumorphic, isTrue);
      expect(t.tokens.cardShadow.length, equals(2)); // Dual soft shadow
      expect(t.tokens.background, equals(const Color(0xFFEBF0F5)));
    });

    test('3. Midnight Cosmos properties', () {
      final t = AppThemeRegistry.midnightCosmos;
      expect(t.name, equals('Midnight Cosmos'));
      expect(t.emoji, equals('🌌'));
      expect(t.isDark, isTrue);
      expect(t.toThemeData().brightness, equals(Brightness.dark));
      expect(t.tokens.primary, equals(const Color(0xFF6366F1)));
    });

    test('4. Crystal Frost properties', () {
      final t = AppThemeRegistry.crystalFrost;
      expect(t.name, equals('Crystal Frost'));
      expect(t.emoji, equals('🪞'));
      expect(t.isGlass, isTrue);
      expect(t.tokens.background, equals(const Color(0xFFF0F9FF)));
    });

    test('5. Academic Classic properties', () {
      final t = AppThemeRegistry.academicClassic;
      expect(t.name, equals('Academic Classic'));
      expect(t.emoji, equals('🏛️'));
      expect(t.tokens.primary, equals(const Color(0xFF1E3A8A)));
      expect(t.tokens.secondary, equals(const Color(0xFFD97706)));
      expect(t.tokens.background, equals(const Color(0xFFFDFBF7)));
    });

    test('6. Ocean Breeze properties', () {
      final t = AppThemeRegistry.oceanBreeze;
      expect(t.name, equals('Ocean Breeze'));
      expect(t.emoji, equals('🌊'));
      expect(t.tokens.primary, equals(const Color(0xFF0D9488)));
      expect(t.tokens.secondary, equals(const Color(0xFF06B6D4)));
    });

    test('7. Forest Academic properties', () {
      final t = AppThemeRegistry.forestAcademic;
      expect(t.name, equals('Forest Academic'));
      expect(t.emoji, equals('🌿'));
      expect(t.tokens.primary, equals(const Color(0xFF059669)));
      expect(t.tokens.secondary, equals(const Color(0xFF065F46)));
    });

    test('8. Royal Sapphire properties', () {
      final t = AppThemeRegistry.royalSapphire;
      expect(t.name, equals('Royal Sapphire'));
      expect(t.emoji, equals('💎'));
      expect(t.isDark, isTrue);
      expect(t.tokens.primary, equals(const Color(0xFF2563EB)));
      expect(t.tokens.secondary, equals(const Color(0xFF7C3AED)));
    });

    test('9. Arctic Minimal properties', () {
      final t = AppThemeRegistry.arcticMinimal;
      expect(t.name, equals('Arctic Minimal'));
      expect(t.emoji, equals('🩵'));
      expect(t.tokens.background, equals(const Color(0xFFF8FAFC)));
    });

    test('10. Warm Gradient properties', () {
      final t = AppThemeRegistry.warmGradient;
      expect(t.name, equals('Warm Gradient'));
      expect(t.emoji, equals('🌅'));
      expect(t.tokens.primaryGradient.colors.length, equals(3));
    });

    test('Every theme generates a valid ThemeData with AppThemeTokens extension', () {
      for (final theme in AppThemeRegistry.allThemes) {
        final themeData = theme.toThemeData();
        expect(themeData, isNotNull);
        final ext = themeData.extension<AppThemeTokens>();
        expect(ext, isNotNull);
        expect(ext!.id, equals(theme.id));
      }
    });
  });

  group('ThemeProvider Dynamic Customization & Persistence', () {
    test('Defaults to classic_light and allows immediate theme switching', () {
      final provider = ThemeProvider();
      expect(provider.currentThemeId, equals('classic_light'));
      expect(provider.currentPalette.name, equals('Classic Light'));

      // Switch to Ocean Breeze
      provider.setTheme('ocean_breeze');
      expect(provider.currentThemeId, equals('ocean_breeze'));
      expect(provider.currentPalette.name, equals('Ocean Breeze'));
      expect(provider.isDark, isFalse);

      // Switch to Midnight Cosmos
      provider.setTheme('midnight_cosmos');
      expect(provider.currentThemeId, equals('midnight_cosmos'));
      expect(provider.currentPalette.name, equals('Midnight Cosmos'));
      expect(provider.isDark, isTrue);

      // Switch to Minimal Neumorphism
      provider.setTheme('minimal_neumorphism');
      expect(provider.currentThemeId, equals('minimal_neumorphism'));
      expect(provider.currentPalette.isNeumorphic, isTrue);
    });

    test('User-scoped theme separation maintains independent preferences', () async {
      final provider = ThemeProvider();

      // Student sets Ocean Breeze
      await provider.setTheme('ocean_breeze', userId: 'student_12345');
      expect(provider.currentThemeId, equals('ocean_breeze'));

      // Teacher sets Academic Classic
      await provider.setTheme('academic_classic', userId: 'teacher_99999');
      expect(provider.currentThemeId, equals('academic_classic'));

      // Re-loading student's theme restores Ocean Breeze
      await provider.loadUserTheme('student_12345');
      expect(provider.currentThemeId, equals('ocean_breeze'));

      // Re-loading teacher's theme restores Academic Classic
      await provider.loadUserTheme('teacher_99999');
      expect(provider.currentThemeId, equals('academic_classic'));
    });
  });

  group('ThemeSelectionScreen UI', () {
    testWidgets('Renders theme selection gallery and allows tapping themes', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final provider = ThemeProvider();

      await tester.pumpWidget(
        ChangeNotifierProvider<ThemeProvider>.value(
          value: provider,
          child: MaterialApp(
            theme: provider.currentThemeData,
            home: const ThemeSelectionScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify screen header
      expect(find.text('Choose Your Theme'), findsOneWidget);
      expect(find.text('PORTAL PERSONALIZATION'), findsOneWidget);

      // Verify presence of new themes
      expect(find.text('Sunset Amber'), findsOneWidget);
      expect(find.text('Minimal Neumorphism'), findsOneWidget);
      expect(find.text('Midnight Cosmos'), findsOneWidget);

      // Tap on Ocean Breeze theme card
      await tester.tap(find.text('Ocean Breeze'));
      await tester.pumpAndSettle();

      expect(provider.currentThemeId, equals('ocean_breeze'));
      expect(provider.currentPalette.name, equals('Ocean Breeze'));
    });
  });
}
