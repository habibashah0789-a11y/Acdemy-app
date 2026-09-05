import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/teacher_model.dart';
import '../theme/app_theme.dart';
import 'teacher_dashboard_screen.dart';
import 'teacher_students_screen.dart';
import 'teacher_notifications_screen.dart';
import 'teacher_profile_screen.dart';

import 'teacher_payout_ledger_screen.dart';

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

    if (isWide) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: _currentIndex,
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
                        color: AppTheme.primaryBlue,
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
                        color: AppTheme.lightTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              destinations: _navItems
                  .map((item) => NavigationRailDestination(
                        icon: Icon(item.icon),
                        selectedIcon: Icon(item.activeIcon),
                        label: Text(item.label,
                            style: GoogleFonts.poppins(fontSize: 11)),
                      ))
                  .toList(),
            ),
            const VerticalDivider(width: 1, thickness: 1),
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
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        items: _navItems
            .map((item) => BottomNavigationBarItem(
                  icon: Icon(item.icon),
                  activeIcon: Icon(item.activeIcon),
                  label: item.label,
                ))
            .toList(),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _NavItem(this.icon, this.activeIcon, this.label);
}
