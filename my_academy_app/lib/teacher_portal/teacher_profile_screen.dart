import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../models/teacher_model.dart';
import '../services/teacher_service.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import '../screens/role_selection_screen.dart';
import '../widgets/about_developers_widget.dart';
import '../screens/app_info_screens.dart';
import '../utils/image_utils.dart';
import '../widgets/crop_image_dialog.dart';
import '../widgets/teacher_avatar.dart';

class TeacherProfileScreen extends StatelessWidget {
  final TeacherModel teacher;
  const TeacherProfileScreen({super.key, required this.teacher});

  Color _getSubjectColor(String subject) {
    switch (subject.toLowerCase()) {
      case 'biology':
        return const Color(0xFF059669);
      case 'physics':
        return const Color(0xFF2563EB);
      case 'chemistry':
        return const Color(0xFFD97706);
      case 'mathematics':
      case 'math':
        return const Color(0xFF0891B2);
      case 'english':
        return const Color(0xFF7C3AED);
      default:
        return AppTheme.primaryBlue;
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
      body: StreamBuilder<TeacherModel?>(
        stream: TeacherService.getCurrentTeacherStream(),
        initialData: teacher,
        builder: (context, snapshot) {
          final currentTeacher = snapshot.data ?? teacher;
          final subjectColor = _getSubjectColor(currentTeacher.subject);

          return SingleChildScrollView(
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
                      colors: [AppTheme.primaryDarkBlue, subjectColor],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: subjectColor.withValues(alpha: 0.25),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      _buildAvatar(context, 84, currentTeacher),
                      const SizedBox(height: 16),
                      Text(
                        currentTeacher.name.isNotEmpty
                            ? currentTeacher.name
                            : 'Faculty Member',
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        currentTeacher.tagLine,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          currentTeacher.teacherId.isNotEmpty
                              ? currentTeacher.teacherId
                              : 'ID-TEACHER',
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
                _buildInfoCard(isDark, currentTeacher, subjectColor),
                const SizedBox(height: 20),

                // ── Assigned Classes ──
                _buildClassesCard(isDark, currentTeacher, subjectColor),
                const SizedBox(height: 20),

                // ── About App & Manual ──
                Material(
                  color: isDark ? AppTheme.darkCard : Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color:
                          isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryBlue.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.info_outline_rounded,
                          color: AppTheme.primaryBlue, size: 20),
                    ),
                    title: Text(
                      'About Quaid Academy App',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      'Features, version details & manual',
                      style: GoogleFonts.poppins(
                          fontSize: 11, color: Colors.grey),
                    ),
                    trailing:
                        const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const AboutAppScreen()),
                      );
                    },
                  ),
                ).animate().fadeIn(),

                const SizedBox(height: 20),

                const AboutDevelopersCard().animate().fadeIn(),

                const SizedBox(height: 32),

                // ── Logout Button ──
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
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ).animate().fadeIn(),

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
          );
        },
      ),
    );
  }

  Widget _buildInfoCard(
      bool isDark, TeacherModel currentTeacher, Color subjectColor) {
    final rows = [
      _Row(Icons.email_rounded, 'Email', currentTeacher.email),
      _Row(Icons.auto_stories_rounded, 'Subject', currentTeacher.subject),
      _Row(Icons.school_rounded, 'Section', currentTeacher.section),
      _Row(
        currentTeacher.isActive
            ? Icons.verified_rounded
            : Icons.block_rounded,
        'Status',
        currentTeacher.isActive ? 'Active' : 'Inactive',
        valueColor: currentTeacher.isActive
            ? AppTheme.secondaryGreen
            : AppTheme.warningRed,
      ),
      _Row(
        Icons.calendar_today_rounded,
        'Joined',
        '${currentTeacher.createdAt.day}/${currentTeacher.createdAt.month}/${currentTeacher.createdAt.year}',
      ),
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
              Icon(Icons.badge_rounded, color: subjectColor, size: 18),
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
    ).animate().fadeIn().slideY(begin: 0.04);
  }

  Widget _buildClassesCard(
      bool isDark, TeacherModel currentTeacher, Color subjectColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: subjectColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: subjectColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.class_rounded, color: subjectColor, size: 18),
              const SizedBox(width: 8),
              Text(
                'Assigned Classes',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: subjectColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: currentTeacher.assignedClasses.isEmpty
                ? [
                    Chip(
                      label: const Text('All Classes'),
                      backgroundColor: subjectColor.withValues(alpha: 0.15),
                      labelStyle:
                          TextStyle(color: subjectColor, fontSize: 12),
                    )
                  ]
                : currentTeacher.assignedClasses
                    .map((cls) => Chip(
                          label: Text(cls),
                          backgroundColor:
                              subjectColor.withValues(alpha: 0.15),
                          labelStyle:
                              TextStyle(color: subjectColor, fontSize: 12),
                        ))
                    .toList(),
          ),
        ],
      ),
    ).animate().fadeIn();
  }

  Widget _buildAvatar(BuildContext context, double size, TeacherModel currentTeacher) {
    return Stack(
      children: [
        GestureDetector(
          onTap: () => _changeTeacherPhoto(context, currentTeacher),
          child: Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: TeacherAvatar(
              teacher: currentTeacher,
              size: size,
              backgroundColor: Colors.white.withValues(alpha: 0.25),
            ),
          ),
        ),
        Positioned(
          bottom: 0,
          right: 0,
          child: GestureDetector(
            onTap: () => _changeTeacherPhoto(context, currentTeacher),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.camera_alt_rounded,
                color: AppTheme.primaryBlue,
                size: 16,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _changeTeacherPhoto(
      BuildContext context, TeacherModel currentTeacher) async {
    final picker = ImagePicker();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Update Profile Picture',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryBlue,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.blue.shade50,
                  child: const Icon(Icons.camera_alt,
                      color: AppTheme.primaryBlue),
                ),
                title: const Text('Camera'),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.green.shade50,
                  child: const Icon(Icons.photo_library, color: Colors.green),
                ),
                title: const Text('Gallery'),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );

    if (source == null) return;

    try {
      final pickedFile =
          await picker.pickImage(source: source, imageQuality: 75);
      if (pickedFile != null && context.mounted) {
        final bytes = await pickedFile.readAsBytes();
        final cropped = await showDialog<Uint8List>(
          context: context,
          barrierDismissible: false,
          builder: (_) => CropImageDialog(imageBytes: bytes),
        );

        final imageBytesToUpload = cropped ?? bytes;
        final compressed = await ImageUtils.compressAndResizeImage(
          imageBytesToUpload,
          targetWidth: 360,
          targetHeight: 360,
          quality: 75,
        );

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Uploading profile picture...'),
            duration: Duration(seconds: 2),
          ),
        );

        final uploadedUrl = await TeacherService.uploadTeacherProfileImage(
          compressed,
          currentTeacher.id,
        );

        final picUrl = (uploadedUrl != null && uploadedUrl.isNotEmpty)
            ? uploadedUrl
            : 'data:image/png;base64,${base64Encode(compressed)}';

        final updatedTeacher = currentTeacher.copyWith(profilePicUrl: picUrl);
        await TeacherService.updateTeacher(updatedTeacher);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile picture updated successfully!'),
              backgroundColor: AppTheme.secondaryGreen,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update picture: $e'),
            backgroundColor: AppTheme.warningRed,
          ),
        );
      }
    }
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
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      NotificationService.cancelTeacherSubscription();
      final currentUid = FirebaseAuth.instance.currentUser?.uid;
      if (currentUid != null) {
        unawaited(NotificationService.unregisterFcmToken(userId: currentUid));
      }
      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const RoleSelectionScreen()),
          (_) => false,
        );
      }
      await FirebaseAuth.instance.signOut();
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
