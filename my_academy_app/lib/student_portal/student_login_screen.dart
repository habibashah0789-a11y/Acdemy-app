import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../login/login_screen.dart';
import '../theme/app_theme.dart';
import '../widgets/shimmer_loading_widget.dart';
import '../widgets/custom_card.dart';
import 'student_auth_service.dart';
import 'student_main_wrapper.dart';
import 'student_qr_scanner_screen.dart';
import '../services/notification_service.dart';


class StudentLoginScreen extends StatefulWidget {
  final String? message;
  const StudentLoginScreen({super.key, this.message});

  @override
  State<StudentLoginScreen> createState() => _StudentLoginScreenState();
}

class _StudentLoginScreenState extends State<StudentLoginScreen> {
  final _studentIdController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  String? _scannedToken;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _studentIdController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin({bool isQrScan = false}) async {
    final enteredCode = _studentIdController.text.trim();
    final tokenToUse = (_scannedToken != null && _scannedToken!.isNotEmpty)
        ? _scannedToken!
        : enteredCode;

    if (!isQrScan) {
      if (!(_formKey.currentState?.validate() ?? false)) return;
    } else {
      if (enteredCode.isEmpty && tokenToUse.isEmpty) return;
    }

    debugPrint('[QR BINDING] login started');

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final studentId = await StudentAuthService.loginStudent(
        studentCode: enteredCode.isNotEmpty ? enteredCode : tokenToUse,
        scannedQrToken: tokenToUse,
      );

      await NotificationService.init();
      await NotificationService.registerFcmToken(
        userId: studentId,
        role: 'student',
        studentId: studentId,
      );
      NotificationService.listenForStudent(studentId);

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const StudentMainWrapper()),
          (_) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _openScanner() async {
    setState(() => _errorMessage = null);

    final result = await Navigator.of(context).push<StudentQrScanResult>(
      MaterialPageRoute(
        builder: (_) => const StudentQrScannerScreen(),
      ),
    );

    if (result != null && mounted) {
      debugPrint('[QR LIVE TEST] QR detected');
      debugPrint('[QR LIVE TEST] studentCode = ${result.studentCode}');
      setState(() {
        if (result.studentCode.isNotEmpty) {
          _studentIdController.text = result.studentCode;
        }
        _scannedToken = result.token ?? result.rawData;
        _errorMessage = null;
      });

      // Automatically trigger login process upon scanning valid QR code
      _handleLogin(isQrScan: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: [
          // Elegant Header Gradient Blob Background
          Positioned(
            top: -100,
            left: -50,
            right: -50,
            child: Container(
              height: 320,
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(160)),
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 36),

                  // Brand Icon & Title
                  Container(
                    height: 96,
                    width: 96,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(26),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryBlue.withValues(alpha: 0.25),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        )
                      ],
                    ),
                    child: const Icon(
                      Icons.school_rounded,
                      size: 52,
                      color: AppTheme.primaryBlue,
                    ),
                  ).animate().fadeIn(duration: 500.ms).scale(begin: const Offset(0.85, 0.85)),

                  const SizedBox(height: 20),

                  Text(
                    'Quaid Academy',
                    style: GoogleFonts.poppins(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : AppTheme.primaryDarkBlue,
                    ),
                  ).animate().fadeIn(),

                  Text(
                    'Student Access Portal',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.5,
                    ),
                  ).animate().fadeIn(),

                  if (widget.message != null) ...[
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: AppTheme.warningRed.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.warningRed.withValues(alpha: 0.2)),
                      ),
                      child: Text(
                        widget.message!,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          color: AppTheme.warningRed,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ).animate().fadeIn().shake(hz: 3, curve: Curves.easeInOut),
                  ],

                  const SizedBox(height: 36),

                  // Step 1: QR Code Section
                  _buildStepCard(
                    stepNumber: '1',
                    title: 'Scan Your QR Access Code',
                    child: Column(
                      children: [
                        Text(
                          _scannedToken == null
                              ? 'Scan the official student QR code provided by administration'
                              : 'QR Code verified successfully',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: _scannedToken == null
                                ? (isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary)
                                : AppTheme.secondaryGreen,
                            fontWeight: _scannedToken != null ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (_scannedToken != null)
                          _buildSuccessBadge('QR Token Authenticated ✓')
                        else
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _openScanner,
                              icon: const Icon(Icons.qr_code_scanner_rounded),
                              label: const Text('Scan Student QR Code'),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 15),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                            ),
                          ),
                        if (_scannedToken != null)
                          TextButton.icon(
                            onPressed: _openScanner,
                            icon: const Icon(Icons.refresh_rounded, size: 16),
                            label: const Text('Scan Different Code'),
                          ),
                      ],
                    ),
                  ).animate().fadeIn().slideY(begin: 0.08),

                  const SizedBox(height: 18),

                  // Step 2: Student ID Input
                  _buildStepCard(
                    stepNumber: '2',
                    title: 'Enter Your Student Code',
                    isLocked: false,
                    child: Form(
                      key: _formKey,
                      child: TextFormField(
                        controller: _studentIdController,
                        textCapitalization: TextCapitalization.characters,
                        enabled: true,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) {
                          if (!_isLoading) _handleLogin();
                        },
                        decoration: InputDecoration(
                          hintText: 'e.g. QA-9-2026-001 or QA-11-2026-001',
                          prefixIcon: const Icon(
                            Icons.badge_rounded,
                            color: AppTheme.primaryBlue,
                          ),
                          labelText: 'Student ID',
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Please enter your assigned Student ID';
                          }
                          return null;
                        },
                      ),
                    ),
                  ).animate().fadeIn().slideY(begin: 0.08),

                  const SizedBox(height: 16),

                  // Error Banner
                  if (_errorMessage != null)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppTheme.warningRed.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppTheme.warningRed.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline_rounded, color: AppTheme.warningRed, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(color: AppTheme.warningRed, fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    ).animate().fadeIn().shakeX(),

                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    child: InlineLoadingButton(
                      isLoading: _isLoading,
                      label: 'Access Student Portal',
                      loadingLabel: 'Verifying Credentials...',
                      icon: Icons.arrow_forward_rounded,
                      onPressed: _handleLogin,
                    ),
                  ).animate().fadeIn(),

                  const SizedBox(height: 32),



                  const SizedBox(height: 16),

                  Text(
                    'Need assistance? Contact the Academy Administration',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepCard({
    required String stepNumber,
    required String title,
    required Widget child,
    bool isLocked = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return CustomCard(
      padding: const EdgeInsets.all(20),
      child: Opacity(
        opacity: isLocked ? 0.5 : 1.0,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    gradient: isLocked
                        ? null
                        : AppTheme.primaryGradient,
                    color: isLocked
                        ? (isDark ? Colors.grey.shade700 : Colors.grey.shade300)
                        : null,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: isLocked
                        ? Icon(Icons.lock_outline_rounded,
                            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                            size: 16)
                        : Text(
                            stepNumber,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: isLocked
                          ? (isDark ? Colors.grey.shade500 : Colors.grey.shade600)
                          : null,
                    ),
                  ),
                ),
                if (isLocked)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Locked',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessBadge(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: AppTheme.secondaryGreen.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.secondaryGreen.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle_rounded, color: AppTheme.secondaryGreen, size: 20),
          const SizedBox(width: 10),
          Text(
            text,
            style: const TextStyle(
              color: AppTheme.secondaryGreen,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
