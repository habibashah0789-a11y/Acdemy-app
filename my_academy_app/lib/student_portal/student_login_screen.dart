import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_card.dart';
import 'student_auth_service.dart';
import 'student_main_wrapper.dart';

class StudentLoginScreen extends StatefulWidget {
  const StudentLoginScreen({super.key});

  @override
  State<StudentLoginScreen> createState() => _StudentLoginScreenState();
}

class _StudentLoginScreenState extends State<StudentLoginScreen> {
  final _studentIdController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  String? _scannedToken;
  bool _isLoading = false;
  bool _isScannerOpen = false;
  String? _errorMessage;

  @override
  void dispose() {
    _studentIdController.dispose();
    super.dispose();
  }

  void _onQrDetected(BarcodeCapture capture) {
    if (_scannedToken != null) return;
    final barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      final raw = barcode.rawValue ?? '';
      if (raw.isNotEmpty) {
        setState(() {
          _scannedToken = raw;
          _isScannerOpen = false;
          _errorMessage = null;
        });
        return;
      }
    }
  }

  Future<void> _handleLogin() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_scannedToken == null || _scannedToken!.isEmpty) {
      setState(() => _errorMessage = 'Please scan your academy QR code first.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await StudentAuthService.loginStudent(
        studentCode: _studentIdController.text.trim(),
        scannedQrToken: _scannedToken!,
      );

      // After successful login, the main app's AuthWrapper will detect
      // the auth state change and route to StudentMainWrapper automatically.
      // We just need to pop back to the root so AuthWrapper takes over.
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
          _scannedToken = null;
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _openScanner() {
    setState(() {
      _isScannerOpen = true;
      _scannedToken = null;
      _errorMessage = null;
    });
  }

  void _closeScanner() {
    setState(() => _isScannerOpen = false);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isScannerOpen) {
      return _buildScannerView();
    }

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
                  const SizedBox(height: 16),

                  // Top Navigation Back Button
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      icon: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),

                  const SizedBox(height: 12),

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
                  ).animate().fadeIn(delay: 150.ms),

                  Text(
                    'Student Access Portal',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.5,
                    ),
                  ).animate().fadeIn(delay: 250.ms),

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
                  ).animate().fadeIn(delay: 350.ms).slideY(begin: 0.08),

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
                        decoration: InputDecoration(
                          hintText: 'e.g. QA-2026-001',
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
                  ).animate().fadeIn(delay: 450.ms).slideY(begin: 0.08),

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
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleLogin,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.5,
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Access Student Portal',
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(Icons.arrow_forward_rounded, size: 18),
                              ],
                            ),
                    ),
                  ).animate().fadeIn(delay: 550.ms),

                  const SizedBox(height: 32),

                  Text(
                    'Need assistance? Contact Academy Administration Office',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 24),
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

  Widget _buildScannerView() {
    final bool isMobile = !kIsWeb && 
        (defaultTargetPlatform == TargetPlatform.android || 
         defaultTargetPlatform == TargetPlatform.iOS);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          isMobile ? 'Scan Academy QR Code' : 'Enter Auth Token',
          style: GoogleFonts.poppins(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white),
          onPressed: _closeScanner,
        ),
      ),
      body: isMobile ? _buildCameraScanner() : _buildManualTokenEntry(),
    );
  }

  Widget _buildCameraScanner() {
    return Stack(
      children: [
        MobileScanner(
          onDetect: _onQrDetected,
        ),
        Center(
          child: Container(
            width: 250,
            height: 250,
            decoration: BoxDecoration(
              border: Border.all(color: AppTheme.primaryBlue, width: 3.5),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryBlue.withValues(alpha: 0.3),
                  blurRadius: 20,
                  spreadRadius: 4,
                )
              ],
            ),
          ),
        ),
        Positioned(
          bottom: 60,
          left: 20,
          right: 20,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              'Align camera frame over your academy student QR code',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildManualTokenEntry() {
    final tokenController = TextEditingController();
    return Center(
      child: Container(
        padding: const EdgeInsets.all(24),
        margin: const EdgeInsets.symmetric(horizontal: 32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.qr_code_scanner_rounded, size: 64, color: AppTheme.primaryBlue),
            const SizedBox(height: 16),
            Text(
              'Manual Token Entry',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Please enter the auth token provided on your academy ID slip.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            TextField(
              controller: tokenController,
              style: const TextStyle(color: Colors.black87),
              decoration: InputDecoration(
                labelText: 'QR Token / Auth Code',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  final token = tokenController.text.trim();
                  if (token.isNotEmpty) {
                    setState(() {
                      _scannedToken = token;
                      _isScannerOpen = false;
                      _errorMessage = null;
                    });
                  }
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Verify Token'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
