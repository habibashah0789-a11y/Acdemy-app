import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:my_academy_app/provider/theme_provider.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';

class AppearanceScreen extends StatelessWidget {
  const AppearanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Appearance'),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
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
          
          Row(
            children: [
              Expanded(
                child: _ThemeOptionCard(
                  title: 'Light Theme',
                  isSelected: !isDark,
                  onTap: () => themeProvider.toggleTheme(false),
                  backgroundColor: Colors.white,
                  textColor: Colors.black87,
                  icon: Icons.light_mode_rounded,
                  iconColor: Colors.orange,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _ThemeOptionCard(
                  title: 'Dark Theme',
                  isSelected: isDark,
                  onTap: () => themeProvider.toggleTheme(true),
                  backgroundColor: Colors.grey.shade900,
                  textColor: Colors.white,
                  icon: Icons.dark_mode_rounded,
                  iconColor: Colors.indigo,
                ),
              ),
            ],
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
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0C0C0C) : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryBlue.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.school_rounded,
                            color: AppTheme.primaryBlue,
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
                                isDark ? 'Dark theme is active' : 'Light theme is active',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: isDark
                                      ? Colors.grey.shade400
                                      : Colors.grey.shade600,
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
          ),
        ],
      ),
    );
  }
}

class _ThemeOptionCard extends StatelessWidget {
  final String title;
  final bool isSelected;
  final VoidCallback onTap;
  final Color backgroundColor;
  final Color textColor;
  final IconData icon;
  final Color iconColor;

  const _ThemeOptionCard({
    required this.title,
    required this.isSelected,
    required this.onTap,
    required this.backgroundColor,
    required this.textColor,
    required this.icon,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkCard = backgroundColor == Colors.grey.shade900;
    
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        height: 160,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppTheme.primaryBlue : (isDarkCard ? Colors.grey.shade800 : Colors.grey.shade200),
            width: isSelected ? 2.5 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppTheme.primaryBlue.withValues(alpha: 0.15),
                    blurRadius: 8,
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
            // Theme Visual mockup
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Mini AppBar
                  Container(
                    height: 20,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: isSelected ? AppTheme.primaryBlue : (isDarkCard ? const Color(0xFF1E1E1E) : Colors.grey.shade200),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 4.0),
                        child: Container(
                          height: 4,
                          width: 25,
                          color: isSelected ? Colors.white70 : (isDarkCard ? Colors.grey.shade700 : Colors.grey.shade400),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Mini List Tiles
                  for (int i = 0; i < 2; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6.0),
                      child: Row(
                        children: [
                          Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              color: isDarkCard ? Colors.grey.shade800 : Colors.grey.shade300,
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
                                  color: isDarkCard ? Colors.grey.shade800 : Colors.grey.shade300,
                                ),
                                const SizedBox(height: 3),
                                Container(
                                  height: 3,
                                  width: 30,
                                  color: isDarkCard ? const Color(0xFF1E1E1E) : Colors.grey.shade200,
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
                      ? AppTheme.primaryBlue.withValues(alpha: 0.1) 
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
                    Text(
                      title,
                      style: GoogleFonts.poppins(
                        color: textColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Icon(
                      isSelected ? Icons.check_circle_rounded : icon,
                      size: 15,
                      color: isSelected ? AppTheme.primaryBlue : iconColor,
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