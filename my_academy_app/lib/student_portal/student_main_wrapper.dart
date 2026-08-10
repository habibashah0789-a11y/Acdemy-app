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

enum DeviceBindingState {
  checking,
  valid,
  unknown,
  confirmedReset,
  mismatch,
}

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

  // ── Device-binding state machine fields ──────────────────────────────────
  String? _lastKnownLinkedDeviceId;
  DeviceBindingState _bindingState = DeviceBindingState.checking;
  DateTime? _listenerStartTime;

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
    _initializeStudentSession();
  }

  Future<void> _initializeStudentSession() async {
    try {
      final session = await StudentAuthService.getLocalSession();
      if (session != null) {
        final studentId = session['studentId'] as String? ?? '';
        final studentCode = session['studentCode'] as String? ?? '';
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

          _listenToStudentStatus(studentId, currentDeviceId, studentCode: studentCode);
        }
      }
    } catch (e) {
      debugPrint('[StudentMainWrapper] Failed to initialize session: $e');
    }
  }

  void _listenToStudentStatus(String studentId, String currentDeviceId, {String? studentCode}) {
    // Initialize tracking state
    _bindingState = DeviceBindingState.checking;
    _listenerStartTime = DateTime.now();
    _lastKnownLinkedDeviceId = currentDeviceId;

    debugPrint('''
[LOGIN PATH] student_auth/$studentId
[LISTENER PATH] student_auth/$studentId
[DEVICE ID SOURCE] currentDeviceId = $currentDeviceId''');

    // ── Student document stream (for account deletion detection) ──────────
    _studentStatusSubscription?.cancel();
    _studentStatusSubscription = FirebaseFirestore.instance
        .collection('students')
        .doc(studentId)
        .snapshots()
        .listen((doc) {
      if (!doc.exists && mounted) {
        _handleForceLogout(
            'Your account has been deleted by administration. Please login again.');
      }
    }, onError: (e) {
      debugPrint('[StudentMainWrapper] Student status stream error: $e');
    });

    // ── Student auth stream (for device-binding enforcement) ──────────────
    _studentAuthSubscription?.cancel();
    _studentAuthSubscription = FirebaseFirestore.instance
        .collection('student_auth')
        .doc(studentId)
        .snapshots()
        .listen((doc) {
      if (!mounted) return;

      final isFromCache = doc.metadata.isFromCache;
      final hasPendingWrites = doc.metadata.hasPendingWrites;
      final data = doc.data();
      final linkedDeviceId = data?['linkedDeviceId'] as String? ?? '';
      final secondsSinceStart = _listenerStartTime != null
          ? DateTime.now().difference(_listenerStartTime!).inSeconds
          : 999;

      final localMasked = currentDeviceId.length > 8
          ? '${currentDeviceId.substring(0, 4)}...${currentDeviceId.substring(currentDeviceId.length - 4)}'
          : currentDeviceId;
      final remoteMasked = linkedDeviceId.length > 8
          ? '${linkedDeviceId.substring(0, 4)}...${linkedDeviceId.substring(linkedDeviceId.length - 4)}'
          : linkedDeviceId;

      debugPrint('''
==============================
[SESSION BINDING CHECK]
studentCode = ${studentCode ?? ''}
canonicalStudentId = $studentId
documentPath = student_auth/$studentId
documentExists = ${doc.exists}
snapshotFromCache = $isFromCache
hasPendingWrites = $hasPendingWrites
localDeviceId = $localMasked
remoteLinkedDeviceId = $remoteMasked
lastKnownLinkedDeviceId = $_lastKnownLinkedDeviceId
localLength = ${currentDeviceId.length}
remoteLength = ${linkedDeviceId.length}
exactMatch = ${linkedDeviceId == currentDeviceId}
secondsSinceStart = $secondsSinceStart
currentBindingState = $_bindingState
==============================''');

      // RULE 1: Ignore cached / pending write snapshots
      if (isFromCache || hasPendingWrites) {
        debugPrint('[BINDING CHECK] Cached or pending-write snapshot ignored — keeping session active.');
        if (linkedDeviceId == currentDeviceId) {
          _bindingState = DeviceBindingState.valid;
          _lastKnownLinkedDeviceId = linkedDeviceId;
        }
        return;
      }

      // RULE 2: If document does not exist, perform server check
      if (!doc.exists) {
        _confirmServerAndEvaluate(
          studentId: studentId,
          currentDeviceId: currentDeviceId,
          studentCode: studentCode,
          reasonForEmpty: 'document_not_found',
        );
        return;
      }

      // RULE 3: Empty linkedDeviceId case — auto-bind current device & keep session active
      if (linkedDeviceId.isEmpty) {
        debugPrint('[BINDING CHECK] Empty binding observed — auto-binding current device.');
        _lastKnownLinkedDeviceId = currentDeviceId;
        _bindingState = DeviceBindingState.valid;
        StudentAuthService.ensureDeviceBound(
          studentId: studentId,
          currentDeviceId: currentDeviceId,
          studentCode: studentCode,
        );
        return;
      }

      // RULE 4: Non-matching device ID case
      if (linkedDeviceId != currentDeviceId) {
        if (_bindingState == DeviceBindingState.checking || secondsSinceStart < 6) {
          debugPrint('[BINDING CHECK] Device ID mismatch during startup window — verifying with server.');
        }

        _confirmServerAndEvaluate(
          studentId: studentId,
          currentDeviceId: currentDeviceId,
          studentCode: studentCode,
          reasonForEmpty: 'mismatch',
          observedRemoteId: linkedDeviceId,
        );
        return;
      }

      // RULE 5: Exact match confirmed!
      _lastKnownLinkedDeviceId = linkedDeviceId;
      _bindingState = DeviceBindingState.valid;
      debugPrint('DECISION: KEEP SESSION\nREASON: Device binding confirmed active.');
    }, onError: (e) {
      debugPrint('[StudentMainWrapper] Student auth stream error: $e');
    });
  }

  Future<void> _confirmServerAndEvaluate({
    required String studentId,
    required String currentDeviceId,
    String? studentCode,
    required String reasonForEmpty,
    String? observedRemoteId,
  }) async {
    try {
      debugPrint('[BINDING SERVER CONFIRMATION] Performing Source.server read for student_auth/$studentId...');
      final serverDoc = await FirebaseFirestore.instance
          .collection('student_auth')
          .doc(studentId)
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 5));

      if (!mounted) return;

      if (!serverDoc.exists) {
        if (studentCode != null && studentCode.isNotEmpty && studentCode != studentId) {
          final codeDoc = await FirebaseFirestore.instance
              .collection('student_auth')
              .doc(studentCode.trim().toUpperCase())
              .get(const GetOptions(source: Source.server))
              .timeout(const Duration(seconds: 5));

          if (codeDoc.exists && codeDoc.data() != null) {
            final codeDeviceId = codeDoc.data()?['linkedDeviceId'] as String? ?? '';
            if (codeDeviceId == currentDeviceId) {
              _lastKnownLinkedDeviceId = codeDeviceId;
              _bindingState = DeviceBindingState.valid;
              debugPrint('DECISION: KEEP SESSION\nREASON: Server confirmed valid binding under studentCode path ($studentCode).');
              return;
            }
          }
        }

        if (_bindingState != DeviceBindingState.checking) {
          _bindingState = DeviceBindingState.confirmedReset;
          debugPrint('DECISION: FORCE LOGOUT\nREASON: Fresh server read confirmed student_auth record does not exist.');
          _handleForceLogout('Your student authorization has been removed. Please contact admin.');
        } else {
          debugPrint('DECISION: KEEP SESSION\nREASON: Document missing during checking state — keeping session active.');
        }
        return;
      }

      final serverData = serverDoc.data() ?? {};
      final serverDeviceId = serverData['linkedDeviceId'] as String? ?? '';

      if (serverDeviceId == currentDeviceId) {
        _lastKnownLinkedDeviceId = serverDeviceId;
        _bindingState = DeviceBindingState.valid;
        debugPrint('DECISION: KEEP SESSION\nREASON: Source.server confirmed active matching binding ($serverDeviceId).');
        return;
      }

      if (serverDeviceId.isEmpty) {
        debugPrint('DECISION: KEEP SESSION\nREASON: Server read empty binding — auto-binding current device.');
        _lastKnownLinkedDeviceId = currentDeviceId;
        _bindingState = DeviceBindingState.valid;
        StudentAuthService.ensureDeviceBound(
          studentId: studentId,
          currentDeviceId: currentDeviceId,
          studentCode: studentCode,
        );
        return;
      }

      _bindingState = DeviceBindingState.mismatch;
      debugPrint('DECISION: FORCE LOGOUT\nREASON: Authoritative server read confirmed device mismatch ($serverDeviceId vs $currentDeviceId).');
      _handleForceLogout('already login on another device');
    } catch (e) {
      _bindingState = DeviceBindingState.unknown;
      debugPrint('[BINDING SERVER CONFIRMATION] Read failed ($e) — NETWORK ERROR DOES NOT FORCE LOGOUT. Keeping session active.');
    }
  }

  Future<void> _handleForceLogout(String message) async {
    final st = StackTrace.current;
    final session = await StudentAuthService.getLocalSession();
    final sid = session?['studentId'] as String? ?? '';
    final scode = session?['studentCode'] as String? ?? '';

    debugPrint('''
==============================
[STUDENT FORCED LOGOUT]
reason = $message
caller = _handleForceLogout
studentId = $sid
studentCode = $scode
timestamp = ${DateTime.now().toIso8601String()}
stackTrace =
$st
==============================''');

    _studentStatusSubscription?.cancel();
    _studentAuthSubscription?.cancel();
    if (sid.isNotEmpty) {
      try {
        await NotificationService.unregisterFcmToken(userId: sid);
      } catch (_) {}
      NotificationService.cancelStudentSubscription();
    }
    await StudentAuthService.logout();

    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => StudentLoginScreen(message: message),
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
                color: isDark
                    ? AppTheme.darkTextSecondary
                    : AppTheme.lightTextSecondary,
              );
            }),
            iconTheme: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return const IconThemeData(color: AppTheme.primaryBlue, size: 24);
              }
              return IconThemeData(
                color: isDark
                    ? AppTheme.darkTextSecondary
                    : AppTheme.lightTextSecondary,
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
