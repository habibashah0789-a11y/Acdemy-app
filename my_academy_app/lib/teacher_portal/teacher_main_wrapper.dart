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

import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/web_adaptive_layout.dart';

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

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Logout'),
        content: const Text('Are you sure you want to log out of the Teacher Portal?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await FirebaseAuth.instance.signOut();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Logout', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final navItems = [
      const WebNavItem(
        icon: Icons.dashboard_outlined,
        activeIcon: Icons.dashboard_rounded,
        label: 'Dashboard',
      ),
      const WebNavItem(
        icon: Icons.people_outline_rounded,
        activeIcon: Icons.people_rounded,
        label: 'My Students',
      ),
      const WebNavItem(
        icon: Icons.account_balance_wallet_outlined,
        activeIcon: Icons.account_balance_wallet_rounded,
        label: 'Payment Ledger',
      ),
      WebNavItem(
        icon: Icons.notifications_outlined,
        activeIcon: Icons.notifications_rounded,
        label: 'Notices',
        badge: ValueListenableBuilder<int>(
          valueListenable: NotificationService.teacherUnreadNoticesCount,
          builder: (context, unreadCount, _) {
            if (unreadCount <= 0) return const SizedBox.shrink();
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.redAccent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$unreadCount',
                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            );
          },
        ),
      ),
      const WebNavItem(
        icon: Icons.person_outline_rounded,
        activeIcon: Icons.person_rounded,
        label: 'Profile',
      ),
    ];

    return WebAdaptiveLayout(
      currentIndex: _currentIndex,
      onIndexChanged: (i) => setState(() => _currentIndex = i),
      items: navItems,
      roleTitle: 'Faculty • ${widget.teacher.subject}',
      userName: widget.teacher.name,
      userSubtitle: '${widget.teacher.subject} • ${widget.teacher.section}',
      onLogout: () => _confirmLogout(context),
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
    );
  }
}
