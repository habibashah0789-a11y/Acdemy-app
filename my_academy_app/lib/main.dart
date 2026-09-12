import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';

// Models
import 'models/student_model.dart';
import 'models/recycled_student.dart';

// Services
import 'services/database_service.dart';
import 'services/notification_service.dart';
import 'services/sync_service.dart';
import 'student_portal/student_auth_service.dart';

// Providers
import 'provider/theme_provider.dart';

// Screens
import 'screens/main_wrapper.dart';
import 'screens/role_selection_screen.dart';
import 'screens/reset_password_screen.dart';
import 'screens/landing/web_landing_screen.dart';
import 'student_portal/student_main_wrapper.dart';

// Teacher portal
import 'teacher_portal/teacher_main_wrapper.dart';
import 'services/teacher_service.dart';
import 'models/teacher_model.dart';

// Loading
import 'widgets/portal_loading_screen.dart';


import 'package:firebase_messaging/firebase_messaging.dart';

// Firebase options
import 'firebase_options.dart';

import 'config/supabase_config.dart';
import 'core/hybrid_backend.dart';

Future<void> main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  final app = await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await SupabaseConfig.init();
  HybridBackend.printDiagnostics().catchError((e) => debugPrint('[HYBRID BACKEND] Diagnostics error: $e'));

  if (!kIsWeb) {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  }

  debugPrint('[FIREBASE CONFIG] platform = ${defaultTargetPlatform.name}');
  debugPrint('[FIREBASE CONFIG] projectId = ${app.options.projectId}');
  debugPrint('[FIREBASE CONFIG] appId = ${app.options.appId}');
  debugPrint('[FIREBASE CONFIG] storageBucket = ${app.options.storageBucket}');

  await Hive.initFlutter();

  if (!Hive.isAdapterRegistered(0)) {
    Hive.registerAdapter(StudentModelAdapter());
  }
  if (!Hive.isAdapterRegistered(1)) {
    Hive.registerAdapter(RecycledStudentAdapter());
  }

  await DatabaseService.init();
  await NotificationService.init(key: appNavigatorKey);

  final themeProvider = ThemeProvider();
  await themeProvider.init();

  final syncService = SyncService();
  await syncService.init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: themeProvider),
        ChangeNotifierProvider.value(value: syncService),
      ],
      child: const MyApp(),
    ),
  );

  FlutterNativeSplash.remove();
}

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      navigatorKey: appNavigatorKey,
      title: 'Quaid Academy',
      debugShowCheckedModeBanner: false,
      theme: themeProvider.currentThemeData,
      darkTheme: themeProvider.currentThemeData,
      themeMode: themeProvider.themeMode,
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  Map<String, String>? _resetParams;

  @override
  void initState() {
    super.initState();
    _checkUrlParams();
  }

  void _checkUrlParams() {
    try {
      final uri = Uri.base;
      String? mode = uri.queryParameters['mode'];
      String? oobCode = uri.queryParameters['oobCode'];
      String? email = uri.queryParameters['email'];
      String? role = uri.queryParameters['role'];

      // Also support hash routing format (#/?mode=resetPassword&oobCode=...)
      if ((oobCode == null || oobCode.isEmpty) && uri.fragment.isNotEmpty) {
        final fragment = uri.fragment;
        if (fragment.contains('?')) {
          final queryPart = fragment.substring(fragment.indexOf('?') + 1);
          final params = Uri.splitQueryString(queryPart);
          mode ??= params['mode'];
          oobCode ??= params['oobCode'];
          email ??= params['email'];
          role ??= params['role'];
        }
      }

      if (mode == 'resetPassword' && oobCode != null && oobCode.isNotEmpty) {
        setState(() {
          _resetParams = {
            'oobCode': oobCode!,
            if (email != null) 'email': email,
            if (role != null) 'role': role,
          };
        });
      }
    } catch (e) {
      debugPrint('[AuthWrapper] Error checking URL params: $e');
    }
  }

  Widget _buildStartupSplash(BuildContext context) {
    return const Scaffold(
      body: BeautifulLoadingWidget(
        message: 'Initializing Quaid Academy...',
        size: 88,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // If opened via password reset link from email, show ResetPasswordScreen immediately
    if (_resetParams != null) {
      return ResetPasswordScreen(
        oobCode: _resetParams!['oobCode']!,
        emailHint: _resetParams!['email'],
        roleHint: _resetParams!['role'],
      );
    }

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildStartupSplash(context);
        }
        if (snapshot.hasData && snapshot.data != null) {
          return RoleRoutingWrapper(user: snapshot.data!);
        }
        return const StudentPortalEntryWrapper();
      },
    );
  }
}

class StudentPortalEntryWrapper extends StatefulWidget {
  const StudentPortalEntryWrapper({super.key});

  @override
  State<StudentPortalEntryWrapper> createState() =>
      _StudentPortalEntryWrapperState();
}

class _StudentPortalEntryWrapperState extends State<StudentPortalEntryWrapper> {
  bool _checkingSession = true;
  bool _hasSession = false;

  @override
  void initState() {
    super.initState();
    _checkLocalSession();
  }

  Future<void> _checkLocalSession() async {
    final session = await StudentAuthService.getLocalSession();
    if (mounted) {
      setState(() {
        _hasSession = session != null;
        _checkingSession = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingSession) {
      return const Scaffold(
        body: BeautifulLoadingWidget(
          message: 'Checking Student Session...',
          size: 80,
        ),
      );
    }

    if (_hasSession) {
      return const StudentMainWrapper();
    }

    // No session: On web browsers, show the Quaid Academy Public Landing Screen.
    // On native mobile devices, show RoleSelectionScreen.
    if (kIsWeb) {
      return const WebLandingScreen();
    }

    return const RoleSelectionScreen();
  }
}

class RoleRoutingWrapper extends StatefulWidget {
  final User user;
  const RoleRoutingWrapper({super.key, required this.user});

  @override
  State<RoleRoutingWrapper> createState() => _RoleRoutingWrapperState();
}

class _RoleRoutingWrapperState extends State<RoleRoutingWrapper> {
  String? _role;
  bool _isLoading = true;
  String? _error;
  TeacherModel? _teacherModel;

  @override
  void initState() {
    super.initState();
    _checkRole();
  }

  @override
  void didUpdateWidget(covariant RoleRoutingWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user.uid != widget.user.uid) {
      _checkRole();
    }
  }

  Future<void> _checkRole() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final firestore = FirebaseFirestore.instance;
      final roleDocRef = firestore.collection('roles').doc(widget.user.uid);
      DocumentSnapshot<Map<String, dynamic>>? roleDoc;

      // 1. Try local offline cache first for instant startup (< 20ms)
      try {
        roleDoc = await roleDocRef.get(const GetOptions(source: Source.cache));
      } catch (_) {}

      // 2. If not in cache, fetch from server with a 2-second timeout
      if (roleDoc == null || !roleDoc.exists) {
        try {
          roleDoc = await roleDocRef.get().timeout(const Duration(seconds: 2));
        } catch (e) {
          debugPrint('[RoleRoutingWrapper] Server role lookup timed out: $e');
        }
      }

      String role = roleDoc?.data()?['role'] as String? ?? '';

      // 3. Check if current authenticated user has a Teacher profile
      if (role == 'teacher' || role.isEmpty) {
        final teacher = await TeacherService.getCurrentTeacher();
        if (teacher != null) {
          role = 'teacher';
          try {
            await roleDocRef.set({'role': 'teacher'}, SetOptions(merge: true));
          } catch (_) {}

          if (mounted) {
            setState(() {
              _role = 'teacher';
              _teacherModel = teacher;
              _isLoading = false;
            });
          }
          return;
        }
      }

      // 4. Check admins collection (by UID and by email)
      if (role.isEmpty) {
        try {
          final adminDoc = await firestore
              .collection('admins')
              .doc(widget.user.uid)
              .get()
              .timeout(const Duration(seconds: 4));
          if (adminDoc.exists) {
            final data = adminDoc.data();
            if (data != null) {
              final isAdminField = data['admin'] == true || data['isAdmin'] == true;
              final isRoleAdmin = (data['role'] ?? '').toString().toLowerCase() == 'admin';
              if (isAdminField || isRoleAdmin || data.isNotEmpty) {
                role = 'admin';
              }
            } else {
              role = 'admin';
            }
          }
        } catch (_) {}

        if (role.isEmpty && widget.user.email != null && widget.user.email!.isNotEmpty) {
          try {
            final aQuery = await firestore
                .collection('admins')
                .where('email', isEqualTo: widget.user.email!.trim().toLowerCase())
                .limit(1)
                .get()
                .timeout(const Duration(seconds: 4));
            if (aQuery.docs.isNotEmpty) {
              role = 'admin';
            }
          } catch (_) {}
        }
      }

      // 4b. Also check teachers collection by email if role still empty
      if (role.isEmpty && widget.user.email != null && widget.user.email!.isNotEmpty) {
        try {
          final tQuery = await firestore
              .collection('teachers')
              .where('email', isEqualTo: widget.user.email!.trim().toLowerCase())
              .limit(1)
              .get()
              .timeout(const Duration(seconds: 4));
          if (tQuery.docs.isNotEmpty) {
            role = 'teacher';
            _teacherModel = TeacherModel.fromFirestore(tQuery.docs.first);
          }
        } catch (_) {}
      }

      // 4c. Non-teacher authenticated accounts are recognized as admin
      if (role.isEmpty) {
        role = 'admin';
      }

      if (role == 'admin') {
        try {
          await roleDocRef.set({'role': 'admin'}, SetOptions(merge: true));
        } catch (_) {}
        if (mounted) {
          setState(() {
            _role = 'admin';
            _isLoading = false;
          });
        }
        return;
      }

      if (role == 'teacher') {
        try {
          await roleDocRef.set({'role': 'teacher'}, SetOptions(merge: true));
        } catch (_) {}
        if (mounted) {
          setState(() {
            _role = 'teacher';
            _isLoading = false;
          });
        }
        return;
      }

      // 5. Account not authorized as admin or teacher
      if (mounted) {
        setState(() {
          _role = 'unauthorized';
          _error = 'Your account has not been assigned authorization. Please contact Quaid Academy Administration.';
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[RoleRoutingWrapper] Role lookup exception: $e');
      if (mounted) {
        setState(() {
          _role = 'unauthorized';
          _error = 'Role verification failed. Your request was not authorized by the server.';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: BeautifulLoadingWidget(
          message: 'Verifying Security & Role Access...',
          size: 80,
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.gpp_bad_rounded, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () async {
                    await FirebaseAuth.instance.signOut();
                    await StudentAuthService.logout();
                  },
                  child: const Text('Go to Login'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_role == 'admin') {
      return const MainWrapper();
    }

    if (_role == 'teacher') {
      final teacher = _teacherModel ??
          TeacherModel(
            id: widget.user.uid,
            name: widget.user.displayName ?? 'Faculty Member',
            email: widget.user.email ?? '',
            teacherId: 'T-FAC-001',
            subject: 'Faculty',
            section: 'FSc',
            assignedClasses: const ['First Year'],
            createdAt: DateTime.now(),
          );
      return TeacherMainWrapper(teacher: teacher);
    }

    // Unknown role — sign out and show role selection
    FirebaseAuth.instance.signOut();
    return const RoleSelectionScreen();
  }
}
