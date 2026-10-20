import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
// ignore: avoid_web_libraries_in_flutter
import 'dart:io' if (dart.library.html) 'package:my_academy_app/utils/io_stub.dart' as io;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/student_model.dart';
import 'database_service.dart';
import 'pdf_helpers.dart';
import 'audit_log_service.dart';

class FeeDefaultersPrintService {
  static Future<void> printDefaultersList(
      List<StudentModel> defaulters) async {
    try {
      await AuditLogService.logAction(
        actorId: 'ADMIN',
        actorName: 'Administrator',
        actorRole: 'ADMIN',
        action: 'FEE_DEFAULTERS_EXPORTED',
        transactionId: 'DEFAULTERS_LIST',
        details: 'Exported fee defaulters list containing ${defaulters.length} students.',
      );
    } catch (_) {}
    final doc = pw.Document();
    final now = DateTime.now();

    final profile = DatabaseService.getAcademyProfile();
    final academyName =
        profile['name']?.toString().isNotEmpty == true
            ? profile['name'].toString()
            : 'Quaid Academy';
    final academyAddress = profile['address']?.toString() ?? '';
    final academyPhone = profile['phone']?.toString() ?? '';

    // ── Load academy logo for header & centered watermark ───────────────────
    final logoImage = await PdfHelpers.loadLogoImage();

    // ── Pagination: ~18 students per page ─────────────────────────────────
    const int studentsPerPage = 18;
    final int totalPages =
        (defaulters.length / studentsPerPage).ceil().clamp(1, 9999);

    final double totalPending = defaulters.fold<double>(
        0, (total, s) => total + s.feeRemaining);

    for (int page = 0; page < totalPages; page++) {
      final start = page * studentsPerPage;
      final end = (start + studentsPerPage > defaulters.length)
          ? defaulters.length
          : start + studentsPerPage;
      final pageStudents = defaulters.sublist(start, end);

      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(30),
          build: (pw.Context context) {
            return pw.Stack(
              children: [
                // ── Watermark ──────────────────────────────────────────
                PdfHelpers.buildWatermark(logoImage: logoImage),

                // ── Page content ─────────────────────────────────────────────
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    // ── Header ─────────────────────────────────────────────
                    PdfHelpers.buildPdfHeader(
                      logoImage: logoImage,
                      profileAcademyName: academyName,
                      profileAddress: academyAddress,
                      profilePhone: academyPhone,
                    ),
                    pw.SizedBox(height: 10),

                    // ── Report title ────────────────────────────────────────
                    pw.Center(
                      child: pw.Text(
                        'FEE DEFAULTERS LIST',
                        style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                          decoration: pw.TextDecoration.underline,
                          color: PdfColors.blueGrey800,
                        ),
                      ),
                    ),
                    pw.SizedBox(height: 6),

                    // ── Summary row ─────────────────────────────────────────
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          'Total Defaulters: ${defaulters.length}',
                          style: pw.TextStyle(
                              fontSize: 10,
                              fontWeight: pw.FontWeight.bold),
                        ),
                        pw.Text(
                          'Total Pending: Rs. ${totalPending.toStringAsFixed(0)}',
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.red800,
                          ),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 10),

                    // ── Defaulters table ────────────────────────────────────
                    pw.TableHelper.fromTextArray(
                      border: pw.TableBorder.all(
                          color: PdfColors.grey400, width: 0.5),
                      headerStyle: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 9,
                        color: PdfColors.white,
                      ),
                      headerDecoration: const pw.BoxDecoration(
                          color: PdfColors.blueGrey800),
                      cellStyle: const pw.TextStyle(fontSize: 8),
                      cellAlignments: {
                        0: pw.Alignment.center,
                        1: pw.Alignment.centerLeft,
                        2: pw.Alignment.centerLeft,
                        3: pw.Alignment.centerLeft,
                        4: pw.Alignment.center,
                        5: pw.Alignment.centerRight,
                        6: pw.Alignment.centerRight,
                      },
                      columnWidths: {
                        0: const pw.FixedColumnWidth(25),
                        1: const pw.FlexColumnWidth(2.5),
                        2: const pw.FlexColumnWidth(2.5),
                        3: const pw.FlexColumnWidth(2),
                        4: const pw.FlexColumnWidth(2),
                        5: const pw.FlexColumnWidth(1.5),
                        6: const pw.FlexColumnWidth(1.5),
                      },
                      cellPadding: const pw.EdgeInsets.symmetric(
                          horizontal: 4, vertical: 4),
                      headers: [
                        '#',
                        'Student Name',
                        'Father Name',
                        'Phone',
                        'Class',
                        'Paid',
                        'Remaining',
                      ],
                      data: List.generate(pageStudents.length, (i) {
                        final s = pageStudents[i];
                        return [
                          '${start + i + 1}',
                          s.name,
                          s.fatherName,
                          s.phone,
                          '${s.classType} ${s.grade}',
                          'Rs.${s.feeSubmitted.toStringAsFixed(0)}',
                          'Rs.${s.feeRemaining.toStringAsFixed(0)}',
                        ];
                      }),
                    ),

                    // ── Spacer + Footer ─────────────────────────────────────
                    pw.Spacer(),
                    PdfHelpers.buildPdfFooter(
                      pageNum: page + 1,
                      totalPages: totalPages,
                      now: now,
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      );
    }

    // ── Output ────────────────────────────────────────────────────────────
    if (!kIsWeb && io.Platform.isWindows) {
      try {
        final bytes = await doc.save();
        final tempDir = await getTemporaryDirectory();
        final fileName =
            'fee_defaulters_${DateFormat('yyyyMMdd').format(now)}.pdf';
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
          name:
              'fee_defaulters_${DateFormat('yyyyMMdd').format(now)}.pdf',
        );
      }
    } else {
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => doc.save(),
        name:
            'fee_defaulters_${DateFormat('yyyyMMdd').format(now)}.pdf',
      );
    }
  }
}
