import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../services/notification_service.dart';
import 'student_auth_service.dart';
import 'student_dashboard_screen.dart';
import 'student_fee_screen.dart';
import 'student_notifications_screen.dart';
import 'student_profile_screen.dart';

class StudentMainWrapper extends StatefulWidget {
  const StudentMainWrapper({super.key});

  @override
  State<StudentMainWrapper> createState() => _StudentMainWrapperState();
}

class _StudentMainWrapperState extends State<StudentMainWrapper> {
  int _currentIndex = 0;
  late final PageController _pageController;

  final List<Widget> _screens = [
    const StudentDashboardScreen(),
    const StudentFeeScreen(),
    const StudentNotificationsScreen(),
    const StudentProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentIndex);
    _initializeStudentNotifications();
  }

  Future<void> _initializeStudentNotifications() async {
    try {
      final session = await StudentAuthService.getLocalSession();
      if (session != null) {
        final studentId = session['studentId'] as String? ?? '';
        if (studentId.isNotEmpty) {
          await NotificationService.init();
          await NotificationService.registerFcmToken(
            userId: studentId,
            role: 'student',
            studentId: studentId,
          );
          NotificationService.listenForStudent(studentId);
        }
      }
    } catch (e) {
      debugPrint('[StudentMainWrapper] Failed to initialize notifications: $e');
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurface : Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, -4),
            )
          ],
        ),
        child: NavigationBarTheme(
          data: NavigationBarThemeData(
            indicatorColor: AppTheme.primaryBlue.withValues(alpha: 0.14),
            labelTextStyle: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryBlue,
                );
              }
              return GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
              );
            }),
            iconTheme: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return const IconThemeData(color: AppTheme.primaryBlue, size: 24);
              }
              return IconThemeData(
                color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                size: 22,
              );
            }),
          ),
          child: NavigationBar(
            selectedIndex: _currentIndex,
            height: 68,
            elevation: 0,
            backgroundColor: Colors.transparent,
            onDestinationSelected: (index) {
              setState(() => _currentIndex = index);
              _pageController.jumpToPage(index);
            },
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.grid_view_outlined),
                selectedIcon: Icon(Icons.grid_view_rounded),
                label: 'Dashboard',
              ),
              NavigationDestination(
                icon: Icon(Icons.account_balance_wallet_outlined),
                selectedIcon: Icon(Icons.account_balance_wallet_rounded),
                label: 'Fees',
              ),
              NavigationDestination(
                icon: Icon(Icons.notifications_none_rounded),
                selectedIcon: Icon(Icons.notifications_rounded),
                label: 'Notices',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline_rounded),
                selectedIcon: Icon(Icons.person_rounded),
                label: 'Profile',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
