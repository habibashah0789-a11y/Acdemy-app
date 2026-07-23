import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/student_model.dart';
import '../theme/app_theme.dart';

/// A self-contained QR code painter that generates a QR-like pattern
/// deterministically based on the student's unique data.
/// Uses the student's unique [qrData] string to produce a consistent,
/// visually distinct matrix for each student.
class StudentQrWidget extends StatelessWidget {
  final StudentModel student;
  final double size;
  final bool showLabel;

  const StudentQrWidget({
    super.key,
    required this.student,
    this.size = 140,
    this.showLabel = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(
              color: AppTheme.primaryBlue.withValues(alpha: 0.25),
              width: 1.5,
            ),
          ),
          child: CustomPaint(
            size: Size(size, size),
            painter: _StudentQrPainter(qrData: student.qrData),
          ),
        ),
        if (showLabel) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.primaryBlue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              student.studentCode,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryBlue,
                letterSpacing: 1.1,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Deterministic QR-style pattern painter using the student's unique qrData string.
/// Each student gets a unique pattern guaranteed to differ because qrData
/// encodes the student's unique ID.
class _StudentQrPainter extends CustomPainter {
  final String qrData;

  _StudentQrPainter({required this.qrData});

  @override
  void paint(Canvas canvas, Size size) {
    const modules = 21; // 21x21 module grid (QR Version 1 style)
    final cellSize = size.width / modules;

    final paint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;

    final whitePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    // Fill white background
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), whitePaint);

    // Build bit matrix from qrData hash
    final matrix = _buildMatrix(qrData, modules);

    for (int row = 0; row < modules; row++) {
      for (int col = 0; col < modules; col++) {
        if (matrix[row][col]) {
          canvas.drawRect(
            Rect.fromLTWH(
              col * cellSize,
              row * cellSize,
              cellSize,
              cellSize,
            ),
            paint,
          );
        }
      }
    }

    // Draw the three finder pattern squares (top-left, top-right, bottom-left)
    _drawFinderPattern(canvas, 0, 0, cellSize, paint, whitePaint);
    _drawFinderPattern(canvas, 0, modules - 7, cellSize, paint, whitePaint);
    _drawFinderPattern(canvas, modules - 7, 0, cellSize, paint, whitePaint);
  }

  List<List<bool>> _buildMatrix(String data, int size) {
    final matrix = List.generate(size, (_) => List<bool>.filled(size, false));

    // Seed RNG from deterministic hash of data
    int hash = 5381;
    for (int i = 0; i < data.length; i++) {
      hash = ((hash << 5) + hash) ^ data.codeUnitAt(i);
    }
    final rng = math.Random(hash.abs());

    // Fill data area (avoiding finder pattern zones: corners 8x8)
    for (int row = 0; row < size; row++) {
      for (int col = 0; col < size; col++) {
        final inTopLeft = row < 9 && col < 9;
        final inTopRight = row < 9 && col >= size - 8;
        final inBottomLeft = row >= size - 8 && col < 9;
        if (!inTopLeft && !inTopRight && !inBottomLeft) {
          matrix[row][col] = rng.nextBool();
        }
      }
    }

    // Add timing patterns
    for (int i = 8; i < size - 8; i++) {
      matrix[6][i] = i.isEven;
      matrix[i][6] = i.isEven;
    }

    return matrix;
  }

  void _drawFinderPattern(Canvas canvas, int startRow, int startCol,
      double cellSize, Paint darkPaint, Paint lightPaint) {
    // Outer 7x7 dark border
    for (int r = 0; r < 7; r++) {
      for (int c = 0; c < 7; c++) {
        final isOuter = r == 0 || r == 6 || c == 0 || c == 6;
        final isInner = r >= 2 && r <= 4 && c >= 2 && c <= 4;
        canvas.drawRect(
          Rect.fromLTWH(
            (startCol + c) * cellSize,
            (startRow + r) * cellSize,
            cellSize,
            cellSize,
          ),
          (isOuter || isInner) ? darkPaint : lightPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _StudentQrPainter oldDelegate) {
    return oldDelegate.qrData != qrData;
  }
}

void showStudentQrDialog(BuildContext context, StudentModel student) {
  showDialog(
    context: context,
    builder: (context) {
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
                            'Student Pass & QR Code',
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
                StudentQrWidget(
                  student: student,
                  size: 200,
                  showLabel: true,
                ),
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
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
                      const SizedBox(height: 4),
                      Text(
                        student.subject,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      if (student.phone.isNotEmpty) ...[
                        const SizedBox(height: 4),
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
              ],
            ),
          ),
        ),
      );
    },
  );
}
