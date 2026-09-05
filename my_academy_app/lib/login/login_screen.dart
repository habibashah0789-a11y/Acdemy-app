import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../main.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/shimmer_loading_widget.dart';
import '../theme/ui_helpers.dart';
import '../widgets/custom_card.dart';

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
          MaterialPageRoute(builder: (_) => const AuthWrapper()),
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: [
          // Background Gradient Blob
          Positioned(
            top: -120,
            left: -60,
            right: -60,
            child: Container(
              height: 340,
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(170)),
              ),
            ),
          ),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 20),

                    // Logo Container
                    Container(
                      height: 100,
                      width: 100,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryBlue.withValues(alpha: 0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          )
                        ],
                      ),
                      child: const Icon(
                        Icons.school_rounded,
                        size: 54,
                        color: AppTheme.primaryBlue,
                      ),
                    ).animate().fadeIn(duration: 600.ms).scale(begin: const Offset(0.8, 0.8)),

                    const SizedBox(height: 24),

                    Text(
                      'Quaid Academy',
                      style: GoogleFonts.poppins(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : AppTheme.primaryDarkBlue,
                      ),
                    ).animate().fadeIn(),

                    Text(
                      'Administration & Faculty Portal',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.5,
                      ),
                    ).animate().fadeIn(),

                    const SizedBox(height: 36),

                    // Main Login Card
                    CustomCard(
                      padding: const EdgeInsets.all(24),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Sign In to Dashboard',
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 20),
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                labelText: 'Email Address',
                                hintText: 'admin@academy.com',
                                prefixIcon: Icon(Icons.email_outlined, color: AppTheme.primaryBlue),
                              ),
                              validator: (v) =>
                                  (v == null || !v.contains('@'))
                                      ? 'Please enter a valid email address'
                                      : null,
                            ),
                            const SizedBox(height: 18),
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) {
                                if (!_isLoading) _handleLogin();
                              },
                              decoration: InputDecoration(
                                labelText: 'Password',
                                prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppTheme.primaryBlue),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword ? Icons.visibility_off : Icons.visibility,
                                    color: Colors.grey,
                                  ),
                                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                ),
                              ),
                              validator: (v) => (v == null || v.length < 6)
                                  ? 'Password must be at least 6 characters'
                                  : null,
                            ),
                            const SizedBox(height: 10),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                onPressed: () {},
                                icon: const Icon(Icons.help_outline_rounded, size: 16),
                                label: const Text('Forgot Password?'),
                              ),
                            ),
                            const SizedBox(height: 20),
                             SizedBox(
                              width: double.infinity,
                              child: InlineLoadingButton(
                                isLoading: _isLoading,
                                label: 'LOGIN TO ADMIN PORTAL',
                                loadingLabel: 'Signing in...',
                                icon: Icons.arrow_forward_rounded,
                                onPressed: _handleLogin,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryBlue.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: TextButton.icon(
                                  onPressed: () {
                                    // Admin login is pushed on top of StudentLoginScreen,
                                    // so simply pop back to the student portal.
                                    if (Navigator.canPop(context)) {
                                      Navigator.pop(context);
                                    }
                                  },
                                  icon: const Icon(Icons.school_rounded, color: AppTheme.primaryBlue, size: 18),
                                  label: const Text(
                                    'Switch to Student Portal',
                                    style: TextStyle(
                                      color: AppTheme.primaryBlue,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ).animate().fadeIn().slideY(begin: 0.08),

                    const SizedBox(height: 32),

                    Text(
                      '© 2026 Quaid Academy Pro Management',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
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
