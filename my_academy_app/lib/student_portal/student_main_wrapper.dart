import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_theme.dart';
import '../services/notification_service.dart';
import 'student_auth_service.dart';
import 'student_dashboard_screen.dart';
import 'student_fee_screen.dart';
import 'student_notifications_screen.dart';
import 'student_profile_screen.dart';
import 'student_login_screen.dart';
import 'package:hive_flutter/hive_flutter.dart';

class StudentMainWrapper extends StatefulWidget {
  const StudentMainWrapper({super.key});

  @override
  State<StudentMainWrapper> createState() => _StudentMainWrapperState();
}

class _StudentMainWrapperState extends State<StudentMainWrapper> {
  int _currentIndex = 0;
  late final PageController _pageController;
  StreamSubscription<DocumentSnapshot>? _studentStatusSubscription;
  StreamSubscription<DocumentSnapshot>? _studentAuthSubscription;

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
        final deviceId = session['deviceId'] as String? ?? '';
        if (studentId.isNotEmpty) {
          await Hive.openBox<bool>('read_notices');
          await NotificationService.init();
          await NotificationService.registerFcmToken(
            userId: studentId,
            role: 'student',
            studentId: studentId,
          );
          NotificationService.listenForStudent(studentId);

          final currentDeviceId = deviceId.isNotEmpty
              ? deviceId
              : await StudentAuthService.getDeviceId();

          _listenToStudentStatus(studentId, currentDeviceId);
        }
      }
    } catch (e) {
      debugPrint('[StudentMainWrapper] Failed to initialize notifications: $e');
    }
  }

  void _listenToStudentStatus(String studentId, String currentDeviceId) {
    _studentStatusSubscription?.cancel();
    _studentStatusSubscription = FirebaseFirestore.instance
        .collection('students')
        .doc(studentId)
        .snapshots()
        .listen((doc) {
      if (!doc.exists && mounted) {
        _handleForceLogout('Your account has been deleted by administration. Please login again.');
      }
    }, onError: (e) {
      debugPrint('[StudentMainWrapper] Student status stream error: $e');
    });

    _studentAuthSubscription?.cancel();
    // _lastKnownLinkedDeviceId starts as null meaning "haven't received first snapshot yet".
    // This lets us distinguish:
    //   null → '' : first snapshot with no binding yet (login race condition) — do NOT logout
    //   'someId' → '' : admin explicitly reset the binding — MUST logout
    //   '' or 'someId' → 'differentId' : different device logged in — MUST logout
    String? _lastKnownLinkedDeviceId;

    _studentAuthSubscription = FirebaseFirestore.instance
        .collection('student_auth')
        .doc(studentId)
        .snapshots()
        .listen((doc) {
      if (!mounted) return;

      if (!doc.exists) {
        _handleForceLogout('Your student authorization has been removed. Please contact admin.');
        return;
      }

      final data = doc.data();
      if (data == null) return;

      final linkedDeviceId = data['linkedDeviceId'] as String? ?? '';

      // First snapshot: record the current binding state and return.
      // If linkedDeviceId is already empty on the first snapshot, it means
      // the login device-binding write hasn't completed yet — do NOT logout.
      // If linkedDeviceId is non-empty on the first snapshot, record it and
      // check it matches the current device.
      if (_lastKnownLinkedDeviceId == null) {
        _lastKnownLinkedDeviceId = linkedDeviceId;

        // On first snapshot: only logout if there's a confirmed device mismatch
        // (a non-empty binding to a DIFFERENT device — meaning this device has
        // no right to be in the portal at all).
        if (linkedDeviceId.isNotEmpty && linkedDeviceId != currentDeviceId) {
          _handleForceLogout('already login on another device');
        }
        return;
      }

      // Subsequent snapshots:
      if (linkedDeviceId.isEmpty && _lastKnownLinkedDeviceId!.isNotEmpty) {
        // Transition: was bound → now empty. Admin explicitly reset the device.
        _lastKnownLinkedDeviceId = linkedDeviceId;
        _handleForceLogout('Your device binding has been reset by administration.');
      } else if (linkedDeviceId.isNotEmpty && linkedDeviceId != currentDeviceId) {
        // A different device is now bound to this account.
        _lastKnownLinkedDeviceId = linkedDeviceId;
        _handleForceLogout('already login on another device');
      } else {
        // Normal update (name, fees, etc.) — just record the new value, do nothing.
        _lastKnownLinkedDeviceId = linkedDeviceId;
      }
    }, onError: (e) {
      debugPrint('[StudentMainWrapper] Student auth stream error: $e');
    });
  }


  Future<void> _handleForceLogout(String message) async {
    _studentStatusSubscription?.cancel();
    _studentAuthSubscription?.cancel();
    final session = await StudentAuthService.getLocalSession();
    if (session != null) {
      final studentId = session['studentId'] as String? ?? '';
      if (studentId.isNotEmpty) {
        try {
          await NotificationService.unregisterFcmToken(userId: studentId);
        } catch (_) {}
        NotificationService.cancelStudentSubscription();
      }
    }
    await StudentAuthService.logout();

    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => StudentLoginScreen(
            message: message,
          ),
        ),
        (_) => false,
      );
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _studentStatusSubscription?.cancel();
    _studentAuthSubscription?.cancel();
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
            destinations: [
              const NavigationDestination(
                icon: Icon(Icons.grid_view_outlined),
                selectedIcon: Icon(Icons.grid_view_rounded),
                label: 'Dashboard',
              ),
              const NavigationDestination(
                icon: Icon(Icons.account_balance_wallet_outlined),
                selectedIcon: Icon(Icons.account_balance_wallet_rounded),
                label: 'Fees',
              ),
              NavigationDestination(
                icon: ValueListenableBuilder<int>(
                  valueListenable: NotificationService.studentUnreadNoticesCount,
                  builder: (context, count, _) {
                    return Badge(
                      isLabelVisible: count > 0,
                      label: Text('$count'),
                      child: const Icon(Icons.notifications_none_rounded),
                    );
                  },
                ),
                selectedIcon: ValueListenableBuilder<int>(
                  valueListenable: NotificationService.studentUnreadNoticesCount,
                  builder: (context, count, _) {
                    return Badge(
                      isLabelVisible: count > 0,
                      label: Text('$count'),
                      child: const Icon(Icons.notifications_rounded),
                    );
                  },
                ),
                label: 'Notices',
              ),
              const NavigationDestination(
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
