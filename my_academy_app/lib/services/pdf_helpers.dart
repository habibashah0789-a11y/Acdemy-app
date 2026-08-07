import 'dart:math' show pi;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';

/// Shared PDF branding helpers for Quaid Academy print documents.
/// Provides [buildPdfHeader], [buildWatermark], and [buildPdfFooter]
/// so that every printed page has a consistent look.
class PdfHelpers {
  // ─── Academy constants ────────────────────────────────────────────────────

  static const String _academyName = 'QUAID ACADEMY';
  static const String _motto = 'From Here It Is Possible';
  static const String _phone = '03139509505';
  static const String _address =
      'Opposite Islamia College Gate 2, UPS School Street,\n'
      'Railway Tract, University Road, Peshawar';
  static const String _systemName = 'Quaid Academy Management System';

  // ─── Header ───────────────────────────────────────────────────────────────

  /// Builds the branded page header:
  ///   [Logo 65 px]   QUAID ACADEMY (bold, large)
  ///                  "From Here It Is Possible" (italic)
  ///                  [optional sub-text from academy profile]
  static pw.Widget buildPdfHeader({
    required pw.MemoryImage? logoImage,
    String? profileAcademyName,
    String? profileAddress,
    String? profilePhone,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            // Logo — top-left, 65 px wide, aspect ratio preserved
            if (logoImage != null) ...[
              pw.Container(
                width: 65,
                height: 65,
                child: pw.Image(logoImage, fit: pw.BoxFit.contain),
              ),
              pw.SizedBox(width: 14),
            ],

            // Academy name + motto
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    profileAcademyName?.isNotEmpty == true
                        ? profileAcademyName!.toUpperCase()
                        : _academyName,
                    style: pw.TextStyle(
                      fontSize: 22,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blueGrey900,
                    ),
                  ),
                  pw.Text(
                    '"$_motto"',
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontStyle: pw.FontStyle.italic,
                      color: PdfColors.blueGrey600,
                    ),
                  ),
                  if (profileAddress != null && profileAddress.isNotEmpty)
                    pw.Text(
                      profileAddress,
                      style: const pw.TextStyle(
                          fontSize: 9, color: PdfColors.grey700),
                    ),
                  if (profilePhone != null && profilePhone.isNotEmpty)
                    pw.Text(
                      'Phone: $profilePhone',
                      style: const pw.TextStyle(
                          fontSize: 9, color: PdfColors.grey700),
                    ),
                ],
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 8),
        // Decorative double rule
        pw.Container(
          height: 2,
          color: PdfColors.blueGrey800,
        ),
        pw.SizedBox(height: 2),
        pw.Container(
          height: 0.5,
          color: PdfColors.blueGrey400,
        ),
      ],
    );
  }

  // ─── Watermark ────────────────────────────────────────────────────────────

  /// Returns a 45°-rotated, semi-transparent watermark.
  /// Uses the academy logo when available; falls back to text.
  static pw.Widget buildWatermark({pw.MemoryImage? logoImage}) {
    return pw.Center(
      child: pw.Opacity(
        opacity: 0.07,
        child: pw.Transform.rotate(
          angle: -45 * pi / 180,
          child: logoImage != null
              ? pw.Image(logoImage, width: 340, height: 340)
              : pw.Text(
                  'QUAID ACADEMY',
                  style: pw.TextStyle(
                    fontSize: 60,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blueGrey300,
                  ),
                ),
        ),
      ),
    );
  }

  // ─── Footer ───────────────────────────────────────────────────────────────

  /// Builds a 3-line centred footer with branding, timestamp, page info,
  /// address, and phone number.
  static pw.Widget buildPdfFooter({
    required int pageNum,
    required int totalPages,
    required DateTime now,
  }) {
    final dateStr = DateFormat('dd/MM/yyyy').format(now);
    final timeStr = DateFormat('HH:mm').format(now);

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Container(height: 0.5, color: PdfColors.grey500),
        pw.SizedBox(height: 5),

        // Line 1 — system name
        pw.Center(
          child: pw.Text(
            'Generated by $_systemName',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
          ),
        ),
        pw.SizedBox(height: 2),

        // Line 2 — address + phone
        pw.Center(
          child: pw.Text(
            '$_address  |  $_phone',
            style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600),
            textAlign: pw.TextAlign.center,
          ),
        ),
        pw.SizedBox(height: 2),

        // Line 3 — timestamp | page
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.center,
          children: [
            pw.Text(
              'Printed on: $dateStr $timeStr',
              style:
                  const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
            ),
            pw.SizedBox(width: 24),
            pw.Text(
              'Page $pageNum of $totalPages',
              style: pw.TextStyle(
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.grey700),
            ),
          ],
        ),
      ],
    );
  }
}
