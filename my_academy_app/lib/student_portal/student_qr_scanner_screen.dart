import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../theme/app_theme.dart';

/// Result object returned by [StudentQrScannerScreen] upon a successful scan.
class StudentQrScanResult {
  final String studentCode;
  final String? token;
  final String rawData;

  StudentQrScanResult({
    required this.studentCode,
    this.token,
    required this.rawData,
  });
}

/// Helper class to safely parse and validate QR code payloads.
class StudentQrParser {
  /// Safely masks tokens for production/debug logs (e.g. `abcd****wxyz`).
  static String maskToken(String token) {
    final trimmed = token.trim();
    if (trimmed.length <= 8) return '****';
    return '${trimmed.substring(0, 4)}****${trimmed.substring(trimmed.length - 4)}';
  }

  /// Parses raw QR payload into a valid [StudentQrScanResult] or null if invalid.
  static StudentQrScanResult? parseQrPayload(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;

    // ── Format 1: JSON Payload ──
    if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
      try {
        final Map<String, dynamic> json = jsonDecode(trimmed);
        final type = json['type']?.toString();
        if (type != null && type != 'student_access' && type != 'student_qr') {
          return null;
        }

        final code = json['studentCode'] ?? json['student_code'] ?? json['code'] ?? json['studentId'];
        final token = json['token'] ?? json['qrToken'] ?? json['qr_token'];

        if (code != null && code.toString().trim().isNotEmpty) {
          return StudentQrScanResult(
            studentCode: code.toString().trim().toUpperCase(),
            token: token?.toString().trim(),
            rawData: trimmed,
          );
        }
      } catch (e) {
        debugPrint('[StudentQrParser] JSON parse error: $e');
      }
    }

    // ── Format 2: Quaid Academy formatted payload string (e.g. QA-STUDENT:QA-2026-001:ID=...) ──
    if (trimmed.startsWith('QA-STUDENT:')) {
      final parts = trimmed.split(':');
      if (parts.length >= 2) {
        final codePart = parts[1].trim().toUpperCase();
        if (codePart.isNotEmpty) {
          return StudentQrScanResult(
            studentCode: codePart,
            token: parts.length > 2 ? parts[2].replaceFirst('ID=', '').trim() : null,
            rawData: trimmed,
          );
        }
      }
    }

    // ── Format 3: Plain Student Code (e.g. QA-2026-001 or STU-1002) ──
    final studentCodeRegex = RegExp(r'^[A-Z0-9]{2,10}-[A-Z0-9\-]{2,15}$', caseSensitive: false);
    if (studentCodeRegex.hasMatch(trimmed)) {
      return StudentQrScanResult(
        studentCode: trimmed.toUpperCase(),
        token: trimmed,
        rawData: trimmed,
      );
    }

    // ── Format 4: UUID v4 QR Token (e.g. c7a4e610-8b65-4e78-9e6b-76f8e70a1c32) ──
    final uuidRegex = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
    if (uuidRegex.hasMatch(trimmed)) {
      return StudentQrScanResult(
        studentCode: '',
        token: trimmed,
        rawData: trimmed,
      );
    }

    // ── Fallback Format: Alphanumeric String ──
    if (trimmed.length >= 3 && trimmed.length <= 64 && !trimmed.contains('\n')) {
      return StudentQrScanResult(
        studentCode: trimmed.toUpperCase(),
        token: trimmed,
        rawData: trimmed,
      );
    }

    return null;
  }
}

/// Dedicated modern QR Code Scanner screen using `mobile_scanner`.
class StudentQrScannerScreen extends StatefulWidget {
  const StudentQrScannerScreen({super.key});

  @override
  State<StudentQrScannerScreen> createState() => _StudentQrScannerScreenState();
}

class _StudentQrScannerScreenState extends State<StudentQrScannerScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  MobileScannerController? _scannerController;
  late final AnimationController _laserController;
  late final Animation<double> _laserAnimation;

  bool _isProcessingScan = false;
  bool _showSuccess = false;
  bool _isTorchOn = false;
  String? _scanError;

  bool get _isMobilePlatform {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _laserController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _laserAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _laserController, curve: Curves.easeInOut),
    );

    if (_isMobilePlatform) {
      _scannerController = MobileScannerController(
        detectionSpeed: DetectionSpeed.normal,
        facing: CameraFacing.back,
        torchEnabled: false,
      );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_isMobilePlatform) return;
    if (_scannerController == null || !_scannerController!.value.isInitialized) return;

    switch (state) {
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        _scannerController?.stop();
        break;
      case AppLifecycleState.resumed:
        if (!_isProcessingScan && !_showSuccess) {
          _scannerController?.start();
        }
        break;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _laserController.dispose();
    if (_isMobilePlatform) {
      _scannerController?.dispose();
    }
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) async {
    if (_isProcessingScan || _showSuccess) return;

    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final barcode = barcodes.first;
    final rawValue = barcode.rawValue;
    if (rawValue == null || rawValue.trim().isEmpty) return;

    setState(() {
      _isProcessingScan = true;
    });

    final masked = StudentQrParser.maskToken(rawValue);
    debugPrint('[StudentQrScanner] Detected QR token: $masked');

    final scanResult = StudentQrParser.parseQrPayload(rawValue);

    if (scanResult == null) {
      HapticFeedback.heavyImpact();
      if (mounted) {
        setState(() {
          _scanError = 'Invalid student QR code. Please scan official academy QR code.';
        });
      }
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        setState(() {
          _scanError = null;
          _isProcessingScan = false;
        });
      }
      return;
    }

    HapticFeedback.mediumImpact();

    if (mounted) {
      setState(() {
        _showSuccess = true;
        _scanError = null;
      });
    }

    try {
      await _scannerController?.stop();
    } catch (_) {}

    await Future.delayed(const Duration(milliseconds: 350));

    if (mounted) {
      Navigator.of(context).pop(scanResult);
    }
  }

  void _toggleFlashlight() async {
    if (!_isMobilePlatform) return;
    try {
      await _scannerController?.toggleTorch();
      setState(() {
        _isTorchOn = !_isTorchOn;
      });
    } catch (e) {
      debugPrint('[StudentQrScanner] Toggle torch error: $e');
    }
  }

  void _switchCamera() async {
    if (!_isMobilePlatform) return;
    try {
      await _scannerController?.switchCamera();
    } catch (e) {
      debugPrint('[StudentQrScanner] Switch camera error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _isMobilePlatform ? _buildMobileScannerUI() : _buildDesktopFallbackUI(),
    );
  }

  Widget _buildDesktopFallbackUI() {
    return SafeArea(
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppTheme.primaryBlue.withValues(alpha: 0.3)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.no_photography_rounded,
                  size: 48,
                  color: AppTheme.primaryBlue,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Camera Scanner Unavailable',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'QR scanning is supported on Android and iOS mobile devices.\n\nPlease enter your assigned Student ID manually on Desktop.',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: Colors.grey.shade400,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.keyboard_outlined),
                  label: const Text('Use Manual Student ID Entry'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileScannerUI() {
    final screenSize = MediaQuery.of(context).size;
    final scanBoxSize = (screenSize.width * 0.72).clamp(220.0, 320.0);

    return Stack(
      children: [
        // ── Camera Preview ──
        MobileScanner(
          controller: _scannerController,
          onDetect: _onDetect,
          errorBuilder: (context, error) {
            return _buildCameraErrorUI(error);
          },
        ),

        // ── Dark Mask Overlay ──
        CustomPaint(
          size: Size.infinite,
          painter: _ScannerOverlayPainter(scanBoxSize: scanBoxSize),
        ),

        // ── Animated Scanner Laser Box ──
        Center(
          child: SizedBox(
            width: scanBoxSize,
            height: scanBoxSize,
            child: Stack(
              children: [
                // Corner Brackets
                _buildCornerBrackets(scanBoxSize),

                // Moving Laser Line
                if (!_showSuccess)
                  AnimatedBuilder(
                    animation: _laserAnimation,
                    builder: (context, child) {
                      return Positioned(
                        top: _laserAnimation.value * (scanBoxSize - 4),
                        left: 8,
                        right: 8,
                        child: Container(
                          height: 3,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppTheme.primaryBlue.withValues(alpha: 0.1),
                                AppTheme.primaryBlue,
                                AppTheme.secondaryGreen,
                                AppTheme.primaryBlue,
                                AppTheme.primaryBlue.withValues(alpha: 0.1),
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.primaryBlue.withValues(alpha: 0.8),
                                blurRadius: 8,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),

                // Success Overlay Indicator
                if (_showSuccess)
                  Container(
                    decoration: BoxDecoration(
                      color: AppTheme.secondaryGreen.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppTheme.secondaryGreen, width: 3),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.check_circle_rounded,
                        color: Colors.white,
                        size: 72,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),

        // ── Top Header Controls ──
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Close Button
                CircleAvatar(
                  backgroundColor: Colors.black54,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: 'Close Scanner',
                  ),
                ),

                // Header Title
                Text(
                  'Scan Student QR',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                // Flashlight & Camera Switch
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.black54,
                      child: IconButton(
                        icon: Icon(
                          _isTorchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                          color: _isTorchOn ? Colors.yellow : Colors.white,
                        ),
                        onPressed: _toggleFlashlight,
                        tooltip: 'Toggle Flashlight',
                      ),
                    ),
                    const SizedBox(width: 8),
                    CircleAvatar(
                      backgroundColor: Colors.black54,
                      child: IconButton(
                        icon: const Icon(Icons.cameraswitch_rounded, color: Colors.white),
                        onPressed: _switchCamera,
                        tooltip: 'Switch Camera',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // ── Bottom Instruction / Error Card ──
        Positioned(
          bottom: 40,
          left: 20,
          right: 20,
          child: Column(
            children: [
              if (_scanError != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade900.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.redAccent),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, color: Colors.white),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _scanError!,
                          style: GoogleFonts.poppins(color: Colors.white, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white24),
                ),
                child: Text(
                  _showSuccess
                      ? '✓ QR Code Authenticated Successfully!'
                      : 'Place the official student QR code inside the frame',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    color: _showSuccess ? AppTheme.secondaryGreen : Colors.white,
                    fontSize: 13,
                    fontWeight: _showSuccess ? FontWeight.bold : FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCornerBrackets(double size) {
    const double length = 28;
    const double width = 4;
    final color = _showSuccess ? AppTheme.secondaryGreen : AppTheme.primaryBlue;

    return Stack(
      children: [
        // Top-Left
        Positioned(top: 0, left: 0, child: _cornerWidget(color, width, length, isTop: true, isLeft: true)),
        // Top-Right
        Positioned(top: 0, right: 0, child: _cornerWidget(color, width, length, isTop: true, isLeft: false)),
        // Bottom-Left
        Positioned(bottom: 0, left: 0, child: _cornerWidget(color, width, length, isTop: false, isLeft: true)),
        // Bottom-Right
        Positioned(bottom: 0, right: 0, child: _cornerWidget(color, width, length, isTop: false, isLeft: false)),
      ],
    );
  }

  Widget _cornerWidget(Color color, double thickness, double length, {required bool isTop, required bool isLeft}) {
    return SizedBox(
      width: length,
      height: length,
      child: CustomPaint(
        painter: _CornerPainter(color: color, thickness: thickness, isTop: isTop, isLeft: isLeft),
      ),
    );
  }

  Widget _buildCameraErrorUI(MobileScannerException error) {
    return SafeArea(
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.camera_alt_outlined, size: 56, color: Colors.orangeAccent),
              const SizedBox(height: 16),
              Text(
                'Camera Access Required',
                style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 10),
              Text(
                'Camera permission is required to scan the student QR code.',
                style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade300),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white38),
                    ),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () {
                      _scannerController?.start();
                    },
                    child: const Text('Try Again'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Custom painter for semi-transparent dark overlay around scanning square.
class _ScannerOverlayPainter extends CustomPainter {
  final double scanBoxSize;

  _ScannerOverlayPainter({required this.scanBoxSize});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0x99000000);

    final left = (size.width - scanBoxSize) / 2;
    final top = (size.height - scanBoxSize) / 2;
    final rect = Rect.fromLTWH(left, top, scanBoxSize, scanBoxSize);

    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(20)))
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _ScannerOverlayPainter oldDelegate) {
    return oldDelegate.scanBoxSize != scanBoxSize;
  }
}

/// Custom painter for scanner frame corner brackets.
class _CornerPainter extends CustomPainter {
  final Color color;
  final double thickness;
  final bool isTop;
  final bool isLeft;

  _CornerPainter({
    required this.color,
    required this.thickness,
    required this.isTop,
    required this.isLeft,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = thickness
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    if (isTop && isLeft) {
      path.moveTo(0, size.height);
      path.lineTo(0, 0);
      path.lineTo(size.width, 0);
    } else if (isTop && !isLeft) {
      path.moveTo(0, 0);
      path.lineTo(size.width, 0);
      path.lineTo(size.width, size.height);
    } else if (!isTop && isLeft) {
      path.moveTo(0, 0);
      path.lineTo(0, size.height);
      path.lineTo(size.width, size.height);
    } else {
      path.moveTo(0, size.height);
      path.lineTo(size.width, size.height);
      path.lineTo(size.width, 0);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _CornerPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.thickness != thickness ||
        oldDelegate.isTop != isTop ||
        oldDelegate.isLeft != isLeft;
  }
}
