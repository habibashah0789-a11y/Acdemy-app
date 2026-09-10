import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../models/student_model.dart';
import '../student_portal/student_auth_service.dart';
import '../theme/app_theme.dart';
import 'shimmer_loading_widget.dart';

/// Modern, scannable QR Code Widget powered by `qr_flutter`.
/// Encodes structured JSON containing minimum necessary auth fields.
class StudentQrWidget extends StatelessWidget {
  final StudentModel student;
  final double size;
  final bool showLabel;
  final String? customQrData;
  final String? qrToken;

  const StudentQrWidget({
    super.key,
    required this.student,
    this.size = 200,
    this.showLabel = true,
    this.customQrData,
    this.qrToken,
  });

  String _buildPayload() {
    if (customQrData != null && customQrData!.trim().startsWith('{')) {
      return customQrData!.trim();
    }

    final token = qrToken ?? customQrData;
    final Map<String, dynamic> payload = {
      'type': 'student_access',
      'version': 1,
      'studentCode': student.studentCode,
      'studentId': student.id,
      'token': token ?? student.id,
    };
    return jsonEncode(payload);
  }

  @override
  Widget build(BuildContext context) {
    final payloadString = _buildPayload();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
            border: Border.all(
              color: AppTheme.primaryBlue.withValues(alpha: 0.25),
              width: 2,
            ),
          ),
          child: QrImageView(
            data: payloadString,
            version: QrVersions.auto,
            size: size,
            gapless: true,
            padding: const EdgeInsets.all(8),
            errorCorrectionLevel: QrErrorCorrectLevel.M,
            backgroundColor: Colors.white,
            eyeStyle: const QrEyeStyle(
              eyeShape: QrEyeShape.square,
              color: Color(0xFF0F172A),
            ),
            dataModuleStyle: const QrDataModuleStyle(
              dataModuleShape: QrDataModuleShape.square,
              color: Color(0xFF0F172A),
            ),
          ),
        ),
        if (showLabel) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.primaryBlue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              student.studentCode,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryBlue,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Displays the student's official QR Access Pass dialog.
void showStudentQrDialog(
  BuildContext context,
  StudentModel student, {
  String? customQrData,
}) {
  showDialog(
    context: context,
    builder: (context) {
      return _StudentQrDialogContent(
        student: student,
        customQrData: customQrData,
      );
    },
  );
}

class _StudentQrDialogContent extends StatefulWidget {
  final StudentModel student;
  final String? customQrData;

  const _StudentQrDialogContent({
    required this.student,
    this.customQrData,
  });

  @override
  State<_StudentQrDialogContent> createState() => _StudentQrDialogContentState();
}

class _StudentQrDialogContentState extends State<_StudentQrDialogContent> {
  String? _token;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    if (widget.customQrData != null && widget.customQrData!.trim().isNotEmpty) {
      _token = widget.customQrData;
      _isLoading = false;
    } else {
      _fetchToken();
    }
  }

  Future<void> _fetchToken() async {
    try {
      final info = await StudentAuthService.getOrGenerateStudentAuthInfo(
        studentId: widget.student.id,
        studentCode: widget.student.studentCode,
        studentName: widget.student.name,
      );
      if (mounted) {
        setState(() {
          _token = info['qrToken']?.toString();
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final student = widget.student;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Official Student Pass',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          student.name,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (_isLoading)
                const SizedBox(
                  height: 220,
                  child: Center(
                    child: ShimmerLoadingWidget(width: 200, height: 200, borderRadius: 20),
                  ),
                )
              else
                StudentQrWidget(
                  student: student,
                  size: 210,
                  showLabel: true,
                  customQrData: widget.customQrData,
                  qrToken: _token,
                ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.primaryBlue.withValues(alpha: 0.15),
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      '${student.classType} • ${student.grade}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      student.subject,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    if (student.phone.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Ph: ${student.phone}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.phonelink_lock_rounded, size: 14, color: Colors.grey),
                  const SizedBox(width: 6),
                  Text(
                    'Protected: 1 device active at a time',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
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
