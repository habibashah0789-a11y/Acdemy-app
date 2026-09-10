import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/teacher_model.dart';
import '../theme/app_theme.dart';
import 'teacher_dashboard_screen.dart';
import 'teacher_students_screen.dart';
import 'teacher_notifications_screen.dart';
import 'teacher_profile_screen.dart';
import 'teacher_payout_ledger_screen.dart';
import '../services/notification_service.dart';

class TeacherMainWrapper extends StatefulWidget {
  final TeacherModel teacher;
  const TeacherMainWrapper({super.key, required this.teacher});

  @override
  State<TeacherMainWrapper> createState() => _TeacherMainWrapperState();
}

class _TeacherMainWrapperState extends State<TeacherMainWrapper> {
  int _currentIndex = 0;

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      TeacherDashboardScreen(teacher: widget.teacher),
      TeacherStudentsScreen(teacher: widget.teacher),
      TeacherPayoutLedgerScreen(teacher: widget.teacher),
      TeacherNotificationsScreen(teacher: widget.teacher),
      TeacherProfileScreen(teacher: widget.teacher),
    ];
    NotificationService.listenForTeacher(widget.teacher);
  }

  @override
  void dispose() {
    NotificationService.cancelTeacherSubscription();
    super.dispose();
  }

  static const List<_NavItem> _navItems = [
    _NavItem(Icons.dashboard_outlined, Icons.dashboard_rounded, 'Dashboard'),
    _NavItem(Icons.people_outline_rounded, Icons.people_rounded, 'My Students'),
    _NavItem(Icons.account_balance_wallet_outlined, Icons.account_balance_wallet_rounded, 'Payment Ledger'),
    _NavItem(Icons.notifications_outlined, Icons.notifications_rounded, 'Notices'),
    _NavItem(Icons.person_outline_rounded, Icons.person_rounded, 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isWide = size.width >= 700;
    final isAurora = AppTheme.isAurora(context);

    if (isWide) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: _currentIndex,
              backgroundColor: isAurora ? AppTheme.auroraSurface : null,
              selectedIconTheme: isAurora ? const IconThemeData(color: AppTheme.auroraCyanHighlight) : null,
              unselectedIconTheme: isAurora ? const IconThemeData(color: AppTheme.auroraTextSecondary) : null,
              selectedLabelTextStyle: isAurora ? GoogleFonts.poppins(fontSize: 11, color: AppTheme.auroraCyanHighlight, fontWeight: FontWeight.bold) : null,
              unselectedLabelTextStyle: isAurora ? GoogleFonts.poppins(fontSize: 11, color: AppTheme.auroraTextSecondary) : null,
              onDestinationSelected: (i) => setState(() => _currentIndex = i),
              labelType: NavigationRailLabelType.all,
              leading: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: isAurora
                            ? const LinearGradient(
                                colors: [Color(0xFF1E3A8A), Color(0xFF7C3AED)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )
                            : null,
                        color: isAurora ? null : AppTheme.primaryBlue,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Center(
                        child: Text('👨‍🏫', style: TextStyle(fontSize: 24)),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Teacher',
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: isAurora ? AppTheme.auroraCyanHighlight : AppTheme.lightTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              destinations: _navItems
                  .map((item) => NavigationRailDestination(
                        icon: _buildIcon(item.icon, item.label),
                        selectedIcon: _buildIcon(item.activeIcon, item.label),
                        label: Text(item.label,
                            style: GoogleFonts.poppins(fontSize: 11)),
                      ))
                  .toList(),
            ),
            VerticalDivider(
              width: 1,
              thickness: 1,
              color: isAurora ? AppTheme.auroraBorder : null,
            ),
            Expanded(child: _screens[_currentIndex]),
          ],
        ),
      );
    }

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: isAurora
            ? const BoxDecoration(
                color: AppTheme.auroraSurface,
                border: Border(
                  top: BorderSide(color: AppTheme.auroraBorder, width: 1.2),
                ),
              )
            : null,
        child: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          currentIndex: _currentIndex,
          backgroundColor: isAurora ? AppTheme.auroraSurface : null,
          selectedItemColor: isAurora ? AppTheme.auroraCyanHighlight : null,
          unselectedItemColor: isAurora ? AppTheme.auroraTextSecondary : null,
          onTap: (i) => setState(() => _currentIndex = i),
          items: _navItems
              .map((item) => BottomNavigationBarItem(
                    icon: _buildIcon(item.icon, item.label),
                    activeIcon: _buildIcon(item.activeIcon, item.label),
                    label: item.label,
                  ))
              .toList(),
        ),
      ),
    );
  }

  Widget _buildIcon(IconData icon, String label) {
    if (label == 'Notices') {
      return ValueListenableBuilder<int>(
        valueListenable: NotificationService.teacherUnreadNoticesCount,
        builder: (context, unreadCount, _) {
          return Badge(
            isLabelVisible: unreadCount > 0,
            label: Text('$unreadCount'),
            child: Icon(icon),
          );
        },
      );
    }
    return Icon(icon);
  }
}

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _NavItem(this.icon, this.activeIcon, this.label);
}
