import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import 'dart:ui';
import 'dart:async';
import '../models/teacher_model.dart';
import '../services/teacher_service.dart';
import '../services/notification_service.dart';
import '../screens/role_selection_screen.dart';
import '../widgets/portal_loading_screen.dart';
import 'teacher_main_wrapper.dart';
import '../screens/forgot_password_screen.dart';


class TeacherLoginScreen extends StatefulWidget {
  const TeacherLoginScreen({super.key});

  @override
  State<TeacherLoginScreen> createState() => _TeacherLoginScreenState();
}

class _TeacherLoginScreenState extends State<TeacherLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 1. Sign in with Firebase Auth
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      final uid = credential.user!.uid;

      // 2. Load teacher data with fallback email matching and auto-linking
      TeacherModel? teacher = await TeacherService.getCurrentTeacher();

      if (teacher == null) {
        // Double check role document in case profile load was delayed
        try {
          final roleDoc = await FirebaseFirestore.instance
              .collection('roles')
              .doc(uid)
              .get()
              .timeout(const Duration(seconds: 3));
          final role = roleDoc.data()?['role'] as String? ?? '';
          if (role == 'teacher') {
            teacher = await TeacherService.getCurrentTeacher();
          }
        } catch (_) {}
      }

      if (teacher == null) {
        await FirebaseAuth.instance.signOut();
        setState(() {
          _errorMessage =
              'Teacher profile not found for ${_emailController.text.trim()}. Please contact administration.';
          _isLoading = false;
        });
        return;
      }

      // Ensure roles document is synced
      try {
        await FirebaseFirestore.instance
            .collection('roles')
            .doc(uid)
            .set({'role': 'teacher'}, SetOptions(merge: true));
      } catch (_) {}

      if (!teacher.isActive) {
        await FirebaseAuth.instance.signOut();
        setState(() {
          _errorMessage =
              'Your teacher account has been deactivated. Please contact administration.';
          _isLoading = false;
        });
        return;
      }

      // Register FCM token for teacher notifications (non-blocking for fast execution)
      unawaited(NotificationService.registerFcmToken(
        userId: teacher.id,
        role: 'teacher',
      ));

      // 3. Navigate to teacher portal with rich loading experience
      if (mounted) {
        final currentTeacher = teacher;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => PortalLoadingScreen.teacher(
              teacher: currentTeacher,
              teacherName: currentTeacher.name,
              subject: currentTeacher.subject,
              targetScreen: TeacherMainWrapper(teacher: currentTeacher),
            ),
          ),
          (_) => false,
        );
      }
    } on FirebaseAuthException catch (e) {
      String message;
      switch (e.code) {
        case 'user-not-found':
          message = 'No account found with this email.';
          break;
        case 'wrong-password':
          message = 'Incorrect password. Please try again.';
          break;
        case 'invalid-email':
          message = 'The email address is invalid.';
          break;
        case 'user-disabled':
          message = 'This account has been disabled.';
          break;
        case 'too-many-requests':
          message = 'Too many attempts. Please try again later.';
          break;
        case 'invalid-credential':
          message = 'Invalid email or password. Please try again.';
          break;
        default:
          message = 'Login failed: ${e.message}';
      }
      setState(() {
        _errorMessage = message;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'An unexpected error occurred. Please try again.';
        _isLoading = false;
      });
    }
  }

  void _handleForgotPassword() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ForgotPasswordScreen(
          initialRole: 'teacher',
          initialEmail: _emailController.text.trim(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;
    final isWide = size.width >= 600;

    return Scaffold(
      body: Stack(
        children: [
          // Premium Ambient Background
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark 
                    ? (AppTheme.isAurora(context)
                        ? const [Color(0xFF070B14), Color(0xFF0C1425), Color(0xFF080F1F)]
                        : const [Color(0xFF020617), Color(0xFF1E3A8A), Color(0xFF0F172A)])
                    : [const Color(0xFFF0F9FF), const Color(0xFFE0F2FE), const Color(0xFFBAE6FD)],
                ),
              ),
            ),
          ),
          
          // Animated Ambient Orbs
          Positioned(
            top: -100,
            left: -50,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: (AppTheme.isAurora(context) ? const Color(0xFF3B82F6) : const Color(0xFF3B82F6)).withValues(alpha: isDark ? 0.15 : 0.08),
              ),
            ).animate(onPlay: (controller) => controller.repeat(reverse: true))
             .scale(begin: const Offset(1, 1), end: const Offset(1.2, 1.2), duration: 4.seconds)
             .move(begin: const Offset(0, 0), end: const Offset(20, 20), duration: 5.seconds),
          ),
          
          Positioned(
            bottom: -50,
            right: -100,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: (AppTheme.isAurora(context) ? const Color(0xFF06B6D4) : const Color(0xFF8B5CF6)).withValues(alpha: isDark ? 0.1 : 0.05),
              ),
            ).animate(onPlay: (controller) => controller.repeat(reverse: true))
             .scale(begin: const Offset(1, 1), end: const Offset(1.1, 1.1), duration: 6.seconds)
             .move(begin: const Offset(0, 0), end: const Offset(-30, -20), duration: 7.seconds),
          ),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: isWide ? size.width * 0.2 : 28,
                  vertical: 24,
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 16),

                    // Back to Portals button
                    Align(
                      alignment: Alignment.centerLeft,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          if (Navigator.canPop(context)) {
                            Navigator.pop(context);
                          } else {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const RoleSelectionScreen(),
                              ),
                            );
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.1)
                                : Colors.black.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.15)
                                  : Colors.black.withValues(alpha: 0.08),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.arrow_back_ios_new_rounded,
                                size: 15,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Back to Portals',
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ).animate().fadeIn(duration: 400.ms),

                    const SizedBox(height: 16),

                    // Premium Icon
                    Container(
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [const Color(0xFF3B82F6), const Color(0xFF2563EB)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF3B82F6).withOpacity(0.4),
                            blurRadius: 30,
                            offset: const Offset(0, 10),
                          )
                        ],
                        border: Border.all(
                          color: Colors.white.withOpacity(0.2),
                          width: 1.5,
                        ),
                      ),
                      child: const Center(
                        child: Text('👨‍🏫', style: TextStyle(fontSize: 48)),
                      ),
                    ).animate().fadeIn(duration: 600.ms).scale(begin: const Offset(0.8, 0.8), curve: Curves.easeOutBack),

                    const SizedBox(height: 28),

                    Text(
                      'Teacher Portal',
                      style: GoogleFonts.outfit(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ).animate().fadeIn().slideY(begin: 0.1),

                    Text(
                      'Quaid Academy — Faculty Access',
                      style: GoogleFonts.outfit(
                        fontSize: 15,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.2,
                      ),
                    ).animate().fadeIn().slideY(begin: 0.15),

                    const SizedBox(height: 40),

                    // Glassmorphic Login Card
                    ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                        child: Container(
                          padding: const EdgeInsets.all(32),
                          decoration: BoxDecoration(
                            color: isDark
                                ? (AppTheme.isAurora(context) ? AppTheme.auroraGlassCard : Colors.white.withOpacity(0.05))
                                : Colors.white.withOpacity(0.7),
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(
                              color: isDark
                                  ? (AppTheme.isAurora(context) ? AppTheme.auroraBorder : Colors.white.withOpacity(0.1))
                                  : Colors.white,
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 30,
                                offset: const Offset(0, 10),
                              )
                            ],
                          ),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Error message
                                if (_errorMessage != null) ...[
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: AppTheme.warningRed.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: AppTheme.warningRed.withOpacity(0.3),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.error_outline_rounded,
                                            color: AppTheme.warningRed, size: 18),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            _errorMessage!,
                                            style: GoogleFonts.outfit(
                                              fontSize: 13,
                                              color: AppTheme.warningRed,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ).animate().shake(hz: 3, curve: Curves.easeInOut),
                                  const SizedBox(height: 20),
                                ],

                                // Email
                                TextFormField(
                                  controller: _emailController,
                                  keyboardType: TextInputType.emailAddress,
                                  textInputAction: TextInputAction.next,
                                  style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                                  decoration: InputDecoration(
                                    labelText: 'Email Address',
                                    hintText: 'teacher@academy.com',
                                    filled: true,
                                    fillColor: isDark ? Colors.black.withOpacity(0.2) : Colors.white,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: BorderSide.none,
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: BorderSide(color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey.shade200),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: const BorderSide(color: AppTheme.primaryBlue, width: 2),
                                    ),
                                    prefixIcon: const Icon(Icons.email_outlined, color: AppTheme.primaryBlue),
                                  ),
                                  validator: (v) => (v == null || !v.contains('@'))
                                      ? 'Valid email required'
                                      : null,
                                ),

                                const SizedBox(height: 20),

                                // Password
                                TextFormField(
                                  controller: _passwordController,
                                  obscureText: _obscurePassword,
                                  textInputAction: TextInputAction.done,
                                  style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                                  onFieldSubmitted: (_) {
                                    if (!_isLoading) _handleLogin();
                                  },
                                  decoration: InputDecoration(
                                    labelText: 'Password',
                                    filled: true,
                                    fillColor: isDark ? Colors.black.withOpacity(0.2) : Colors.white,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: BorderSide.none,
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: BorderSide(color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey.shade200),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: const BorderSide(color: AppTheme.primaryBlue, width: 2),
                                    ),
                                    prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppTheme.primaryBlue),
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _obscurePassword ? Icons.visibility_off : Icons.visibility,
                                        color: isDark ? Colors.grey.shade400 : Colors.grey,
                                      ),
                                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                    ),
                                  ),
                                  validator: (v) => (v == null || v.length < 6)
                                      ? 'Minimum 6 characters'
                                      : null,
                                ),

                                const SizedBox(height: 12),

                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton(
                                    onPressed: _handleForgotPassword,
                                    style: TextButton.styleFrom(
                                      foregroundColor: AppTheme.primaryBlue,
                                      padding: const EdgeInsets.symmetric(horizontal: 8),
                                    ),
                                    child: Text('Forgot Password?', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
                                  ),
                                ),

                                const SizedBox(height: 24),

                                SizedBox(
                                  width: double.infinity,
                                  height: 56,
                                  child: ElevatedButton(
                                    onPressed: _isLoading ? null : _handleLogin,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.primaryBlue,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      elevation: 8,
                                      shadowColor: AppTheme.primaryBlue.withOpacity(0.5),
                                    ),
                                    child: _isLoading 
                                        ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                        : Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Text('ACCESS PORTAL', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                                              const SizedBox(width: 8),
                                              const Icon(Icons.arrow_forward_rounded, size: 20),
                                            ],
                                          ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ).animate().fadeIn().slideY(begin: 0.08, curve: Curves.easeOutCirc),

                    const SizedBox(height: 40),

                    Text(
                      '© 2026 Quaid Academy Pro Management',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: isDark ? Colors.grey.shade600 : Colors.grey.shade500,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
