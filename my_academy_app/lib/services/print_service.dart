import 'package:flutter/material.dart';    //line #114 about  width: 120 is commented out in the code
import 'package:intl/intl.dart';           // because it is showing some error
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:convert';
import 'dart:io' as io;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/student_model.dart';
import 'database_service.dart';
import '../student_portal/student_auth_service.dart';
import 'audit_log_service.dart';
import 'pdf_helpers.dart';

class PrintService {
  static Future<void> printStudentReport(StudentModel student) async {
    try {
      await AuditLogService.logAction(
        actorId: student.id,
        actorName: student.name,
        actorRole: 'USER',
        action: 'STUDENT_REPORT_EXPORTED',
        transactionId: student.id,
        details: 'Exported PDF report for student ${student.name} (${student.id}).',
      );
    } catch (_) {}
    // Use a short timeout so a slow/offline Firestore call never hangs the print button.
    Map<String, dynamic>? authInfo;
    try {
      authInfo = await StudentAuthService.getStudentAuthInfo(student.id)
          .timeout(const Duration(seconds: 3));
    } catch (_) {
      // Firestore unavailable or timed-out — fall back to the QR data on the model.
      authInfo = null;
    }
    final token = authInfo?['qrToken']?.toString() ?? student.id;
    final qrCodeData = jsonEncode({
      'type': 'student_access',
      'version': 1,
      'studentCode': student.studentCode,
      'token': token,
    });

    final doc = pw.Document();
    final now = DateTime.now();

    final profile = DatabaseService.getAcademyProfile();
    final academyName = profile['name']?.toString().isNotEmpty == true
        ? profile['name'].toString()
        : 'Quaid Academy';
    final academyAddress = profile['address']?.toString() ?? '';
    final academyPhone = profile['phone']?.toString() ?? '';

    // ── Load student profile image ─────────────────────────────────────────
    pw.ImageProvider? profileImage;
    if (student.profilePicUrl.isNotEmpty) {
      try {
        final url = student.profilePicUrl;
        if (url.startsWith('http://') || url.startsWith('https://')) {
          // Limit network fetch to 5 s so a bad URL never hangs the print button.
          profileImage = await networkImage(url)
              .timeout(const Duration(seconds: 5));
        } else if (url.startsWith('data:image') ||
            (!url.contains('/') &&
                !url.contains('\\') &&
                url.length > 100)) {
          final base64Str =
              url.contains(',') ? url.split(',').last : url;
          final bytes = base64Decode(base64Str.trim());
          profileImage = pw.MemoryImage(bytes);
        } else if (url.startsWith('blob:')) {
          // Web blob URL — skip
        } else if (!kIsWeb) {
          final file = io.File(url);
          if (await file.exists()) {
            final bytes = await file.readAsBytes();
            profileImage = pw.MemoryImage(bytes);
          }
        }
      } catch (e) {
        debugPrint('Error loading profile image for PDF: $e');
        profileImage = null; // Proceed without image rather than hanging.
      }
    }

    // ── Load academy logo ──────────────────────────────────────────────────
    pw.MemoryImage? logoImage;
    try {
      final logoBytes =
          await rootBundle.load('assets/images/Quaid Academy logo.png');
      logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());
    } catch (e) {
      debugPrint('Error loading print logo: $e');
    }

    // ── Build page ─────────────────────────────────────────────────────────
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 32, vertical: 36),
        build: (pw.Context context) {
          return pw.Stack(
            children: [
              // ── Watermark (behind content) ───────────────────────────────
              PdfHelpers.buildWatermark(logoImage: logoImage),

              // ── Page content ─────────────────────────────────────────────
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // ── Header ───────────────────────────────────────────────
                  PdfHelpers.buildPdfHeader(
                    logoImage: logoImage,
                    profileAcademyName: academyName,
                    profileAddress: academyAddress,
                    profilePhone: academyPhone,
                  ),
                  pw.SizedBox(height: 14),

                  // ── Section title ─────────────────────────────────────────
                  pw.Center(
                    child: pw.Text(
                      'STUDENT RECORD',
                      style: pw.TextStyle(
                        fontSize: 15,
                        fontWeight: pw.FontWeight.bold,
                        decoration: pw.TextDecoration.underline,
                        color: PdfColors.blueGrey800,
                      ),
                    ),
                  ),
                  pw.SizedBox(height: 20),

                  // ── Photo, basic info, and QR code ────────────────────────
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      // Photo
                      if (profileImage != null)
                        pw.Container(
                          width: 100,
                          height: 100,
                          decoration: pw.BoxDecoration(
                            shape: pw.BoxShape.circle,
                            image: pw.DecorationImage(
                                image: profileImage, fit: pw.BoxFit.cover),
                          ),
                        )
                      else
                        pw.Container(
                          width: 100,
                          height: 100,
                          decoration: const pw.BoxDecoration(
                            shape: pw.BoxShape.circle,
                            color: PdfColors.grey300,
                          ),
                          child: pw.Center(
                            child: pw.Text(
                              student.initials,
                              style: pw.TextStyle(
                                  fontSize: 40,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.grey600),
                            ),
                          ),
                        ),

                      pw.SizedBox(width: 28),

                      // Basic info
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            _buildInfoRow('Student ID', student.studentCode),
                            _buildInfoRow('Student Name', student.name),
                            _buildInfoRow('Father Name', student.fatherName),
                            _buildInfoRow('Phone', student.phone),
                            _buildInfoRow(
                                'Registration Date',
                                DateFormat('MMM dd, yyyy')
                                    .format(student.createdAt)),
                            _buildInfoRow('Class',
                                '${student.classType} - ${student.grade}'),
                            _buildInfoRow('Subject', student.subject),
                          ],
                        ),
                      ),
                      pw.SizedBox(width: 14),

                      // QR code
                      pw.Column(
                        children: [
                          pw.Container(
                            padding: const pw.EdgeInsets.all(6),
                            decoration: pw.BoxDecoration(
                              border: pw.Border.all(
                                  color: PdfColors.grey400, width: 1),
                              borderRadius: const pw.BorderRadius.all(
                                  pw.Radius.circular(6)),
                            ),
                            child: pw.BarcodeWidget(
                              barcode: pw.Barcode.qrCode(),
                              data: qrCodeData,
                              width: 75,
                              height: 75,
                            ),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text(
                            student.studentCode,
                            style: pw.TextStyle(
                                fontSize: 8,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.blue800),
                          ),
                        ],
                      ),
                    ],
                  ),

                  pw.SizedBox(height: 30),

                  // ── Fee Details ───────────────────────────────────────────
                  pw.Text(
                    'Fee Details',
                    style: pw.TextStyle(
                        fontSize: 15,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blueGrey800),
                  ),
                  pw.Divider(),
                  pw.SizedBox(height: 8),

                  _buildInfoRow('Total Fee',
                      'Rs. ${student.totalFee.toStringAsFixed(0)}'),
                  _buildInfoRow('Fee Submitted',
                      'Rs. ${student.feeSubmitted.toStringAsFixed(0)}'),
                  _buildInfoRow('Fee Remaining',
                      'Rs. ${student.feeRemaining.toStringAsFixed(0)}'),

                  pw.SizedBox(height: 8),
                  pw.Row(
                    children: [
                      pw.Text('Status:',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(width: 8),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: pw.BoxDecoration(
                          color: student.isFeeFullyPaid
                              ? PdfColors.green100
                              : PdfColors.red100,
                          borderRadius: const pw.BorderRadius.all(
                              pw.Radius.circular(4)),
                        ),
                        child: pw.Text(
                          student.isFeeFullyPaid ? 'SUBMITTED' : 'PENDING',
                          style: pw.TextStyle(
                            color: student.isFeeFullyPaid
                                ? PdfColors.green800
                                : PdfColors.red800,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),

                  // ── Payment installment history ────────────────────────────
                  ...(() {
                    List<dynamic> history = [];
                    if (student.paymentHistoryJson != null &&
                        student.paymentHistoryJson!.isNotEmpty) {
                      try {
                        history = jsonDecode(student.paymentHistoryJson!);
                      } catch (e) {
                        debugPrint('PDF Print: Error decoding history: $e');
                      }
                    }
                    if (history.isEmpty && student.feeSubmitted > 0) {
                      history = [
                        {
                          'date': student.createdAt.toIso8601String(),
                          'amount': student.feeSubmitted,
                          'note': 'Registration Payment',
                        }
                      ];
                    }
                    if (history.isEmpty) return <pw.Widget>[];

                    return [
                      pw.SizedBox(height: 22),
                      pw.Text(
                        'Payment Installments History',
                        style: pw.TextStyle(
                            fontSize: 13,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.blueGrey800),
                      ),
                      pw.Divider(thickness: 1),
                      pw.SizedBox(height: 4),
                      ...history.map((item) {
                        final dateStr = item['date'] != null
                            ? DateFormat('MMM dd, yyyy')
                                .format(DateTime.parse(item['date']))
                            : 'Unknown Date';
                        final amount = (item['amount'] ?? 0.0).toDouble();
                        final note = item['note'] ?? 'Payment';
                        return pw.Padding(
                          padding:
                              const pw.EdgeInsets.symmetric(vertical: 3),
                          child: pw.Row(
                            mainAxisAlignment:
                                pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Text('$dateStr: $note',
                                  style: const pw.TextStyle(fontSize: 10)),
                              pw.Text(
                                'Rs. ${amount.toStringAsFixed(0)}',
                                style: pw.TextStyle(
                                    fontSize: 10,
                                    fontWeight: pw.FontWeight.bold),
                              ),
                            ],
                          ),
                        );
                      }),
                    ];
                  }()),

                  // ── Spacer + Footer ────────────────────────────────────────
                  pw.Spacer(),
                  PdfHelpers.buildPdfFooter(
                    pageNum: 1,
                    totalPages: 1,
                    now: now,
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    // ── Output ────────────────────────────────────────────────────────────
    if (!kIsWeb && io.Platform.isWindows) {
      try {
        final bytes = await doc.save();
        final tempDir = await getTemporaryDirectory();
        final fileName =
            '${student.name.replaceAll(' ', '_')}_record.pdf';
        final file = io.File('${tempDir.path}\\$fileName');
        await file.writeAsBytes(bytes);
        // Open PDF — try launchUrl first, then cmd, never hang.
        bool opened = false;
        try {
          final uri = Uri.file(file.path);
          opened = await launchUrl(uri)
              .timeout(const Duration(seconds: 6), onTimeout: () => false);
        } catch (_) {}
        if (!opened) {
          try {
            await io.Process.start('cmd', ['/c', 'start', '', file.path]);
          } catch (e) {
            debugPrint('Process.start fallback error: $e');
          }
        }
      } catch (e) {
        debugPrint('Windows print fallback error: $e');
        await Printing.layoutPdf(
          onLayout: (PdfPageFormat format) async => doc.save(),
          name: '${student.name.replaceAll(' ', '_')}_record.pdf',
        );
      }
    } else {
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => doc.save(),
        name: '${student.name.replaceAll(' ', '_')}_record.pdf',
      );
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  static pw.Widget _buildInfoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 120,
            child: pw.Text('$label:',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          ),
          pw.Expanded(
            child: pw.Text(value),
          ),
        ],
      ),
    );
  }
}
