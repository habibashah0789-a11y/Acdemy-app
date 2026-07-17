import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../models/student_model.dart';
import 'database_service.dart';

class FeeDefaultersPrintService {
  static Future<void> printDefaultersList(List<StudentModel> defaulters) async {
    final doc = pw.Document();

    final profile = DatabaseService.getAcademyProfile();
    final academyName = profile['name']?.toString().isNotEmpty == true
        ? profile['name'].toString()
        : 'Quaid Academy';
    final academyAddress = profile['address']?.toString() ?? '';
    final academyPhone = profile['phone']?.toString() ?? '';

    // Load logo image from assets
    pw.MemoryImage? logoImage;
    try {
      final logoBytes = await rootBundle.load('assets/images/Quaid Academy logo.png');
      logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());
    } catch (e) {
      debugPrint('Error loading print logo: $e');
    }

    // Split defaulters into pages of ~18 students each
    const int studentsPerPage = 18;
    final int totalPages = (defaulters.length / studentsPerPage).ceil();

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
                // Watermark logo
                if (logoImage != null)
                  pw.Align(
                    alignment: pw.Alignment.center,
                    child: pw.Opacity(
                      opacity: 0.06,
                      child: pw.Image(logoImage, width: 350, height: 350),
                    ),
                  ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    // Header
                    pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.Expanded(
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(academyName,
                                  style: pw.TextStyle(
                                      fontSize: 20,
                                      fontWeight: pw.FontWeight.bold)),
                              if (academyAddress.isNotEmpty)
                                pw.Text(academyAddress,
                                    style: const pw.TextStyle(fontSize: 10)),
                              if (academyPhone.isNotEmpty)
                                pw.Text('Phone: $academyPhone',
                                    style: const pw.TextStyle(fontSize: 10)),
                            ],
                          ),
                        ),
                        if (logoImage != null) ...[
                          pw.SizedBox(width: 16),
                          pw.Container(
                            width: 50,
                            height: 50,
                            child: pw.Image(logoImage),
                          ),
                        ],
                      ],
                    ),
                    pw.SizedBox(height: 10),
                    pw.Divider(thickness: 1.5),
                    pw.SizedBox(height: 8),

                    // Title
                    pw.Center(
                      child: pw.Text('FEE DEFAULTERS LIST',
                          style: pw.TextStyle(
                              fontSize: 15,
                              fontWeight: pw.FontWeight.bold,
                              decoration: pw.TextDecoration.underline)),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Center(
                      child: pw.Text(
                        'Generated on: ${DateFormat('MMM dd, yyyy  hh:mm a').format(DateTime.now())}',
                        style: const pw.TextStyle(
                            fontSize: 9, color: PdfColors.grey700),
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          'Total Defaulters: ${defaulters.length}',
                          style: pw.TextStyle(
                              fontSize: 10, fontWeight: pw.FontWeight.bold),
                        ),
                        pw.Text(
                          'Total Pending: Rs. ${defaulters.fold<double>(0, (total, s) => total + s.feeRemaining).toStringAsFixed(0)}',
                          style: pw.TextStyle(
                              fontSize: 10,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.red800),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 10),

                    // Table
                    pw.TableHelper.fromTextArray(
                      border: pw.TableBorder.all(
                          color: PdfColors.grey400, width: 0.5),
                      headerStyle: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 9,
                          color: PdfColors.white),
                      headerDecoration:
                          const pw.BoxDecoration(color: PdfColors.blueGrey800),
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
                        'Remaining'
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

                    pw.SizedBox(height: 15),

                    // Footer
                    pw.Divider(),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          'Page ${page + 1} of $totalPages',
                          style: const pw.TextStyle(
                              fontSize: 9, color: PdfColors.grey600),
                        ),
                        pw.Text(
                          'Printed: ${DateFormat('MMM dd, yyyy').format(DateTime.now())}',
                          style: const pw.TextStyle(
                              fontSize: 9, color: PdfColors.grey600),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      );
    }

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
      name: 'fee_defaulters_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf',
    );
  }
}
