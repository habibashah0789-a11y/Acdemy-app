import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/password_recovery_service.dart';
import '../services/sound_service.dart';
import '../theme/app_theme.dart';
import '../theme/ui_helpers.dart';
import '../widgets/portal_loading_screen.dart';
import 'main_wrapper.dart';
import '../teacher_portal/teacher_main_wrapper.dart';
import '../models/teacher_model.dart';
import '../services/auth_service.dart';
import '../services/teacher_service.dart';

class ForgotPasswordScreen extends StatefulWidget {
  final String initialRole; // 'admin' or 'teacher'
  final String? initialEmail;

  const ForgotPasswordScreen({
    super.key,
    this.initialRole = 'admin',
    this.initialEmail,
  });

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  late String _selectedRole; // 'admin' or 'teacher'
  bool _emailSent = false;
  bool _isLoading = false;
  TeacherModel? _matchedTeacher;

  // Resend cooldown timer (60 seconds)
  Timer? _resendTimer;
  int _resendCooldown = 60;
  bool _canResend = false;

  // In-app reset code input state
  bool _showCodeResetForm = false;
  final _codeResetFormKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  bool _isResettingWithCode = false;

  @override
  void initState() {
    super.initState();
    _selectedRole = widget.initialRole;
    if (widget.initialEmail != null && widget.initialEmail!.isNotEmpty) {
      _emailController.text = widget.initialEmail!;
    }
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _emailController.dispose();
    _codeController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _startResendTimer() {
    _resendTimer?.cancel();
    setState(() {
      _resendCooldown = 60;
      _canResend = false;
    });
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendCooldown <= 1) {
        timer.cancel();
        if (mounted) {
          setState(() {
            _resendCooldown = 0;
            _canResend = true;
          });
        }
      } else {
        if (mounted) {
          setState(() => _resendCooldown--);
        }
      }
    });
  }

  Future<void> _handleSendResetEmail() async {
    if (!_formKey.currentState!.validate()) return;
    final email = _emailController.text.trim();

    setState(() => _isLoading = true);

    try {
      final result = await PasswordRecoveryService.sendRecoveryOtpAndLink(
        email: email,
        role: _selectedRole,
      );

      _matchedTeacher = result['teacher'] as TeacherModel?;

      await SoundService.playNotification();

      if (mounted) {
        setState(() {
          _emailSent = true;
          _isLoading = false;
        });
        _startResendTimer();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Password reset email sent to $email',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            backgroundColor: AppTheme.secondaryGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        UIHelpers.showCustomSnackBar(
          context,
          e.toString().replaceFirst('Exception: ', ''),
          isError: true,
        );
      }
    }
  }

  Future<void> _handleOpenEmailApp() async {
    final mailtoUri = Uri(scheme: 'mailto');
    try {
      if (await canLaunchUrl(mailtoUri)) {
        await launchUrl(mailtoUri);
      } else {
        final webmailUri = Uri.parse('https://mail.google.com');
        if (await canLaunchUrl(webmailUri)) {
          await launchUrl(webmailUri, mode: LaunchMode.externalApplication);
        } else {
          if (mounted) {
            UIHelpers.showCustomSnackBar(
              context,
              'Please open your email application to check for the reset link.',
            );
          }
        }
      }
    } catch (_) {
      if (mounted) {
        UIHelpers.showCustomSnackBar(
          context,
          'Please open your email application to check for the reset link.',
        );
      }
    }
  }

  Future<void> _handleResetWithCode() async {
    if (!_codeResetFormKey.currentState!.validate()) return;
    final code = _codeController.text.trim();
    final newPassword = _newPasswordController.text;
    final email = _emailController.text.trim();

    setState(() => _isResettingWithCode = true);

    try {
      await PasswordRecoveryService.resetPasswordWithCode(
        oobCode: code,
        newPassword: newPassword,
      );

      // Now authenticate the user with the new password
      final user = await AuthService.loginWithEmailPassword(email, newPassword);
      await SoundService.playNotification();

      if (!mounted) return;

      if (_selectedRole == 'teacher') {
        TeacherModel? teacher = await TeacherService.getCurrentTeacher();
        if (!mounted) return;

        teacher ??= _matchedTeacher ??
            TeacherModel(
              id: user.uid,
              name: user.displayName ?? 'Teacher',
              email: email,
              teacherId: 'T-FAC-001',
              subject: 'Faculty',
              section: 'FSc',
              assignedClasses: const ['First Year'],
              createdAt: DateTime.now(),
            );

        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => PortalLoadingScreen.teacher(
              teacher: teacher!,
              teacherName: teacher.name,
              subject: teacher.subject,
              targetScreen: TeacherMainWrapper(teacher: teacher),
            ),
          ),
          (_) => false,
        );
      } else {
        if (!mounted) return;
        final adminName = user.displayName?.isNotEmpty == true
            ? user.displayName!
            : (email.contains('@') ? email.split('@').first : 'Administrator');

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
    } catch (e) {
      if (mounted) {
        setState(() => _isResettingWithCode = false);
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
    final primaryColor = _selectedRole == 'admin'
        ? AppTheme.primaryBlue
        : AppTheme.secondaryGreen;

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
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _emailSent ? 'Reset Email Sent' : 'Reset Password',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            child: _emailSent
                ? _buildEmailSentView(context, isDark, primaryColor)
                : _buildRequestEmailView(context, isDark, primaryColor),
          ),
        ),
      ),
    );
  }

  // ── Phase 1: Request Password Reset Email View ──
  Widget _buildRequestEmailView(BuildContext context, bool isDark, Color primaryColor) {
    return Column(
      key: const ValueKey('request_email_view'),
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 8),

        // Top Role Icon Header
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: primaryColor.withValues(alpha: 0.12),
            border: Border.all(color: primaryColor.withValues(alpha: 0.25), width: 2),
            boxShadow: [
              BoxShadow(
                color: primaryColor.withValues(alpha: 0.15),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Center(
            child: Icon(
              _selectedRole == 'admin'
                  ? Icons.admin_panel_settings_rounded
                  : Icons.school_rounded,
              color: primaryColor,
              size: 40,
            ),
          ),
        ).animate().scale(duration: 400.ms),

        const SizedBox(height: 20),

        Text(
          'Forgot Your Password?',
          style: GoogleFonts.poppins(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),

        const SizedBox(height: 8),

        Text(
          'Select your portal role and enter your registered email address. We will send an official password reset link directly to your inbox.',
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: 13,
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            height: 1.5,
          ),
        ),

        const SizedBox(height: 26),

        // Role Selector Chips
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Expanded(
                child: _buildRoleTab(
                  role: 'admin',
                  label: 'Administrator',
                  icon: Icons.shield_rounded,
                  color: AppTheme.primaryBlue,
                ),
              ),
              Expanded(
                child: _buildRoleTab(
                  role: 'teacher',
                  label: 'Teacher',
                  icon: Icons.school_rounded,
                  color: AppTheme.secondaryGreen,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 28),

        // Email Form
        Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                style: GoogleFonts.poppins(color: isDark ? Colors.white : Colors.black87),
                decoration: InputDecoration(
                  labelText: 'Registered ${_selectedRole == "admin" ? "Admin" : "Teacher"} Email',
                  prefixIcon: Icon(Icons.email_outlined, color: primaryColor),
                  hintText: _selectedRole == 'admin' ? 'admin@quaidacademy.com' : 'teacher@quaidacademy.com',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Email is required';
                  if (!v.contains('@') || !v.contains('.')) return 'Enter a valid email address';
                  return null;
                },
              ),

              const SizedBox(height: 20),

              // Security notice
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: primaryColor.withValues(alpha: 0.2)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.mark_email_read_rounded, color: primaryColor, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'A secure password reset link from Quaid Academy Firebase Authentication will be dispatched to this email address.',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleSendResetEmail,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 4,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.send_rounded, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              'Send Password Reset Link',
                              style: GoogleFonts.poppins(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                ),
              ),

              const SizedBox(height: 16),

              TextButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_rounded, size: 16),
                label: Text(
                  'Back to ${_selectedRole == "admin" ? "Admin" : "Teacher"} Login',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Phase 2: Email Sent Success & Action View ──
  Widget _buildEmailSentView(BuildContext context, bool isDark, Color primaryColor) {
    return Column(
      key: const ValueKey('email_sent_view'),
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 12),

        // Glowing Mail Sent Icon
        Container(
          width: 90,
          height: 90,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppTheme.secondaryGreen.withValues(alpha: 0.14),
            border: Border.all(color: AppTheme.secondaryGreen.withValues(alpha: 0.35), width: 2),
            boxShadow: [
              BoxShadow(
                color: AppTheme.secondaryGreen.withValues(alpha: 0.2),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Center(
            child: Icon(
              Icons.mark_email_read_rounded,
              color: AppTheme.secondaryGreen,
              size: 46,
            ),
          ),
        ).animate().scale(duration: 400.ms),

        const SizedBox(height: 20),

        Text(
          'Check Your Email',
          style: GoogleFonts.poppins(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),

        const SizedBox(height: 8),

        Text(
          'We have sent an official password reset link to:',
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: 13,
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          ),
        ),

        const SizedBox(height: 10),

        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: primaryColor.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.email_outlined, size: 16, color: primaryColor),
              const SizedBox(width: 8),
              Text(
                _emailController.text.trim(),
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Step-by-Step Instructions Card
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.format_list_numbered_rounded, color: primaryColor, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'What to do next:',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _buildStepItem(
                step: '1',
                text: 'Open your email inbox (check Spam/Junk folder if not in inbox).',
                isDark: isDark,
              ),
              const SizedBox(height: 10),
              _buildStepItem(
                step: '2',
                text: 'Click the secure link in the email from Quaid Academy / Firebase.',
                isDark: isDark,
              ),
              const SizedBox(height: 10),
              _buildStepItem(
                step: '3',
                text: 'Enter your new password and click Save.',
                isDark: isDark,
              ),
              const SizedBox(height: 10),
              _buildStepItem(
                step: '4',
                text: 'Return here and sign in to your ${_selectedRole.toUpperCase()} portal with your new password.',
                isDark: isDark,
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Action Buttons
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _handleOpenEmailApp,
                icon: const Icon(Icons.mail_rounded, size: 18),
                label: Text(
                  'Open Email App',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: primaryColor,
                  side: BorderSide(color: primaryColor, width: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.login_rounded, size: 18),
                label: Text(
                  'Back to Login',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 2,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Resend Button with Cooldown
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "Didn't receive the email? ",
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
            ),
            TextButton(
              onPressed: _canResend ? _handleSendResetEmail : null,
              style: TextButton.styleFrom(
                foregroundColor: primaryColor,
                padding: EdgeInsets.zero,
              ),
              child: Text(
                _canResend ? 'Resend Link' : 'Resend in ${_resendCooldown}s',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: _canResend ? primaryColor : Colors.grey,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 24),
        Divider(color: isDark ? Colors.white12 : Colors.grey.shade300),
        const SizedBox(height: 16),

        // Optional In-App Reset Section
        InkWell(
          onTap: () => setState(() => _showCodeResetForm = !_showCodeResetForm),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _showCodeResetForm
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  color: primaryColor,
                  size: 20,
                ),
                const SizedBox(width: 6),
                Text(
                  'Have a reset code / link? Set password here',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: primaryColor,
                  ),
                ),
              ],
            ),
          ),
        ),

        if (_showCodeResetForm) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: primaryColor.withValues(alpha: 0.25)),
            ),
            child: Form(
              key: _codeResetFormKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Direct In-App Password Reset',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Paste the reset code (oobCode from the URL) to set your password immediately:',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _codeController,
                    style: GoogleFonts.poppins(color: isDark ? Colors.white : Colors.black87),
                    decoration: InputDecoration(
                      labelText: 'Reset Code / oobCode',
                      hintText: 'Paste code here',
                      prefixIcon: Icon(Icons.vpn_key_rounded, color: primaryColor),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Reset code is required';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _newPasswordController,
                    obscureText: _obscureNewPassword,
                    style: GoogleFonts.poppins(color: isDark ? Colors.white : Colors.black87),
                    decoration: InputDecoration(
                      labelText: 'New Password',
                      prefixIcon: Icon(Icons.lock_outline_rounded, color: primaryColor),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureNewPassword ? Icons.visibility_off : Icons.visibility,
                          color: Colors.grey,
                        ),
                        onPressed: () => setState(() => _obscureNewPassword = !_obscureNewPassword),
                      ),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    ),
                    validator: (v) {
                      if (v == null || v.length < 6) {
                        return 'Password must be at least 6 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: _obscureConfirmPassword,
                    style: GoogleFonts.poppins(color: isDark ? Colors.white : Colors.black87),
                    decoration: InputDecoration(
                      labelText: 'Confirm New Password',
                      prefixIcon: Icon(Icons.lock_reset_rounded, color: primaryColor),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                          color: Colors.grey,
                        ),
                        onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                      ),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    ),
                    validator: (v) {
                      if (v != _newPasswordController.text) {
                        return 'Passwords do not match';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _isResettingWithCode ? null : _handleResetWithCode,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isResettingWithCode
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : Text(
                              'Save Password & Access Portal',
                              style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildStepItem({required String step, required String text, required bool isDark}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          ),
          child: Center(
            child: Text(
              step,
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRoleTab({
    required String role,
    required String label,
    required IconData icon,
    required Color color,
  }) {
    final isSelected = _selectedRole == role;
    return GestureDetector(
      onTap: () => setState(() => _selectedRole = role),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  )
                ]
              : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? Colors.white : Colors.grey,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
