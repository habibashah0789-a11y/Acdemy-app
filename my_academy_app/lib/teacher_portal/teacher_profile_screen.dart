import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/teacher_model.dart';
import '../theme/app_theme.dart';
import '../screens/role_selection_screen.dart';

class TeacherProfileScreen extends StatelessWidget {
  final TeacherModel teacher;
  const TeacherProfileScreen({super.key, required this.teacher});

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

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'My Profile',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const SizedBox(height: 8),

            // ── Profile Header ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
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
              child: Column(
                children: [
                  _buildAvatar(80),
                  const SizedBox(height: 16),
                  Text(
                    teacher.name,
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    teacher.tagLine,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      teacher.teacherId,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.06),

            const SizedBox(height: 20),

            // ── Info Card ──
            _buildInfoCard(isDark),
            const SizedBox(height: 20),

            // ── Assigned Classes ──
            _buildClassesCard(isDark),
            const SizedBox(height: 32),

            // ── Logout ──
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _confirmLogout(context),
                icon: const Icon(Icons.logout_rounded),
                label: Text(
                  'LOG OUT',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.warningRed,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ).animate().fadeIn(delay: 400.ms),

            const SizedBox(height: 32),

            Text(
              '© 2026 Quaid Academy Pro Management',
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: AppTheme.lightTextSecondary,
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(bool isDark) {
    final rows = [
      _Row(Icons.email_rounded, 'Email', teacher.email),
      _Row(Icons.auto_stories_rounded, 'Subject', teacher.subject),
      _Row(Icons.school_rounded, 'Section', teacher.section),
      _Row(
        teacher.isActive ? Icons.verified_rounded : Icons.block_rounded,
        'Status',
        teacher.isActive ? 'Active' : 'Inactive',
        valueColor: teacher.isActive ? AppTheme.secondaryGreen : AppTheme.warningRed,
      ),
      _Row(Icons.calendar_today_rounded, 'Joined',
          '${teacher.createdAt.day}/${teacher.createdAt.month}/${teacher.createdAt.year}'),
    ];

    return Container(
      padding: const EdgeInsets.all(20),
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
              Icon(Icons.badge_rounded, color: _subjectColor, size: 18),
              const SizedBox(width: 8),
              Text(
                'Account Details',
                style: GoogleFonts.poppins(
                    fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const Divider(height: 20),
          ...rows.map((r) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Icon(r.icon, size: 16, color: AppTheme.lightTextSecondary),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 80,
                      child: Text(
                        r.label,
                        style: const TextStyle(
                            fontSize: 13, color: AppTheme.lightTextSecondary),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        r.value,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: r.valueColor,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.04);
  }

  Widget _buildClassesCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _subjectColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _subjectColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.class_rounded, color: _subjectColor, size: 18),
              const SizedBox(width: 8),
              Text(
                'Assigned Classes',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: _subjectColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: teacher.assignedClasses.isEmpty
                ? [
                    Chip(
                      label: const Text('All Classes'),
                      backgroundColor: _subjectColor.withValues(alpha: 0.15),
                      labelStyle: TextStyle(color: _subjectColor, fontSize: 12),
                    )
                  ]
                : teacher.assignedClasses
                    .map((cls) => Chip(
                          label: Text(cls),
                          backgroundColor: _subjectColor.withValues(alpha: 0.15),
                          labelStyle: TextStyle(color: _subjectColor, fontSize: 12),
                        ))
                    .toList(),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 300.ms);
  }

  Widget _buildAvatar(double size) {
    if (teacher.profilePicUrl.isNotEmpty) {
      return CircleAvatar(
        radius: size / 2,
        backgroundColor: Colors.white.withValues(alpha: 0.2),
        child: ClipOval(
          child: CachedNetworkImage(
            imageUrl: teacher.profilePicUrl,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorWidget: (_, __, ___) => _buildInitialsAvatar(size),
          ),
        ),
      );
    }
    return _buildInitialsAvatar(size);
  }

  Widget _buildInitialsAvatar(double size) {
    final initials = teacher.name.isNotEmpty
        ? teacher.name
            .split(' ')
            .take(2)
            .map((w) => w.isNotEmpty ? w[0].toUpperCase() : '')
            .join()
        : 'T';
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: Colors.white.withValues(alpha: 0.25),
      child: Text(
        initials,
        style: TextStyle(
          fontSize: size * 0.32,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log Out'),
        content: const Text(
          'Are you sure you want to log out of the teacher portal?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.warningRed,
                foregroundColor: Colors.white),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await FirebaseAuth.instance.signOut();
      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const RoleSelectionScreen()),
          (_) => false,
        );
      }
    }
  }
}

class _Row {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  const _Row(this.icon, this.label, this.value, {this.valueColor});
}
