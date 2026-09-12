import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../provider/theme_provider.dart';

class WebNavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final Widget? badge;

  const WebNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    this.badge,
  });
}

/// Adaptive layout scaffold that provides a desktop sidebar, tablet rail,
/// and mobile bottom navigation across all three portals (Admin, Teacher, Student).
class WebAdaptiveLayout extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onIndexChanged;
  final List<WebNavItem> items;
  final Widget body;
  final String roleTitle;
  final String? userName;
  final String? userSubtitle;
  final Widget? avatarWidget;
  final List<Widget>? headerActions;
  final Widget? floatingActionButton;
  final VoidCallback? onLogout;

  const WebAdaptiveLayout({
    super.key,
    required this.currentIndex,
    required this.onIndexChanged,
    required this.items,
    required this.body,
    required this.roleTitle,
    this.userName,
    this.userSubtitle,
    this.avatarWidget,
    this.headerActions,
    this.floatingActionButton,
    this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width >= 1024;
    final isTablet = size.width >= 700 && size.width < 1024;

    if (isDesktop) {
      return _buildDesktopLayout(context);
    } else if (isTablet) {
      return _buildTabletLayout(context);
    } else {
      return _buildMobileLayout(context);
    }
  }

  // ── 1. Desktop Layout (Width >= 1024px) ────────────────────────────────────
  Widget _buildDesktopLayout(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isAurora = AppTheme.isAurora(context);

    return Scaffold(
      backgroundColor: isAurora
          ? AppTheme.auroraBackground
          : (isDark ? AppTheme.darkBackground : AppTheme.lightBackground),
      floatingActionButton: floatingActionButton,
      body: Row(
        children: [
          // Fixed Left Sidebar
          Container(
            width: 260,
            decoration: BoxDecoration(
              color: isAurora
                  ? AppTheme.auroraSurface
                  : (isDark ? AppTheme.darkSurface : Colors.white),
              border: Border(
                right: BorderSide(
                  color: isAurora
                      ? AppTheme.auroraBorder
                      : (isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
                  width: 1.2,
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                  blurRadius: 10,
                  offset: const Offset(2, 0),
                ),
              ],
            ),
            child: Column(
              children: [
                // Academy Brand Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                  child: Row(
                    children: [
                      Image.asset(
                        'assets/images/Quaid Academy logo.png',
                        width: 42,
                        height: 42,
                        errorBuilder: (_, __, ___) => Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: AppTheme.primaryBlue,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.school_rounded, color: Colors.white, size: 24),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Quaid Academy',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: isAurora
                                    ? AppTheme.auroraCyanHighlight
                                    : (isDark ? Colors.white : AppTheme.primaryDarkBlue),
                              ),
                            ),
                            Text(
                              '"From Here It Is Possible"',
                              style: GoogleFonts.poppins(
                                fontSize: 9.5,
                                fontStyle: FontStyle.italic,
                                color: AppTheme.secondaryGreen,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // User Info Card
                if (userName != null || userSubtitle != null)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: isAurora
                          ? AppTheme.auroraGlassCard
                          : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9)),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isAurora ? AppTheme.auroraBorder : Colors.transparent,
                      ),
                    ),
                    child: Row(
                      children: [
                        avatarWidget ??
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: AppTheme.primaryBlue,
                              child: Text(
                                (userName?.isNotEmpty ?? false)
                                    ? userName![0].toUpperCase()
                                    : 'U',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                            ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (userName != null)
                                Text(
                                  userName!,
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12.5,
                                    color: isDark ? Colors.white : AppTheme.primaryDarkBlue,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              Container(
                                margin: const EdgeInsets.only(top: 2),
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryBlue.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  roleTitle,
                                  style: GoogleFonts.poppins(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.bold,
                                    color: isAurora ? AppTheme.auroraCyanHighlight : AppTheme.primaryBlue,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                const Divider(height: 16, indent: 16, endIndent: 16),

                // Navigation Items List
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    itemCount: items.length,
                    itemBuilder: (context, i) {
                      final item = items[i];
                      final isSelected = currentIndex == i;
                      final primaryColor = isAurora
                          ? AppTheme.auroraCyanHighlight
                          : AppTheme.primaryBlue;

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => onIndexChanged(i),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? primaryColor.withValues(alpha: 0.12)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                                border: isSelected
                                    ? Border.all(color: primaryColor.withValues(alpha: 0.3), width: 1)
                                    : null,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    isSelected ? item.activeIcon : item.icon,
                                    size: 20,
                                    color: isSelected
                                        ? primaryColor
                                        : (isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Text(
                                      item.label,
                                      style: GoogleFonts.poppins(
                                        fontSize: 13,
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                        color: isSelected
                                            ? primaryColor
                                            : (isDark ? Colors.white70 : AppTheme.primaryDarkBlue),
                                      ),
                                    ),
                                  ),
                                  if (item.badge != null) item.badge!,
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // Bottom Controls: Theme Mode & Logout
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Consumer<ThemeProvider>(
                        builder: (_, themeProvider, __) {
                          return IconButton(
                            tooltip: 'Switch Theme',
                            icon: Icon(
                              isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                              size: 19,
                              color: isDark ? Colors.white70 : Colors.black54,
                            ),
                            onPressed: () => themeProvider.toggleTheme(),
                          );
                        },
                      ),
                      const Spacer(),
                      if (onLogout != null)
                        TextButton.icon(
                          onPressed: onLogout,
                          icon: const Icon(Icons.logout_rounded, size: 16, color: Colors.redAccent),
                          label: Text(
                            'Logout',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.redAccent,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Main Center Content
          Expanded(
            child: Column(
              children: [
                // Top App Header
                Container(
                  height: 56,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  decoration: BoxDecoration(
                    color: isAurora
                        ? AppTheme.auroraSurface
                        : (isDark ? AppTheme.darkSurface : Colors.white),
                    border: Border(
                      bottom: BorderSide(
                        color: isAurora
                            ? AppTheme.auroraBorder
                            : (isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(
                        items.isNotEmpty && currentIndex < items.length
                            ? items[currentIndex].label
                            : roleTitle,
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: isDark ? Colors.white : AppTheme.primaryDarkBlue,
                        ),
                      ),
                      const Spacer(),
                      if (headerActions != null) ...headerActions!,
                    ],
                  ),
                ),
                // Body View
                Expanded(child: body),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── 2. Tablet Layout (Width 700px - 1023px) ───────────────────────────────
  Widget _buildTabletLayout(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isAurora = AppTheme.isAurora(context);

    return Scaffold(
      backgroundColor: isAurora
          ? AppTheme.auroraBackground
          : (isDark ? AppTheme.darkBackground : AppTheme.lightBackground),
      floatingActionButton: floatingActionButton,
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: currentIndex,
            onDestinationSelected: onIndexChanged,
            labelType: NavigationRailLabelType.selected,
            backgroundColor: isAurora
                ? AppTheme.auroraSurface
                : (isDark ? AppTheme.darkSurface : Colors.white),
            selectedIconTheme: IconThemeData(
              color: isAurora ? AppTheme.auroraCyanHighlight : AppTheme.primaryBlue,
            ),
            unselectedIconTheme: IconThemeData(
              color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
            ),
            selectedLabelTextStyle: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: isAurora ? AppTheme.auroraCyanHighlight : AppTheme.primaryBlue,
            ),
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Image.asset(
                'assets/images/Quaid Academy logo.png',
                width: 36,
                height: 36,
                errorBuilder: (_, __, ___) => const Icon(Icons.school_rounded, color: AppTheme.primaryBlue, size: 28),
              ),
            ),
            destinations: items
                .map((item) => NavigationRailDestination(
                      icon: Icon(item.icon),
                      selectedIcon: Icon(item.activeIcon),
                      label: Text(item.label),
                    ))
                .toList(),
          ),
          VerticalDivider(
            width: 1,
            thickness: 1,
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
          ),
          Expanded(child: body),
        ],
      ),
    );
  }

  // ── 3. Mobile Layout (Width < 700px) ──────────────────────────────────────
  Widget _buildMobileLayout(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isAurora = AppTheme.isAurora(context);
    final tokens = AppTheme.tokens(context);

    return Scaffold(
      backgroundColor: isAurora
          ? AppTheme.auroraBackground
          : (isDark ? AppTheme.darkBackground : AppTheme.lightBackground),
      floatingActionButton: floatingActionButton,
      body: body,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: tokens.navBar,
          border: Border(
            top: BorderSide(
              color: isAurora ? AppTheme.auroraBorder : tokens.border.withValues(alpha: 0.5),
              width: 1,
            ),
          ),
        ),
        child: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          currentIndex: currentIndex.clamp(0, items.length - 1),
          backgroundColor: tokens.navBar,
          selectedItemColor: isAurora ? AppTheme.auroraCyanHighlight : tokens.navBarSelected,
          unselectedItemColor: isAurora ? AppTheme.auroraTextSecondary : tokens.navBarUnselected,
          selectedLabelStyle: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold),
          unselectedLabelStyle: GoogleFonts.poppins(fontSize: 10),
          onTap: onIndexChanged,
          items: items
              .map((item) => BottomNavigationBarItem(
                    icon: Icon(item.icon),
                    activeIcon: Icon(item.activeIcon),
                    label: item.label,
                  ))
              .toList(),
        ),
      ),
    );
  }
}
