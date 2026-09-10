import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:my_academy_app/theme/app_theme.dart';
import 'package:my_academy_app/provider/theme_provider.dart';
import 'package:my_academy_app/settings/appearance_screen.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('AppTheme & Aurora Glass Architecture', () {
    test('AppThemeMode enum has all 3 required themes', () {
      expect(AppThemeMode.values.length, equals(3));
      expect(AppThemeMode.values, contains(AppThemeMode.light));
      expect(AppThemeMode.values, contains(AppThemeMode.dark));
      expect(AppThemeMode.values, contains(AppThemeMode.auroraGlass));
    });

    test('Existing Light Theme remains preserved and functional', () {
      final light = AppTheme.lightTheme;
      expect(light.brightness, equals(Brightness.light));
      expect(light.scaffoldBackgroundColor, equals(AppTheme.lightBackground));
      expect(AppTheme.primaryBlue, equals(const Color(0xFF1E3A8A)));
      expect(AppTheme.primaryDarkBlue, equals(const Color(0xFF0F172A)));
      expect(AppTheme.lightCard, equals(Colors.white));
      expect(AppTheme.lightBorder, equals(const Color(0xFFE2E8F0)));
      // lightTheme must NOT have AuroraThemeExtension
      expect(light.extension<AuroraThemeExtension>(), isNull);
    });

    test('Existing Dark Theme remains preserved and functional', () {
      final dark = AppTheme.darkTheme;
      expect(dark.brightness, equals(Brightness.dark));
      expect(dark.scaffoldBackgroundColor, equals(AppTheme.darkBackground));
      expect(AppTheme.darkCard, equals(const Color(0xFF161F30)));
      expect(AppTheme.darkSurface, equals(const Color(0xFF161F30)));
      expect(AppTheme.darkBorder, equals(const Color(0xFF243044)));
      // darkTheme must NOT have AuroraThemeExtension
      expect(dark.extension<AuroraThemeExtension>(), isNull);
    });

    test('Aurora Glass Theme satisfies all design specifications', () {
      final aurora = AppTheme.auroraGlassTheme;
      expect(aurora.brightness, equals(Brightness.dark));
      expect(aurora.scaffoldBackgroundColor, equals(AppTheme.auroraBackground));
      expect(AppTheme.auroraBackground, equals(const Color(0xFF070B14)));
      expect(AppTheme.auroraSurface, equals(const Color(0xFF0D1527)));
      expect(AppTheme.auroraGlassCard, equals(const Color(0xB8111D35)));
      expect(AppTheme.auroraBorder, equals(const Color(0x3338BDF8)));
      expect(AppTheme.auroraPrimaryBlue, equals(const Color(0xFF3B82F6)));
      expect(AppTheme.auroraSecondaryPurple, equals(const Color(0xFF8B5CF6)));
      expect(AppTheme.auroraCyanHighlight, equals(const Color(0xFF06B6D4)));

      // Aurora ThemeExtension must be present and configured
      final ext = aurora.extension<AuroraThemeExtension>();
      expect(ext, isNotNull);
      expect(ext!.primaryGradient, equals(AppTheme.auroraPrimaryGradient));
      expect(ext.glassCardBackground, equals(AppTheme.auroraGlassCard));
      expect(ext.glassBorderColor, equals(AppTheme.auroraBorder));
      expect(ext.cyanHighlight, equals(AppTheme.auroraCyanHighlight));
    });
  });

  group('AppTheme Context Helpers', () {
    testWidgets('AppTheme.isAurora returns true only for auroraGlassTheme', (tester) async {
      bool? isAuroraLight;
      bool? isAuroraDark;
      bool? isAuroraGlass;

      await tester.pumpWidget(
        Theme(
          data: AppTheme.lightTheme,
          child: Builder(
            builder: (ctx) {
              isAuroraLight = AppTheme.isAurora(ctx);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      await tester.pumpWidget(
        Theme(
          data: AppTheme.darkTheme,
          child: Builder(
            builder: (ctx) {
              isAuroraDark = AppTheme.isAurora(ctx);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      await tester.pumpWidget(
        Theme(
          data: AppTheme.auroraGlassTheme,
          child: Builder(
            builder: (ctx) {
              isAuroraGlass = AppTheme.isAurora(ctx);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(isAuroraLight, isFalse);
      expect(isAuroraDark, isFalse);
      expect(isAuroraGlass, isTrue);
    });

    testWidgets('AppTheme.cardColor and borderColor adapt accurately per theme', (tester) async {
      Color? cardLight, cardDark, cardAurora;
      Color? borderLight, borderDark, borderAurora;

      await tester.pumpWidget(
        Theme(
          data: AppTheme.lightTheme,
          child: Builder(
            builder: (ctx) {
              cardLight = AppTheme.cardColor(ctx);
              borderLight = AppTheme.borderColor(ctx);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      await tester.pumpWidget(
        Theme(
          data: AppTheme.darkTheme,
          child: Builder(
            builder: (ctx) {
              cardDark = AppTheme.cardColor(ctx);
              borderDark = AppTheme.borderColor(ctx);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      await tester.pumpWidget(
        Theme(
          data: AppTheme.auroraGlassTheme,
          child: Builder(
            builder: (ctx) {
              cardAurora = AppTheme.cardColor(ctx);
              borderAurora = AppTheme.borderColor(ctx);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(cardLight, equals(Colors.white));
      expect(cardDark, equals(AppTheme.darkCard));
      expect(cardAurora, equals(AppTheme.auroraGlassCard));

      expect(borderLight, equals(AppTheme.lightBorder));
      expect(borderDark, equals(AppTheme.darkBorder));
      expect(borderAurora, equals(AppTheme.auroraBorder));
    });
  });

  group('ThemeProvider State Management', () {
    test('Defaults to Light and supports setting all 3 modes', () {
      final provider = ThemeProvider();
      expect(provider.currentThemeMode, equals(AppThemeMode.light));
      expect(provider.isAuroraGlass, isFalse);
      expect(provider.isDark, isFalse);
      expect(provider.currentTheme, equals(AppThemeMode.light));
      expect(provider.themeMode, equals(ThemeMode.light));

      // Switch to Dark
      provider.setThemeMode(AppThemeMode.dark);
      expect(provider.currentThemeMode, equals(AppThemeMode.dark));
      expect(provider.isAuroraGlass, isFalse);
      expect(provider.isDark, isTrue);
      expect(provider.currentTheme, equals(AppThemeMode.dark));
      expect(provider.themeMode, equals(ThemeMode.dark));

      // Switch to Aurora Glass
      provider.setThemeMode(AppThemeMode.auroraGlass);
      expect(provider.currentThemeMode, equals(AppThemeMode.auroraGlass));
      expect(provider.isAuroraGlass, isTrue);
      expect(provider.isDark, isTrue); // Aurora is dark-palette
      expect(provider.currentTheme, equals(AppThemeMode.auroraGlass));
      expect(provider.themeMode, equals(ThemeMode.dark));

      // Switch back to Light
      provider.setThemeMode(AppThemeMode.light);
      expect(provider.currentThemeMode, equals(AppThemeMode.light));
      expect(provider.isAuroraGlass, isFalse);
      expect(provider.isDark, isFalse);
    });

    test('toggleTheme backwards-compatibility preserves boolean toggle', () {
      final provider = ThemeProvider();
      provider.toggleTheme(true);
      expect(provider.currentThemeMode, equals(AppThemeMode.dark));
      expect(provider.isDark, isTrue);

      provider.toggleTheme(false);
      expect(provider.currentThemeMode, equals(AppThemeMode.light));
      expect(provider.isDark, isFalse);
    });
  });

  group('AppearanceScreen Widget UI', () {
    testWidgets('Renders all 3 theme options including Aurora Glass', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final provider = ThemeProvider();

      await tester.pumpWidget(
        ChangeNotifierProvider<ThemeProvider>.value(
          value: provider,
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            home: const AppearanceScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify header and theme titles
      expect(find.text('Appearance'), findsOneWidget);
      expect(find.text('CHOOSE THEME'), findsOneWidget);
      expect(find.text('Light Theme'), findsOneWidget);
      expect(find.text('Dark Theme'), findsOneWidget);
      expect(find.text('Aurora Glass'), findsOneWidget);

      // Verify badges on Aurora Glass
      expect(find.text('NEW'), findsOneWidget);
      expect(find.text('GLASS'), findsOneWidget);

      // Tap on Aurora Glass option
      await tester.tap(find.text('Aurora Glass'));
      await tester.pumpAndSettle();

      expect(provider.currentThemeMode, equals(AppThemeMode.auroraGlass));
      expect(provider.isAuroraGlass, isTrue);

      // Tap on Dark option
      await tester.tap(find.text('Dark Theme'));
      await tester.pumpAndSettle();

      expect(provider.currentThemeMode, equals(AppThemeMode.dark));
      expect(provider.isAuroraGlass, isFalse);

      // Tap on Light option
      await tester.tap(find.text('Light Theme'));
      await tester.pumpAndSettle();

      expect(provider.currentThemeMode, equals(AppThemeMode.light));
      expect(provider.isAuroraGlass, isFalse);
    });
  });
}
