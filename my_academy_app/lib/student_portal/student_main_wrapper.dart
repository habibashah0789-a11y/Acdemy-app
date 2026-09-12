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
import '../models/student_model.dart';
import '../services/database_service.dart';
import '../widgets/student_avatar.dart';
import '../widgets/web_adaptive_layout.dart';

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
  String? _currentStudentCode;
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
        if (mounted) {
          setState(() {
            _currentStudentCode = studentCode;
          });
        }
        final deviceId = session['deviceId'] as String? ?? '';
        final sessionQrToken = session['qrToken'] as String? ?? '';
        final loginTimeStr = session['loginTime'] as String? ?? '';
        final loginTime = DateTime.tryParse(loginTimeStr);
        final isRecentLogin = loginTime != null &&
            DateTime.now().difference(loginTime).inSeconds < 45;

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

          _listenToStudentStatus(
            studentId,
            currentDeviceId,
            studentCode: studentCode,
            sessionQrToken: sessionQrToken,
            isRecentLogin: isRecentLogin,
          );
        }
      }
    } catch (e) {
      debugPrint('[StudentMainWrapper] Failed to initialize session: $e');
    }
  }

  void _listenToStudentStatus(
    String studentId,
    String currentDeviceId, {
    String? studentCode,
    String? sessionQrToken,
    bool isRecentLogin = false,
  }) {
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
      } else if (doc.exists) {
        try {
          final s = StudentModel.fromFirestore(doc);
          StudentAvatar.invalidateCache(s.id);
          DatabaseService.studentBox.put(s.id, s);
        } catch (_) {}
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
isRecentLogin = $isRecentLogin
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
          isRecentLogin: isRecentLogin,
        );
        return;
      }

      // Check if QR token was regenerated by administration
      final remoteQrToken = data?['qrToken'] as String? ?? '';
      if (sessionQrToken != null &&
          sessionQrToken.isNotEmpty &&
          remoteQrToken.isNotEmpty &&
          remoteQrToken != sessionQrToken) {
        debugPrint('[BINDING CHECK] QR token has been regenerated by admin. Forcing logout.');
        _bindingState = DeviceBindingState.confirmedReset;
        _handleForceLogout('Your QR code pass was regenerated by administration. Please scan your new QR code to log in.');
        return;
      }

      // RULE 3: Empty linkedDeviceId case — indicates admin reset device or regenerated QR
      if (linkedDeviceId.isEmpty) {
        if ((_bindingState == DeviceBindingState.checking || isRecentLogin) && secondsSinceStart < 8) {
          debugPrint('[BINDING CHECK] Empty binding observed during fresh login grace window — binding device to active session.');
          _bindingState = DeviceBindingState.valid;
          _lastKnownLinkedDeviceId = currentDeviceId;
          unawaited(StudentAuthService.ensureDeviceBound(
            studentId: studentId,
            currentDeviceId: currentDeviceId,
            studentCode: studentCode,
          ));
          return;
        }

        debugPrint('[BINDING CHECK] Empty binding observed — session was reset by admin. Forcing logout.');
        _bindingState = DeviceBindingState.confirmedReset;
        _handleForceLogout('Your session has been reset by the administration. Please scan your QR code to log in.');
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
          isRecentLogin: isRecentLogin,
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
    bool isRecentLogin = false,
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

        if (_bindingState != DeviceBindingState.checking && !isRecentLogin) {
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
        if ((_bindingState == DeviceBindingState.checking || isRecentLogin) &&
            DateTime.now().difference(_listenerStartTime ?? DateTime.now()).inSeconds < 8) {
          debugPrint('DECISION: KEEP SESSION\nREASON: Authoritative read empty during fresh login grace window. Binding device.');
          await StudentAuthService.ensureDeviceBound(
            studentId: studentId,
            currentDeviceId: currentDeviceId,
            studentCode: studentCode,
          );
          _bindingState = DeviceBindingState.valid;
          _lastKnownLinkedDeviceId = currentDeviceId;
          return;
        }

        _bindingState = DeviceBindingState.confirmedReset;
        debugPrint('DECISION: FORCE LOGOUT\nREASON: Authoritative server read confirmed empty device binding (admin reset or QR regenerated).');
        _handleForceLogout('Your session has been reset by the administration. Please scan your QR code to log in.');
        return;
      }

      _bindingState = DeviceBindingState.mismatch;
      debugPrint('DECISION: FORCE LOGOUT\nREASON: Authoritative server read confirmed device mismatch ($serverDeviceId vs $currentDeviceId).');
      _handleForceLogout('This student portal is active on another device.');
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

  void _confirmStudentLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Logout'),
        content: const Text('Are you sure you want to log out of the Student Portal?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await StudentAuthService.clearSession();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const StudentLoginScreen()),
                  (_) => false,
                );
              }
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
        icon: Icons.grid_view_outlined,
        activeIcon: Icons.grid_view_rounded,
        label: 'Dashboard',
      ),
      const WebNavItem(
        icon: Icons.account_balance_wallet_outlined,
        activeIcon: Icons.account_balance_wallet_rounded,
        label: 'Fees & Payments',
      ),
      WebNavItem(
        icon: Icons.notifications_none_rounded,
        activeIcon: Icons.notifications_rounded,
        label: 'Notices',
        badge: ValueListenableBuilder<int>(
          valueListenable: NotificationService.studentUnreadNoticesCount,
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
      onIndexChanged: (index) {
        setState(() => _currentIndex = index);
      },
      items: navItems,
      roleTitle: 'Student Portal',
      userName: _currentStudentCode ?? 'Student',
      onLogout: () => _confirmStudentLogout(context),
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
    );
  }
}
