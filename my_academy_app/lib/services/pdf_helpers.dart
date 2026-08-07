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

  // ─── Brand colours ────────────────────────────────────────────────────────
  static final PdfColor _navyBlue  = PdfColor.fromHex('#1A2472');
  static final PdfColor _gold      = PdfColor.fromHex('#E8A820');
  static final PdfColor _goldLight = PdfColor.fromHex('#F5C842');

  // ─── Header ───────────────────────────────────────────────────────────────

  /// Branded page header matching the academy's physical logo style:
  ///   ┌─────────────────────────────────────────────────────────┐
  ///   │  [Logo]  From here It's Possible  │  Quaid             │  ← navy blue
  ///   │                                    │  Academy           │
  ///   │          ─────────────────────────────────────────────  │
  ///   │                  University Road Peshawar               │
  ///   └─────────────────────────────────────────────────────────┘
  static pw.Widget buildPdfHeader({
    required pw.MemoryImage? logoImage,
    String? profileAcademyName,
    String? profileAddress,
    String? profilePhone,
  }) {
    // Resolve display values
    final displayName = (profileAcademyName?.isNotEmpty == true)
        ? profileAcademyName!
        : 'Quaid Academy';
    // Split name into two parts if it contains a space (e.g. "Quaid Academy")
    final nameParts  = displayName.split(' ');
    final nameLine1  = nameParts.isNotEmpty ? nameParts.first : displayName;
    final nameLine2  = nameParts.length > 1
        ? nameParts.sublist(1).join(' ')
        : '';

    final displayAddress = (profileAddress?.isNotEmpty == true)
        ? profileAddress!
        : 'University Road Peshawar';
    final displayPhone = profilePhone?.isNotEmpty == true
        ? '  |  ${profilePhone!}'
        : '';

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // ── Main navy banner ─────────────────────────────────────────────────
        pw.Container(
          decoration: pw.BoxDecoration(color: _navyBlue),
          padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              // ── Logo section ───────────────────────────────────────────────
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                mainAxisAlignment: pw.MainAxisAlignment.center,
                children: [
                  if (logoImage != null)
                    pw.Container(
                      width: 58,
                      height: 58,
                      child: pw.Image(logoImage, fit: pw.BoxFit.contain),
                    )
                  else
                    pw.Container(
                      width: 58,
                      height: 58,
                      alignment: pw.Alignment.center,
                      child: pw.Text(
                        'QA',
                        style: pw.TextStyle(
                          fontSize: 28,
                          fontWeight: pw.FontWeight.bold,
                          color: _gold,
                        ),
                      ),
                    ),
                  pw.SizedBox(height: 5),
                  // Motto below logo
                  pw.Text(
                    'From here It\'s Possible',
                    style: pw.TextStyle(
                      fontSize: 7,
                      fontStyle: pw.FontStyle.italic,
                      color: _goldLight,
                    ),
                  ),
                ],
              ),

              pw.SizedBox(width: 14),

              // ── Vertical gold divider ──────────────────────────────────────
              pw.Container(
                width: 1.5,
                height: 72,
                color: _gold,
              ),

              pw.SizedBox(width: 14),

              // ── Academy name ───────────────────────────────────────────────
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  mainAxisAlignment: pw.MainAxisAlignment.center,
                  children: [
                    pw.Text(
                      nameLine1,
                      style: pw.TextStyle(
                        fontSize: 30,
                        fontWeight: pw.FontWeight.bold,
                        color: _gold,
                      ),
                    ),
                    if (nameLine2.isNotEmpty)
                      pw.Text(
                        nameLine2,
                        style: pw.TextStyle(
                          fontSize: 22,
                          fontWeight: pw.FontWeight.bold,
                          color: _goldLight,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // ── Thin gold separator line ──────────────────────────────────────────
        pw.Container(height: 1.5, color: _gold),

        // ── Address strip ─────────────────────────────────────────────────────
        pw.Container(
          width: double.infinity,
          color: _navyBlue,
          padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 14),
          child: pw.Center(
            child: pw.Text(
              '$displayAddress$displayPhone',
              style: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
              ),
              textAlign: pw.TextAlign.center,
            ),
          ),
        ),

        // ── Bottom gold rule ──────────────────────────────────────────────────
        pw.Container(height: 2, color: _gold),
        pw.SizedBox(height: 10),
      ],
    );
  }


  // ─── Watermark ────────────────────────────────────────────────────────────

  /// Returns a straight, semi-transparent watermark centred on the page.
  /// Uses the academy logo when available; falls back to text.
  static pw.Widget buildWatermark({pw.MemoryImage? logoImage}) {
    return pw.Center(
      child: pw.Opacity(
        opacity: 0.08,
        child: logoImage != null
            ? pw.Image(logoImage, width: 300, height: 300)
            : pw.Text(
                'QUAID ACADEMY',
                style: pw.TextStyle(
                  fontSize: 60,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blueGrey300,
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
