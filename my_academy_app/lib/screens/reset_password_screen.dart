import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/teacher_model.dart';
import '../screens/main_wrapper.dart';
import '../screens/role_selection_screen.dart';
import '../services/audit_log_service.dart';
import '../services/sound_service.dart';
import '../services/teacher_service.dart';
import '../teacher_portal/teacher_main_wrapper.dart';
import '../theme/app_theme.dart';
import '../theme/ui_helpers.dart';
import '../widgets/portal_loading_screen.dart';
import 'forgot_password_screen.dart';

/// Screen displayed when a user opens the app via a password reset link.
/// Validates the [oobCode], allows entering a new password, saves it,
/// automatically signs the user in, triggers the stepped PortalLoadingScreen,
/// and routes directly into their respective portal (Admin or Teacher).
class ResetPasswordScreen extends StatefulWidget {
  final String oobCode;
  final String? emailHint;
  final String? roleHint;

  const ResetPasswordScreen({
    super.key,
    required this.oobCode,
    this.emailHint,
    this.roleHint,
  });

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isVerifyingCode = true;
  String? _codeError;
  String? _verifiedEmail;
  String _userRole = 'admin'; // 'admin' or 'teacher'
  String _userName = '';
  TeacherModel? _teacherModel;

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _verifyResetCode();
  }

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  /// Verifies that the oobCode from the email link is valid and hasn't expired.
  Future<void> _verifyResetCode() async {
    setState(() {
      _isVerifyingCode = true;
      _codeError = null;
    });

    try {
      final email = await FirebaseAuth.instance.verifyPasswordResetCode(widget.oobCode);
      _verifiedEmail = email;

      // Determine role & load user info from Firestore
      await _resolveRoleAndIdentity(email);

      if (mounted) {
        setState(() {
          _isVerifyingCode = false;
        });
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() {
          _isVerifyingCode = false;
          switch (e.code) {
            case 'expired-action-code':
              _codeError = 'This password reset link has expired. Please request a new one.';
              break;
            case 'invalid-action-code':
              _codeError = 'This password reset link is invalid or has already been used.';
              break;
            case 'user-disabled':
              _codeError = 'The user account associated with this link has been disabled.';
              break;
            default:
              _codeError = 'Unable to verify reset link (${e.message ?? e.code}). Please request a new link.';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isVerifyingCode = false;
          _codeError = 'Failed to verify reset link. Please check your internet connection or request a new link.';
        });
      }
    }
  }

  /// Looks up user role and profile details in Firestore
  Future<void> _resolveRoleAndIdentity(String email) async {
    final cleanEmail = email.trim().toLowerCase();
    final firestore = FirebaseFirestore.instance;

    // 1. Check if user is a teacher
    try {
      final tQuery = await firestore
          .collection('teachers')
          .where('email', isEqualTo: cleanEmail)
          .limit(1)
          .get()
          .timeout(const Duration(seconds: 4));

      if (tQuery.docs.isNotEmpty) {
        final teacher = TeacherModel.fromFirestore(tQuery.docs.first);
        _userRole = 'teacher';
        _userName = teacher.name;
        _teacherModel = teacher;
        return;
      }
    } catch (e) {
      debugPrint('[ResetPasswordScreen] Teacher lookup: $e');
    }

    // 2. Check if user is an admin
    try {
      final aQuery = await firestore
          .collection('admins')
          .where('email', isEqualTo: cleanEmail)
          .limit(1)
          .get()
          .timeout(const Duration(seconds: 4));

      if (aQuery.docs.isNotEmpty) {
        _userRole = 'admin';
        _userName = aQuery.docs.first.data()['name'] ?? 'Administrator';
        return;
      }
    } catch (e) {
      debugPrint('[ResetPasswordScreen] Admin lookup: $e');
    }

    // 3. Fallback to roleHint if provided
    if (widget.roleHint != null && widget.roleHint!.isNotEmpty) {
      _userRole = widget.roleHint!;
    }
    if (_userName.isEmpty) {
      _userName = _userRole == 'teacher' ? 'Faculty Member' : 'Administrator';
    }
  }

  /// Resets password, signs user in, and launches the respective portal loading flow.
  Future<void> _handleResetAndAccessPortal() async {
    if (!_formKey.currentState!.validate()) return;
    if (_verifiedEmail == null) return;

    final newPassword = _newPasswordController.text.trim();

    setState(() => _isSubmitting = true);

    try {
      // 1. Confirm password reset in Firebase Auth
      await FirebaseAuth.instance.confirmPasswordReset(
        code: widget.oobCode,
        newPassword: newPassword,
      );

      // 2. Automatically sign in with the new password
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _verifiedEmail!,
        password: newPassword,
      );

      final user = credential.user;
      if (user == null) {
        throw Exception('Authentication failed after password reset.');
      }

      // 3. Ensure role mapping exists in roles collection for future sessions
      try {
        await FirebaseFirestore.instance
            .collection('roles')
            .doc(user.uid)
            .set({'role': _userRole}, SetOptions(merge: true));
      } catch (_) {}

      // 4. If teacher, ensure teacher document is synchronized
      if (_userRole == 'teacher') {
        TeacherModel? teacher = _teacherModel;
        teacher ??= await TeacherService.getCurrentTeacher();
        _teacherModel = teacher;
      }

      // 5. Play confirmation sound and audit log
      try {
        await SoundService.playSuccess();
      } catch (_) {}

      try {
        await AuditLogService.logAction(
          actorId: _verifiedEmail!,
          actorName: _userName,
          actorRole: _userRole.toUpperCase(),
          action: 'PASSWORD_RESET_COMPLETED',
          transactionId: user.uid,
          details: 'Password was successfully reset via email link and user authenticated.',
        );
      } catch (_) {}

      if (!mounted) return;

      // 6. Transition into respective portal via PortalLoadingScreen
      final targetRole = _userRole;
      final currentTeacher = _teacherModel;
      final adminName = _userName.isNotEmpty ? _userName : (user.displayName ?? 'Administrator');

      if (targetRole == 'teacher') {
        final teacher = currentTeacher ??
            TeacherModel(
              id: user.uid,
              name: _userName,
              email: _verifiedEmail!,
              teacherId: 'T-FAC-001',
              subject: 'Faculty',
              section: 'FSc',
              assignedClasses: const ['First Year'],
              createdAt: DateTime.now(),
            );

        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => PortalLoadingScreen.teacher(
              teacher: teacher,
              teacherName: teacher.name,
              subject: teacher.subject,
              targetScreen: TeacherMainWrapper(teacher: teacher),
            ),
          ),
          (_) => false,
        );
      } else {
        // Admin portal access
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => PortalLoadingScreen.admin(
              adminName: adminName,
              targetScreen: const MainWrapper(),
            ),
          ),
          (_) => false,
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        String msg = e.message ?? 'Password reset failed.';
        if (e.code == 'weak-password') {
          msg = 'The password is too weak. Please use at least 6 characters.';
        } else if (e.code == 'expired-action-code') {
          msg = 'This reset link has expired. Please request a new one.';
        }
        UIHelpers.showCustomSnackBar(context, msg, isError: true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        UIHelpers.showCustomSnackBar(
          context,
          e.toString().replaceFirst('Exception: ', ''),
          isError: true,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = _userRole == 'admin' ? AppTheme.primaryBlue : AppTheme.secondaryGreen;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
          onPressed: () {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const RoleSelectionScreen()),
              (_) => false,
            );
          },
        ),
        title: Text(
          'Set New Password',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: _isVerifyingCode
                  ? _buildVerifyingState(isDark)
                  : _codeError != null
                      ? _buildErrorState(isDark)
                      : _buildResetForm(isDark, primaryColor),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVerifyingState(bool isDark) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const BeautifulLoadingWidget(
          message: 'Verifying Security Link & Credentials...',
          size: 72,
        ),
        const SizedBox(height: 20),
        Text(
          'Connecting to Quaid Academy security services...',
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: 13,
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState(bool isDark) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.red.withValues(alpha: 0.12),
            border: Border.all(color: Colors.red.withValues(alpha: 0.3), width: 2),
          ),
          child: const Center(
            child: Icon(Icons.link_off_rounded, color: Colors.red, size: 40),
          ),
        ).animate().scale(duration: 400.ms),
        const SizedBox(height: 20),
        Text(
          'Reset Link Expired or Invalid',
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          _codeError ?? 'This password reset link cannot be used.',
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (_) => ForgotPasswordScreen(initialRole: _userRole),
                ),
              );
            },
            icon: const Icon(Icons.mail_outline_rounded, size: 18),
            label: Text(
              'Request Fresh Reset Link',
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const RoleSelectionScreen()),
              (_) => false,
            );
          },
          child: Text(
            'Return to Portals',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResetForm(bool isDark, Color primaryColor) {
    final roleName = _userRole == 'admin' ? 'Administrator' : 'Teacher';

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Icon badge
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: primaryColor.withValues(alpha: 0.12),
              border: Border.all(color: primaryColor.withValues(alpha: 0.3), width: 2),
            ),
            child: Center(
              child: Icon(
                _userRole == 'admin' ? Icons.admin_panel_settings_rounded : Icons.school_rounded,
                color: primaryColor,
                size: 38,
              ),
            ),
          ).animate().scale(duration: 400.ms),

          const SizedBox(height: 16),

          Text(
            'Create New Password',
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),

          const SizedBox(height: 6),

          // Role & Email Info Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: primaryColor.withValues(alpha: 0.2)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.verified_user_rounded, size: 16, color: primaryColor),
                const SizedBox(width: 8),
                Text(
                  '$roleName: ${_verifiedEmail ?? ""}',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: primaryColor,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // New Password Field
          TextFormField(
            controller: _newPasswordController,
            obscureText: _obscurePassword,
            style: GoogleFonts.poppins(color: isDark ? Colors.white : Colors.black87),
            decoration: InputDecoration(
              labelText: 'New Password',
              hintText: 'At least 6 characters',
              filled: true,
              fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              prefixIcon: Icon(Icons.lock_outline_rounded, color: primaryColor),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                  color: Colors.grey,
                ),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Password is required';
              if (v.trim().length < 6) return 'Password must be at least 6 characters';
              return null;
            },
          ),

          const SizedBox(height: 16),

          // Confirm Password Field
          TextFormField(
            controller: _confirmPasswordController,
            obscureText: _obscureConfirm,
            style: GoogleFonts.poppins(color: isDark ? Colors.white : Colors.black87),
            decoration: InputDecoration(
              labelText: 'Confirm New Password',
              hintText: 'Re-enter your new password',
              filled: true,
              fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              prefixIcon: Icon(Icons.lock_reset_rounded, color: primaryColor),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureConfirm ? Icons.visibility_off : Icons.visibility,
                  color: Colors.grey,
                ),
                onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
              ),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Please confirm your password';
              if (v.trim() != _newPasswordController.text.trim()) {
                return 'Passwords do not match';
              }
              return null;
            },
          ),

          const SizedBox(height: 24),

          // Information Note
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: primaryColor.withValues(alpha: 0.15)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.shield_outlined, color: primaryColor, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Setting your password will securely sign you in and launch the $roleName Portal with full verified privileges.',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),

          // Action Button
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _handleResetAndAccessPortal,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 4,
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.lock_open_rounded, size: 20),
                        const SizedBox(width: 10),
                        Text(
                          'Reset Password & Access Portal',
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
