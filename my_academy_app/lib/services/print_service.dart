import 'package:flutter/material.dart';    //line #114 about  width: 120 is commented out in the code 
import 'package:intl/intl.dart';           // beacause it is showing somw error
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

class PrintService {
  static Future<void> printStudentReport(StudentModel student) async {
    final doc = pw.Document();

    final profile = DatabaseService.getAcademyProfile();
    final academyName = profile['name']?.toString().isNotEmpty == true 
        ? profile['name'].toString() 
        : 'Quaid Academy';
    final academyAddress = profile['address']?.toString() ?? '';
    final academyPhone = profile['phone']?.toString() ?? '';

    // Load image if available (supports Network, Base64, and Local Files)
    pw.ImageProvider? profileImage;
    if (student.profilePicUrl.isNotEmpty) {
      try {
        final url = student.profilePicUrl;
        if (url.startsWith('http://') || url.startsWith('https://')) {
          profileImage = await networkImage(url);
        } else if (url.startsWith('data:image') || (!url.contains('/') && !url.contains('\\') && url.length > 100)) {
          final base64Str = url.contains(',') ? url.split(',').last : url;
          final bytes = base64Decode(base64Str.trim());
          profileImage = pw.MemoryImage(bytes);
        } else if (url.startsWith('blob:')) {
          // Web blob URL (usually falls back if not cached, but can try loading if network allows)
        } else if (!kIsWeb) {
          final file = io.File(url);
          if (await file.exists()) {
            final bytes = await file.readAsBytes();
            profileImage = pw.MemoryImage(bytes);
          }
        }
      } catch (e) { 
        debugPrint('Error loading profile image for PDF: $e');
      }
    }

    // Load logo image from assets
    pw.MemoryImage? logoImage;
    try {
      final logoBytes = await rootBundle.load('assets/images/Quaid Academy logo.png');
      logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());
    } catch (e) {
      debugPrint('Error loading print logo: $e');
    }

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Stack(
            children: [
              if (logoImage != null)
                pw.Align(
                  alignment: pw.Alignment.center,
                  child: pw.Opacity(
                    opacity: 0.08,
                    child: pw.Image(logoImage, width: 350, height: 350),
                  ),
                ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Header with details on the left and logo on top right
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(academyName, style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
                            if (academyAddress.isNotEmpty)
                              pw.Text(academyAddress, style: const pw.TextStyle(fontSize: 11)),
                            if (academyPhone.isNotEmpty)
                              pw.Text('Phone: $academyPhone', style: const pw.TextStyle(fontSize: 11)),
                          ],
                        ),
                      ),
                      if (logoImage != null) ...[
                        pw.SizedBox(width: 16),
                        pw.Container(
                          width: 60,
                          height: 60,
                          child: pw.Image(logoImage),
                        ),
                      ],
                    ],
                  ),
                  pw.SizedBox(height: 15),
                  pw.Divider(thickness: 1.5),
                  pw.SizedBox(height: 15),
                  pw.Center(
                    child: pw.Text('STUDENT RECORD', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, decoration: pw.TextDecoration.underline)),
                  ),
                  pw.SizedBox(height: 25),
                  
                  // Profile Photo and Info
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
                            image: pw.DecorationImage(image: profileImage, fit: pw.BoxFit.cover),
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
                            child: pw.Text(student.initials, style: pw.TextStyle(fontSize: 40, fontWeight: pw.FontWeight.bold, color: PdfColors.grey600)),
                          ),
                        ),
                      
                      pw.SizedBox(width: 30),
                      
                      // Basic Info
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            _buildInfoRow('Student ID', student.studentCode),
                            _buildInfoRow('Student Name', student.name),
                            _buildInfoRow('Father Name', student.fatherName),
                            _buildInfoRow('Phone', student.phone),
                            _buildInfoRow('Registration Date', DateFormat('MMM dd, yyyy').format(student.createdAt)),
                            _buildInfoRow('Class', '${student.classType} - ${student.grade}'),
                            _buildInfoRow('Subject', student.subject),
                          ],
                        ),
                      ),
                      pw.SizedBox(width: 15),

                      // Unique QR Code Container
                      pw.Column(
                        children: [
                          pw.Container(
                            padding: const pw.EdgeInsets.all(6),
                            decoration: pw.BoxDecoration(
                              border: pw.Border.all(color: PdfColors.grey400, width: 1),
                              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                            ),
                            child: pw.BarcodeWidget(
                              barcode: pw.Barcode.qrCode(),
                              data: student.qrData,
                              width: 75,
                              height: 75,
                            ),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text(
                            student.studentCode,
                            style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800),
                          ),
                        ],
                      ),
                    ],
                  ),
                  
                  pw.SizedBox(height: 40),
                  
                  // Fee Details
                  pw.Text('Fee Details', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                  pw.Divider(),
                  pw.SizedBox(height: 10),
                  
                  _buildInfoRow('Total Fee', 'Rs. ${student.totalFee.toStringAsFixed(0)}'),
                  _buildInfoRow('Fee Submitted', 'Rs. ${student.feeSubmitted.toStringAsFixed(0)}'),
                  _buildInfoRow('Fee Remaining', 'Rs. ${student.feeRemaining.toStringAsFixed(0)}'),
                  
                  pw.SizedBox(height: 10),
                  pw.Row(
                    children: [
                      pw.Text('Status:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(width: 8),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: pw.BoxDecoration(
                          color: student.isFeeFullyPaid ? PdfColors.green100 : PdfColors.red100,
                          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                        ),
                        child: pw.Text(
                          student.isFeeFullyPaid ? 'SUBMITTED' : 'PENDING',
                          style: pw.TextStyle(
                            color: student.isFeeFullyPaid ? PdfColors.green800 : PdfColors.red800,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  ...(() {
                    List<dynamic> history = [];
                    if (student.paymentHistoryJson != null && student.paymentHistoryJson!.isNotEmpty) {
                      try {
                        history = jsonDecode(student.paymentHistoryJson!);
                      } catch (e) {
                        debugPrint('PDF Print: Error decoding history: $e');
                      }
                    }
                    if (history.isEmpty && student.feeSubmitted > 0) {
                      history = [{
                        'date': student.createdAt.toIso8601String(),
                        'amount': student.feeSubmitted,
                        'note': 'Registration Payment'
                      }];
                    }
                    if (history.isEmpty) return <pw.Widget>[];

                    return [
                      pw.SizedBox(height: 25),
                      pw.Text('Payment Installments History', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
                      pw.Divider(thickness: 1),
                      pw.SizedBox(height: 5),
                      ...history.map((item) {
                        final dateStr = item['date'] != null
                            ? DateFormat('MMM dd, yyyy').format(DateTime.parse(item['date']))
                            : 'Unknown Date';
                        final amount = (item['amount'] ?? 0.0).toDouble();
                        final note = item['note'] ?? 'Payment';
                        return pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(vertical: 3),
                          child: pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Text('$dateStr: $note', style: const pw.TextStyle(fontSize: 10)),
                              pw.Text('Rs. ${amount.toStringAsFixed(0)}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                            ],
                          ),
                        );
                      }),
                    ];
                  }()),
                  
                  pw.SizedBox(height: 20),
                  
                  // Footer
                  pw.Divider(),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Printed on: ${DateFormat('MMM dd, yyyy').format(DateTime.now())}', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                      pw.Text('Time: ${DateFormat('hh:mm a').format(DateTime.now())}', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                    ],
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    if (!kIsWeb && io.Platform.isWindows) {
      try {
        final bytes = await doc.save();
        final tempDir = await getTemporaryDirectory();
        final fileName = '${student.name.replaceAll(' ', '_')}_record.pdf';
        final file = io.File('${tempDir.path}\\$fileName');
        await file.writeAsBytes(bytes);
        
        try {
          final uri = Uri.file(file.path);
          await launchUrl(uri);
        } catch (e) {
          await io.Process.start('cmd', ['/c', 'start', '', file.path]);
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

  static pw.Widget _buildInfoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 120,
            child: pw.Text('$label:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          ),
          pw.Expanded(
            child: pw.Text(value),
          ),
        ],
      ),
    );
  }
}
