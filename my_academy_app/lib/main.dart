import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'theme/app_theme.dart';

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
import 'login/login_screen.dart';
import 'screens/main_wrapper.dart';
import 'student_portal/student_main_wrapper.dart';
import 'student_portal/student_login_screen.dart';


// Firebase options
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await Hive.initFlutter();

  if (!Hive.isAdapterRegistered(0)) {
    Hive.registerAdapter(StudentModelAdapter());
  }
  if (!Hive.isAdapterRegistered(1)) {
    Hive.registerAdapter(RecycledStudentAdapter());
  }

  await DatabaseService.init();

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

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      title: 'Quaid Academy',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
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
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Safely request notification permission after the splash screen finishes rendering
      NotificationService.init();
      NotificationService.initializePushNotifications();
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
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
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_hasSession) {
      return const StudentMainWrapper();
    }

    // Default unauthenticated entry: Student portal login.
    // Admins can reach their login via the link inside StudentLoginScreen.
    return const StudentLoginScreen();
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
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final firestore = FirebaseFirestore.instance;
      final roleDocRef = firestore.collection('roles').doc(widget.user.uid);

      var roleDoc = await roleDocRef
          .get()
          .timeout(const Duration(seconds: 10));

      // Auto-bootstrap for admin users.
      if (!roleDoc.exists) {
        await roleDocRef.set({
          'role': 'admin',
          'createdAt': FieldValue.serverTimestamp(),
        });

        roleDoc = await roleDocRef
            .get()
            .timeout(const Duration(seconds: 10));

        if (!roleDoc.exists) {
          throw Exception('Failed to initialize admin account. Please try again.');
        }
      }

      final roleData = roleDoc.data();
      final role = roleData?['role'] as String?;

      if (role == 'admin') {
        setState(() {
          _role = 'admin';
          _isLoading = false;
        });
      } else {
        throw Exception('Invalid user role.');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
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

    return const LoginScreen();
  }
}
