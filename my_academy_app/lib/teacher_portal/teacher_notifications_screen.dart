import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/teacher_model.dart';
import '../theme/app_theme.dart';

class TeacherNotificationsScreen extends StatelessWidget {
  final TeacherModel teacher;
  const TeacherNotificationsScreen({super.key, required this.teacher});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Notifications',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('notifications')
            .orderBy('createdAt', descending: true)
            .limit(50)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text('Failed to load notifications',
                  style: GoogleFonts.poppins()),
            );
          }

          final docs = snapshot.data?.docs ?? [];
          // Filter notifications: show if targetSubject matches or broadcast (no targetSubject / targetSubject = 'all')
          final filtered = docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final targetSubject =
                (data['targetSubject'] as String? ?? '').toLowerCase();
            final targetSection =
                (data['targetSection'] as String? ?? '').toLowerCase();
            if (targetSubject.isEmpty ||
                targetSubject == 'all' ||
                targetSection == 'all') {
              return true;
            }
            final mySubject = teacher.subject.toLowerCase();
            final mySection = teacher.section.toLowerCase();
            return targetSubject == mySubject &&
                (targetSection.isEmpty || targetSection == mySection);
          }).toList();

          if (filtered.isEmpty) {
            return _buildEmpty();
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: filtered.length,
            itemBuilder: (context, i) {
              final data =
                  filtered[i].data() as Map<String, dynamic>;
              return _buildNotifCard(data, i, isDark);
            },
          );
        },
      ),
    );
  }

  Widget _buildNotifCard(
      Map<String, dynamic> data, int idx, bool isDark) {
    final title = data['title'] as String? ?? 'Notification';
    final body = data['body'] as String? ?? '';
    final type = data['type'] as String? ?? 'info';
    final raw = data['createdAt'];
    DateTime? dt;
    if (raw is Timestamp) dt = raw.toDate();

    final color = _colorForType(type);
    final icon = _iconForType(type);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (body.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      body,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.lightTextSecondary,
                        height: 1.4,
                      ),
                    ),
                  ],
                  if (dt != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      DateFormat('dd MMM yyyy, hh:mm a').format(dt),
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
    ).animate().fadeIn(delay: (idx * 60).ms).slideX(begin: 0.05);
  }

  Color _colorForType(String type) {
    switch (type) {
      case 'warning': return AppTheme.warningRed;
      case 'success': return AppTheme.secondaryGreen;
      case 'fee': return AppTheme.accentOrange;
      default: return AppTheme.accentIndigo;
    }
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'warning': return Icons.warning_rounded;
      case 'success': return Icons.check_circle_rounded;
      case 'fee': return Icons.payments_rounded;
      default: return Icons.notifications_rounded;
    }
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notifications_off_rounded,
                size: 72, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              'No Notifications',
              style: GoogleFonts.poppins(
                  fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'You have no notifications at this time.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
            ),
          ],
        ),
      ),
    ).animate().fadeIn();
  }
}
