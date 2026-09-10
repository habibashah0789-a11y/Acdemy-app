import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:my_academy_app/provider/theme_provider.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import 'theme_selection_screen.dart';

class AppearanceScreen extends StatelessWidget {
  const AppearanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final currentTheme = themeProvider.currentTheme;
    final currentPalette = themeProvider.currentPalette;
    final isDark = themeProvider.isDark;
    final isAurora = themeProvider.isAuroraGlass;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Appearance'),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ── Current Theme Banner ──────────────────────────────────
          Text(
            'CURRENT THEME',
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: currentPalette.tokens.headerGradient,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: currentPalette.tokens.primary.withValues(alpha: 0.25),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                Text(currentPalette.emoji, style: const TextStyle(fontSize: 32)),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        currentPalette.name,
                        style: GoogleFonts.poppins(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        currentPalette.description,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ThemeSelectionScreen(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: currentPalette.tokens.primary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Change Theme',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          Text(
            'CHOOSE THEME',
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 16),

          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 640;

              final lightOption = _ThemeOptionCard(
                title: 'Light Theme',
                subtitle: 'Clean & Bright',
                isSelected: currentTheme == AppThemeMode.light,
                onTap: () => themeProvider.setThemeMode(AppThemeMode.light),
                backgroundColor: Colors.white,
                textColor: Colors.black87,
                icon: Icons.light_mode_rounded,
                iconColor: Colors.orange,
              );

              final darkOption = _ThemeOptionCard(
                title: 'Dark Theme',
                subtitle: 'Slate Charcoal',
                isSelected: currentTheme == AppThemeMode.dark,
                onTap: () => themeProvider.setThemeMode(AppThemeMode.dark),
                backgroundColor: Colors.grey.shade900,
                textColor: Colors.white,
                icon: Icons.dark_mode_rounded,
                iconColor: Colors.indigo,
              );

              final auroraOption = _ThemeOptionCard(
                title: 'Aurora Glass',
                subtitle: 'Midnight Navy & Glass',
                isSelected: currentTheme == AppThemeMode.auroraGlass,
                onTap: () => themeProvider.setThemeMode(AppThemeMode.auroraGlass),
                backgroundColor: const Color(0xFF070B14),
                textColor: Colors.white,
                icon: Icons.auto_awesome_rounded,
                iconColor: const Color(0xFF06B6D4),
                isAurora: true,
              );

              if (isWide) {
                return Row(
                  children: [
                    Expanded(child: lightOption),
                    const SizedBox(width: 14),
                    Expanded(child: darkOption),
                    const SizedBox(width: 14),
                    Expanded(child: auroraOption),
                  ],
                );
              }

              return Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: lightOption),
                      const SizedBox(width: 14),
                      Expanded(child: darkOption),
                    ],
                  ),
                  const SizedBox(height: 14),
                  auroraOption,
                ],
              );
            },
          ),

          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ThemeSelectionScreen()),
                );
              },
              icon: const Icon(Icons.palette_rounded),
              label: Text(
                'Explore All 10 Themes & Visual Styles',
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),

          const SizedBox(height: 32),

          Text(
            'LIVE PREVIEW',
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 16),

          // ── Preview card ───────────────────────────────────────────────
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: BorderSide(
                color: isAurora
                    ? AppTheme.auroraBorder
                    : (isDark ? Colors.grey.shade800 : Colors.grey.shade200),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isAurora
                          ? AppTheme.auroraGlassCard
                          : (isDark ? const Color(0xFF0C0C0C) : Colors.grey.shade50),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isAurora
                            ? AppTheme.auroraBorder
                            : (isDark ? Colors.grey.shade800 : Colors.grey.shade200),
                      ),
                      boxShadow: isAurora
                          ? [
                              BoxShadow(
                                color: const Color(0xFF020617).withValues(alpha: 0.6),
                                blurRadius: 16,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : null,
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            gradient: isAurora
                                ? const LinearGradient(
                                    colors: [Color(0xFF2563EB), Color(0xFF7C3AED)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  )
                                : null,
                            color: isAurora
                                ? null
                                : AppTheme.primaryBlue.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: isAurora
                                ? [
                                    BoxShadow(
                                      color: const Color(0xFF06B6D4).withValues(alpha: 0.25),
                                      blurRadius: 12,
                                      offset: const Offset(0, 2),
                                    )
                                  ]
                                : null,
                          ),
                          child: Icon(
                            isAurora ? Icons.auto_awesome_rounded : Icons.school_rounded,
                            color: isAurora ? Colors.white : AppTheme.primaryBlue,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Quaid Academy App',
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                isAurora
                                    ? '✨ Aurora Glass theme is active'
                                    : (isDark ? 'Dark theme is active' : 'Light theme is active'),
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: isAurora
                                      ? const Color(0xFF38BDF8)
                                      : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isAurora)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: const Color(0xFF06B6D4).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: const Color(0xFF06B6D4).withValues(alpha: 0.4),
                              ),
                            ),
                            child: Text(
                              'GLASS',
                              style: GoogleFonts.poppins(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF38BDF8),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ThemeOptionCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool isSelected;
  final VoidCallback onTap;
  final Color backgroundColor;
  final Color textColor;
  final IconData icon;
  final Color iconColor;
  final bool isAurora;

  const _ThemeOptionCard({
    required this.title,
    this.subtitle,
    required this.isSelected,
    required this.onTap,
    required this.backgroundColor,
    required this.textColor,
    required this.icon,
    required this.iconColor,
    this.isAurora = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkCard = backgroundColor == Colors.grey.shade900 || isAurora;

    Color borderColor;
    if (isSelected) {
      borderColor = isAurora ? const Color(0xFF38BDF8) : AppTheme.primaryBlue;
    } else {
      borderColor = isAurora
          ? const Color(0x3338BDF8)
          : (isDarkCard ? Colors.grey.shade800 : Colors.grey.shade200);
    }

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        height: 160,
        decoration: BoxDecoration(
          color: isAurora ? const Color(0xFF070B14) : backgroundColor,
          gradient: isAurora
              ? const LinearGradient(
                  colors: [Color(0xFF070B14), Color(0xFF0D1527), Color(0xFF131F3A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: borderColor,
            width: isSelected ? 2.5 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: (isAurora ? const Color(0xFF06B6D4) : AppTheme.primaryBlue)
                        .withValues(alpha: 0.25),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  )
                ],
        ),
        child: Stack(
          children: [
            if (isAurora)
              Positioned(
                top: 8,
                right: 8,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF38BDF8), Color(0xFF8B5CF6)],
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'NEW',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0x3338BDF8),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0x6638BDF8), width: 0.5),
                      ),
                      child: const Text(
                        'GLASS',
                        style: TextStyle(
                          color: Color(0xFF38BDF8),
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            // Theme Visual mockup
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 44),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Mini AppBar
                  Container(
                    height: 20,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: isAurora
                          ? const LinearGradient(
                              colors: [Color(0xFF1E3A8A), Color(0xFF7C3AED)],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            )
                          : null,
                      color: isAurora
                          ? null
                          : (isSelected
                              ? AppTheme.primaryBlue
                              : (isDarkCard ? const Color(0xFF1E1E1E) : Colors.grey.shade200)),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 6.0),
                        child: Container(
                          height: 4,
                          width: 25,
                          color: isSelected
                              ? Colors.white70
                              : (isDarkCard ? Colors.grey.shade700 : Colors.grey.shade400),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Mini Glass List Tiles
                  for (int i = 0; i < 2; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6.0),
                      child: Row(
                        children: [
                          Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              color: isAurora
                                  ? (i == 0 ? const Color(0xFF38BDF8) : const Color(0xFF8B5CF6))
                                  : (isDarkCard ? Colors.grey.shade800 : Colors.grey.shade300),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  height: 5,
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: isAurora
                                        ? const Color(0xFF1E293B)
                                        : (isDarkCard ? Colors.grey.shade800 : Colors.grey.shade300),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Container(
                                  height: 3,
                                  width: 30,
                                  decoration: BoxDecoration(
                                    color: isAurora
                                        ? const Color(0xFF38BDF8).withValues(alpha: 0.4)
                                        : (isDarkCard ? const Color(0xFF1E1E1E) : Colors.grey.shade200),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            // Bottom Title Bar
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                decoration: BoxDecoration(
                  color: isSelected
                      ? (isAurora
                          ? const Color(0xFF06B6D4).withValues(alpha: 0.15)
                          : AppTheme.primaryBlue.withValues(alpha: 0.1))
                      : (isDarkCard ? const Color(0xFF1E1E1E) : Colors.grey.shade50),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(14),
                    bottomRight: Radius.circular(14),
                  ),
                ),
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          style: GoogleFonts.poppins(
                            color: textColor,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (subtitle != null)
                          Text(
                            subtitle!,
                            style: GoogleFonts.poppins(
                              color: isDarkCard ? Colors.grey.shade400 : Colors.grey.shade600,
                              fontSize: 9,
                            ),
                          ),
                      ],
                    ),
                    Icon(
                      isSelected ? Icons.check_circle_rounded : icon,
                      size: 16,
                      color: isSelected
                          ? (isAurora ? const Color(0xFF06B6D4) : AppTheme.primaryBlue)
                          : iconColor,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}