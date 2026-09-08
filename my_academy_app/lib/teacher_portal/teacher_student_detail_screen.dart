import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../models/student_model.dart';
import '../models/teacher_model.dart';
import '../widgets/student_avatar.dart';
import '../theme/app_theme.dart';

class TeacherStudentDetailScreen extends StatelessWidget {
  final StudentModel student;
  final TeacherModel teacher;

  const TeacherStudentDetailScreen({
    super.key,
    required this.student,
    required this.teacher,
  });

  Color get _subjectColor {
    switch (teacher.subject.toLowerCase()) {
      case 'biology': return const Color(0xFF059669);
      case 'physics': return const Color(0xFF2563EB);
      case 'chemistry': return const Color(0xFFD97706);
      case 'mathematics': case 'math': return const Color(0xFF0891B2);
      case 'english': return const Color(0xFF7C3AED);
      default: return AppTheme.primaryBlue;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currencyFmt = NumberFormat('#,##0', 'en_US');
    final dateFmt = DateFormat('dd MMM yyyy');

    final subjectTotalFee = student.getSubjectTotalFee(teacher.subject);
    final subjectPaid = student.getSubjectPaid(teacher.subject);
    final subjectRemaining = student.getSubjectRemaining(teacher.subject);
    final isPaid = student.isSubjectPaid(teacher.subject);
    final payPercent = subjectTotalFee > 0
        ? (subjectPaid / subjectTotalFee).clamp(0.0, 1.0)
        : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          student.name,
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'READ ONLY',
              style: GoogleFonts.poppins(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Profile Header ──
            _buildProfileHeader(context, isDark),
            const SizedBox(height: 20),

            // ── Personal Info ──
            _buildInfoCard(
              context,
              isDark,
              title: 'Personal Information',
              icon: Icons.person_rounded,
              color: _subjectColor,
              rows: [
                _InfoRow('Full Name', student.name),
                _InfoRow('Father\'s Name', student.fatherName),
                _InfoRow('Student ID', student.studentCode),
                _InfoRow('Phone', student.phone),
                _InfoRow('Email', student.email.isEmpty ? '—' : student.email),
              ],
            ),
            const SizedBox(height: 16),

            // ── Academic Info ──
            _buildInfoCard(
              context,
              isDark,
              title: 'Academic Information',
              icon: Icons.school_rounded,
              color: _subjectColor,
              rows: [
                _InfoRow('Section', student.classType),
                _InfoRow('Class', student.grade),
                _InfoRow('Subjects', student.subject),
                _InfoRow('Status', student.enrollmentStatusText),
                _InfoRow('Registered', dateFmt.format(student.createdAt)),
              ],
            ),
            const SizedBox(height: 16),

            // ── Subject Fee Card ──
            _buildSubjectFeeCard(
              context,
              isDark,
              currencyFmt,
              subjectTotalFee,
              subjectPaid,
              subjectRemaining,
              isPaid,
              payPercent,
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primaryDarkBlue, _subjectColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _subjectColor.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          // Avatar
          StudentAvatar(
            student: student,
            size: 72,
            isCircle: true,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  student.name,
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  student.studentCode,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 12,
                    fontFamily: 'monospace',
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _badgeWidget(student.classType),
                    const SizedBox(width: 6),
                    _badgeWidget(student.grade),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.06);
  }

  Widget _buildInitialsWidget() {
    final initials = student.name.isNotEmpty
        ? student.name
            .split(' ')
            .take(2)
            .map((w) => w.isNotEmpty ? w[0].toUpperCase() : '')
            .join()
        : 'S';
    return Text(
      initials,
      style: const TextStyle(
        fontSize: 26,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
    );
  }

  Widget _badgeWidget(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: Colors.white.withValues(alpha: 0.9),
        ),
      ),
    );
  }

  Widget _buildInfoCard(
    BuildContext context,
    bool isDark, {
    required String title,
    required IconData icon,
    required Color color,
    required List<_InfoRow> rows,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 8),
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          ...rows.map((row) => _buildRowItem(row.label, row.value)),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.04);
  }

  Widget _buildRowItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: AppTheme.lightTextSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '—' : value,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubjectFeeCard(
    BuildContext context,
    bool isDark,
    NumberFormat fmt,
    double total,
    double paid,
    double remaining,
    bool isPaid,
    double payPercent,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _subjectColor.withValues(alpha: 0.25),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: _subjectColor.withValues(alpha: 0.07),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.payments_rounded, color: _subjectColor, size: 18),
              const SizedBox(width: 8),
              Text(
                '${teacher.subject} Fee',
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: _subjectColor,
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isPaid
                      ? Colors.green.withValues(alpha: 0.1)
                      : Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isPaid ? 'PAID' : 'PENDING',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isPaid ? Colors.green : Colors.red,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Progress Bar
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: payPercent,
                    backgroundColor: Colors.grey.shade200,
                    color: isPaid ? Colors.green : _subjectColor,
                    minHeight: 8,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${(payPercent * 100).toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isPaid ? Colors.green : _subjectColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Fee rows
          _feeRow('Total Fee', 'Rs ${fmt.format(total)}', _subjectColor),
          _feeRow('Amount Paid', 'Rs ${fmt.format(paid)}', Colors.green),
          _feeRow(
            'Remaining',
            'Rs ${fmt.format(remaining)}',
            remaining > 0 ? Colors.red : Colors.green,
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.06);
  }

  Widget _feeRow(String label, String value, Color valueColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: AppTheme.lightTextSecondary,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow {
  final String label;
  final String value;
  const _InfoRow(this.label, this.value);
}
