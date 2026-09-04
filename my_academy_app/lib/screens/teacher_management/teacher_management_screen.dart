import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/teacher_model.dart';
import '../../services/teacher_service.dart';
import '../../theme/app_theme.dart';
import 'add_edit_teacher_screen.dart';

class TeacherManagementScreen extends StatelessWidget {
  const TeacherManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Teacher Management',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline_rounded),
            tooltip: 'How teacher accounts are created',
            onPressed: () => _showAccountCreationInfo(context),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AddEditTeacherScreen()),
        ),
        icon: const Icon(Icons.person_add_rounded),
        label: Text('Add Teacher', style: GoogleFonts.poppins()),
      ),
      body: StreamBuilder<List<TeacherModel>>(
        stream: TeacherService.getAllTeachersStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _buildError(snapshot.error.toString());
          }

          final teachers = snapshot.data ?? [];

          if (teachers.isEmpty) {
            return _buildEmpty(context);
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: teachers.length,
            itemBuilder: (context, i) => _buildTeacherCard(
              context,
              teachers[i],
              i,
            ),
          );
        },
      ),
    );
  }

  Widget _buildTeacherCard(
      BuildContext context, TeacherModel teacher, int idx) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final subjectColor = _subjectColor(teacher.subject);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Avatar
                CircleAvatar(
                  radius: 26,
                  backgroundColor: subjectColor.withValues(alpha: 0.1),
                  child: teacher.profilePicUrl.isNotEmpty
                      ? ClipOval(
                          child: CachedNetworkImage(
                            imageUrl: teacher.profilePicUrl,
                            width: 52,
                            height: 52,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) =>
                                _initialsWidget(teacher, subjectColor),
                          ),
                        )
                      : _initialsWidget(teacher, subjectColor),
                ),
                const SizedBox(width: 14),

                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        teacher.name,
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        teacher.tagLine,
                        style: TextStyle(
                          fontSize: 12,
                          color: subjectColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        teacher.teacherId,
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.lightTextSecondary,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),

                // Status badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: teacher.isActive
                        ? Colors.green.withValues(alpha: 0.1)
                        : Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    teacher.isActive ? 'ACTIVE' : 'INACTIVE',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: teacher.isActive ? Colors.green : Colors.red,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Classes
            if (teacher.assignedClasses.isNotEmpty) ...[
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: teacher.assignedClasses
                    .map((c) => Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: subjectColor.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            c,
                            style: TextStyle(
                              fontSize: 11,
                              color: subjectColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 12),
            ],

            // Email
            Row(
              children: [
                const Icon(Icons.email_outlined,
                    size: 14, color: AppTheme.lightTextSecondary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    teacher.email,
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.lightTextSecondary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),

            const Divider(height: 20),

            // Actions
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            AddEditTeacherScreen(teacher: teacher),
                      ),
                    ),
                    icon: const Icon(Icons.edit_rounded, size: 16),
                    label: const Text('Edit'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _toggleActive(context, teacher),
                    icon: Icon(
                      teacher.isActive
                          ? Icons.block_rounded
                          : Icons.check_circle_outline_rounded,
                      size: 16,
                      color: teacher.isActive ? Colors.red : Colors.green,
                    ),
                    label: Text(
                      teacher.isActive ? 'Deactivate' : 'Reactivate',
                      style: TextStyle(
                          color:
                              teacher.isActive ? Colors.red : Colors.green),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      side: BorderSide(
                          color: teacher.isActive ? Colors.red : Colors.green),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: (idx * 60).ms).slideY(begin: 0.05);
  }

  Widget _initialsWidget(TeacherModel teacher, Color color) {
    final initials = teacher.name.isNotEmpty
        ? teacher.name
            .split(' ')
            .take(2)
            .map((w) => w.isNotEmpty ? w[0].toUpperCase() : '')
            .join()
        : 'T';
    return Text(
      initials,
      style: TextStyle(
        fontWeight: FontWeight.bold,
        color: color,
        fontSize: 18,
      ),
    );
  }

  Future<void> _toggleActive(
      BuildContext context, TeacherModel teacher) async {
    final action = teacher.isActive ? 'deactivate' : 'reactivate';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${action[0].toUpperCase()}${action.substring(1)} Teacher?'),
        content: Text(
          'Are you sure you want to $action ${teacher.name}?${teacher.isActive ? " They will no longer be able to login." : ""}',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  teacher.isActive ? AppTheme.warningRed : AppTheme.secondaryGreen,
              foregroundColor: Colors.white,
            ),
            child: Text(action[0].toUpperCase() + action.substring(1)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await TeacherService.setTeacherActive(teacher.id, !teacher.isActive);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${teacher.name} has been ${teacher.isActive ? "deactivated" : "reactivated"}.',
              ),
              behavior: SnackBarBehavior.floating,
              backgroundColor: teacher.isActive
                  ? AppTheme.warningRed
                  : AppTheme.secondaryGreen,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed: $e'),
              backgroundColor: AppTheme.warningRed,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  void _showAccountCreationInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Creating Teacher Accounts'),
        content: const SingleChildScrollView(
          child: Text(
            'To create a teacher portal account:\n\n'
            '1. Tap "Add Teacher" and fill in the details.\n'
            '2. The form saves the teacher profile in Firestore with a "teacher" role.\n'
            '3. A SEPARATE Firebase Auth account must be created for the teacher '
            'using the Firebase Console (Authentication → Add User), using the '
            'email and password you specify.\n'
            '4. The Firestore teacher document ID must match the Firebase Auth UID '
            '(copy the UID from Firebase Console after creating the Auth user).\n\n'
            'Alternatively, use a Cloud Function to automate this process.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline_rounded,
                size: 72, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              'No Teachers Yet',
              style: GoogleFonts.poppins(
                  fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Add teachers using the button below to get started.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const AddEditTeacherScreen()),
              ),
              icon: const Icon(Icons.person_add_rounded),
              label: const Text('Add First Teacher'),
            ),
          ],
        ),
      ),
    ).animate().fadeIn();
  }

  Widget _buildError(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.wifi_off_rounded,
                size: 56, color: AppTheme.warningRed),
            const SizedBox(height: 16),
            Text('Failed to load teachers',
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(error,
                style:
                    const TextStyle(fontSize: 12, color: Colors.grey),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Color _subjectColor(String subject) {
    switch (subject.toLowerCase()) {
      case 'biology': return const Color(0xFF059669);
      case 'physics': return const Color(0xFF2563EB);
      case 'chemistry': return const Color(0xFFD97706);
      case 'mathematics': case 'math': return const Color(0xFF0891B2);
      case 'english': return const Color(0xFF7C3AED);
      default: return AppTheme.primaryBlue;
    }
  }
}
