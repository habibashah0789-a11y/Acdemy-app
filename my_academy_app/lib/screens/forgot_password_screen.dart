import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/password_recovery_service.dart';
import '../services/sound_service.dart';
import '../theme/app_theme.dart';
import '../theme/ui_helpers.dart';
import '../widgets/portal_loading_screen.dart';
import 'main_wrapper.dart';
import '../teacher_portal/teacher_main_wrapper.dart';
import '../models/teacher_model.dart';

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
  bool _codeSent = false;
  bool _isLoading = false;
  bool _isVerifying = false;
  String? _statusMessage;
  String? _lastGeneratedOtp;
  TeacherModel? _matchedTeacher;

  // 6 Digit OTP controllers & focus nodes
  final List<TextEditingController> _otpControllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _otpFocusNodes =
      List.generate(6, (_) => FocusNode());

  // Countdown timer (15 minutes)
  Timer? _countdownTimer;
  int _secondsRemaining = 15 * 60;

  @override
  void initState() {
    super.initState();
    _selectedRole = widget.initialRole;
    if (widget.initialEmail != null && widget.initialEmail!.isNotEmpty) {
      _emailController.text = widget.initialEmail!;
    }
    for (int i = 0; i < 6; i++) {
      final index = i;
      _otpFocusNodes[index].onKeyEvent = (node, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.backspace &&
            _otpControllers[index].text.isEmpty &&
            index > 0) {
          _otpFocusNodes[index - 1].requestFocus();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      };
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _emailController.dispose();
    for (final c in _otpControllers) {
      c.dispose();
    }
    for (final f in _otpFocusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _startTimer() {
    _countdownTimer?.cancel();
    setState(() => _secondsRemaining = 15 * 60);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining <= 1) {
        timer.cancel();
        setState(() => _secondsRemaining = 0);
      } else {
        setState(() => _secondsRemaining--);
      }
    });
  }

  String _formatTimer(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String get _currentOtpEntered {
    return _otpControllers.map((c) => c.text.trim()).join();
  }

  Future<void> _handleSendOtpAndLink() async {
    if (!_formKey.currentState!.validate()) return;
    final email = _emailController.text.trim();

    setState(() {
      _isLoading = true;
      _statusMessage = null;
    });

    try {
      final result = await PasswordRecoveryService.sendRecoveryOtpAndLink(
        email: email,
        role: _selectedRole,
      );

      _matchedTeacher = result['teacher'] as TeacherModel?;
      _lastGeneratedOtp = result['otp'] as String?;

      if (mounted) {
        setState(() {
          _codeSent = true;
          _isLoading = false;
        });
        _startTimer();
        // Focus first OTP field
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted && _otpFocusNodes.isNotEmpty) {
            _otpFocusNodes[0].requestFocus();
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Verification OTP & password reset link sent to $email',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
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

  Future<void> _handleVerifyOtp() async {
    final enteredOtp = _currentOtpEntered;
    if (enteredOtp.length != 6) {
      UIHelpers.showCustomSnackBar(
        context,
        'Please enter all 6 digits of the OTP code.',
        isError: true,
      );
      return;
    }

    setState(() => _isVerifying = true);

    try {
      final result = await PasswordRecoveryService.verifyOtp(
        email: _emailController.text.trim(),
        enteredOtp: enteredOtp,
        role: _selectedRole,
      );

      _countdownTimer?.cancel();
      await SoundService.playNotification();

      if (mounted) {
        final teacher = result['teacher'] as TeacherModel? ?? _matchedTeacher;
        final userName = result['userName'] as String? ?? (_selectedRole == 'admin' ? 'Administrator' : 'Teacher');

        // Route directly to respective portal via beautiful portal loading transition
        if (_selectedRole == 'teacher') {
          final targetTeacher = teacher ??
              TeacherModel(
                id: 'temp_teacher',
                name: userName,
                email: _emailController.text.trim(),
                teacherId: 'T-FAC-001',
                subject: 'Faculty',
                section: 'FSc',
                assignedClasses: const ['First Year'],
                createdAt: DateTime.now(),
              );

          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (portalCtx) => PortalLoadingScreen.teacher(
                teacherName: targetTeacher.name,
                subject: targetTeacher.subject,
                onComplete: () {
                  Navigator.of(portalCtx).pushAndRemoveUntil(
                    MaterialPageRoute(
                      builder: (_) => TeacherMainWrapper(teacher: targetTeacher),
                    ),
                    (_) => false,
                  );
                },
              ),
            ),
            (_) => false,
          );
        } else {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (portalCtx) => PortalLoadingScreen.admin(
                adminName: userName,
                onComplete: () {
                  Navigator.of(portalCtx).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const MainWrapper()),
                    (_) => false,
                  );
                },
              ),
            ),
            (_) => false,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isVerifying = false);
        UIHelpers.showCustomSnackBar(
          context,
          e.toString().replaceFirst('Exception: ', ''),
          isError: true,
        );
      }
    }
  }

  void _onDigitChanged(String val, int index) {
    if (val.length > 1) {
      final lastChar = val.substring(val.length - 1);
      _otpControllers[index].text = lastChar;
      _otpControllers[index].selection = const TextSelection.collapsed(offset: 1);
      if (index < 5) {
        _otpFocusNodes[index + 1].requestFocus();
      }
    } else if (val.length == 1 && index < 5) {
      _otpFocusNodes[index + 1].requestFocus();
    } else if (val.isEmpty && index > 0) {
      _otpFocusNodes[index - 1].requestFocus();
    }
    // Auto-verify if all 6 digits filled
    if (_currentOtpEntered.length == 6) {
      _handleVerifyOtp();
    }
  }

  void _fillPastedOtp(String code) {
    final clean = code.replaceAll(RegExp(r'\D'), '');
    if (clean.length == 6) {
      for (int i = 0; i < 6; i++) {
        _otpControllers[i].text = clean[i];
      }
      _handleVerifyOtp();
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
          'Password Recovery',
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Top Icon Header
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: primaryColor.withValues(alpha: 0.12),
                  border: Border.all(color: primaryColor.withValues(alpha: 0.25), width: 2),
                ),
                child: Center(
                  child: Icon(
                    _selectedRole == 'admin'
                        ? Icons.admin_panel_settings_rounded
                        : Icons.school_rounded,
                    color: primaryColor,
                    size: 38,
                  ),
                ),
              ).animate().scale(duration: 400.ms),

              const SizedBox(height: 16),

              Text(
                _codeSent ? 'Enter Verification Code' : 'Forgot Password?',
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),

              const SizedBox(height: 6),

              Text(
                _codeSent
                    ? 'Enter the 6-digit OTP code sent to your email to directly access your ${_selectedRole.toUpperCase()} portal.'
                    : 'Select your role and enter your registered email to receive an instant verification OTP & reset link.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),

              const SizedBox(height: 24),

              // Role Selector Chips (only editable before code is sent)
              if (!_codeSent) ...[
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
                const SizedBox(height: 24),
              ],

              // Phase 1: Email Form
              if (!_codeSent) ...[
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          labelText: 'Registered ${_selectedRole == "admin" ? "Admin" : "Teacher"} Email',
                          prefixIcon: Icon(Icons.email_outlined, color: primaryColor),
                          hintText: 'user@quaid.edu',
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

                      // Info box explaining dual OTP & link delivery
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
                            Icon(Icons.info_outline_rounded, color: primaryColor, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'A 6-digit OTP code will be generated and an official Firebase reset link will be sent to your email for instant portal access.',
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
                          onPressed: _isLoading ? null : _handleSendOtpAndLink,
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
                                      'Send Verification OTP & Link',
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
                ),
              ] else ...[
                // Phase 2: OTP Verification Form
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.mark_email_read_rounded, size: 16, color: primaryColor),
                      const SizedBox(width: 8),
                      Text(
                        _emailController.text.trim(),
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: primaryColor,
                        ),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: () {
                          _countdownTimer?.cancel();
                          setState(() => _codeSent = false);
                        },
                        child: const Icon(Icons.edit, size: 14, color: Colors.grey),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // 6 Pin digit input boxes
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(6, (i) {
                    return Container(
                      width: 46,
                      height: 54,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      child: TextFormField(
                        controller: _otpControllers[i],
                        focusNode: _otpFocusNodes[i],
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
                        decoration: InputDecoration(
                          counterText: '',
                          contentPadding: EdgeInsets.zero,
                          filled: true,
                          fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: isDark ? Colors.white12 : Colors.grey.shade300,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: primaryColor, width: 2),
                          ),
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(2),
                        ],
                        onChanged: (v) => _onDigitChanged(v, i),
                      ),
                    );
                  }),
                ),

                const SizedBox(height: 20),

                // Timer & Resend Option
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.timer_outlined, size: 16, color: Colors.grey.shade600),
                    const SizedBox(width: 6),
                    Text(
                      _secondsRemaining > 0
                          ? 'Code expires in ${_formatTimer(_secondsRemaining)}'
                          : 'Code expired',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: _secondsRemaining > 0 ? Colors.grey.shade600 : Colors.red,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 12),
                    TextButton(
                      onPressed: (_secondsRemaining == 0 || !_isLoading)
                          ? _handleSendOtpAndLink
                          : null,
                      style: TextButton.styleFrom(
                        foregroundColor: primaryColor,
                        padding: EdgeInsets.zero,
                      ),
                      child: Text(
                        'Resend OTP',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),

                // Instant OTP preview banner for development/demo testing
                if (_lastGeneratedOtp != null) ...[
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () => _fillPastedOtp(_lastGeneratedOtp!),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.lock_clock_rounded, size: 16, color: Colors.amber),
                          const SizedBox(width: 8),
                          Text(
                            'Active OTP: $_lastGeneratedOtp (Tap to auto-fill)',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.amber.shade900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 28),

                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isVerifying ? null : _handleVerifyOtp,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 4,
                    ),
                    child: _isVerifying
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.verified_user_rounded, size: 20),
                              const SizedBox(width: 10),
                              Text(
                                'Verify OTP & Access Portal',
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
            ],
          ),
        ),
      ),
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
