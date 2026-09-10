import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../main.dart';
import '../screens/role_selection_screen.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/shimmer_loading_widget.dart';
import '../widgets/portal_loading_screen.dart';
import '../screens/main_wrapper.dart';
import 'dart:ui';
import '../theme/ui_helpers.dart';
import '../widgets/custom_card.dart';
import '../screens/forgot_password_screen.dart';

class LoginScreen extends StatefulWidget {   
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final user = await AuthService.loginWithEmailPassword(
        _emailController.text,
        _passwordController.text,
      );

      // Verify user has admin role
      final roleDoc = await FirebaseFirestore.instance
          .collection('roles')
          .doc(user.uid)
          .get()
          .timeout(const Duration(seconds: 5));

      final roleData = roleDoc.data();
      String role = roleData?['role'] as String? ?? '';
      
      if (role.isEmpty) {
        final adminDoc = await FirebaseFirestore.instance.collection('admins').doc(user.uid).get();
        if (adminDoc.exists && adminDoc.data()?['admin'] == true) {
          role = 'admin';
        }
      }

      if (role != 'admin') {
        await FirebaseAuth.instance.signOut();
        throw Exception('Access denied. Administrator privileges required.');
      }

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => PortalLoadingScreen.admin(
              adminName: user.displayName ?? 'Administrator',
              onComplete: () {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const MainWrapper()),
                  (route) => false,
                );
              },
            ),
          ),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        UIHelpers.showCustomSnackBar(
          context,
          e.toString().replaceFirst('Exception: ', ''),
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _handleForgotPassword() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ForgotPasswordScreen(
          initialRole: 'admin',
          initialEmail: _emailController.text.trim(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
                    ? [const Color(0xFF020617), const Color(0xFF0F172A), const Color(0xFF1E293B)]
                    : [const Color(0xFFF8FAFC), const Color(0xFFF1F5F9), const Color(0xFFE2E8F0)],
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
                color: AppTheme.primaryBlue.withOpacity(isDark ? 0.15 : 0.08),
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
                color: const Color(0xFF10B981).withOpacity(isDark ? 0.1 : 0.05),
              ),
            ).animate(onPlay: (controller) => controller.repeat(reverse: true))
             .scale(begin: const Offset(1, 1), end: const Offset(1.1, 1.1), duration: 6.seconds)
             .move(begin: const Offset(0, 0), end: const Offset(-30, -20), duration: 7.seconds),
          ),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 12),

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

                    // Premium Logo
                    Container(
                      height: 110,
                      width: 110,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppTheme.primaryBlue, AppTheme.primaryBlue.withOpacity(0.7)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryBlue.withOpacity(0.4),
                            blurRadius: 30,
                            offset: const Offset(0, 10),
                          )
                        ],
                        border: Border.all(
                          color: Colors.white.withOpacity(0.2),
                          width: 1.5,
                        )
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.admin_panel_settings_rounded,
                          size: 54,
                          color: Colors.white,
                        ),
                      ),
                    ).animate().fadeIn(duration: 600.ms).scale(begin: const Offset(0.8, 0.8), curve: Curves.easeOutBack),

                    const SizedBox(height: 28),

                    Text(
                      'Admin Portal',
                      style: GoogleFonts.outfit(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ).animate().fadeIn().slideY(begin: 0.1),

                    Text(
                      'Sign in to manage Quaid Academy',
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
                            color: isDark ? Colors.white.withOpacity(0.05) : Colors.white.withOpacity(0.7),
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(
                              color: isDark ? Colors.white.withOpacity(0.1) : Colors.white,
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
                                TextFormField(
                                  controller: _emailController,
                                  keyboardType: TextInputType.emailAddress,
                                  textInputAction: TextInputAction.next,
                                  style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                                  decoration: InputDecoration(
                                    labelText: 'Email Address',
                                    hintText: 'admin@academy.com',
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
                                  validator: (v) =>
                                      (v == null || !v.contains('@'))
                                          ? 'Valid email required'
                                          : null,
                                ),
                                const SizedBox(height: 20),
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
                                              Text('ACCESS DASHBOARD', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
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
