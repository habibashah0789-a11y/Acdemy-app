import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'daily_records_screen.dart';
import '../../theme/app_theme.dart';
import '../../students/student_detail_screen.dart';
import '../../models/student_model.dart';

class DailyRecordDetailScreen extends StatelessWidget {
  final DailyRecordData record;

  const DailyRecordDetailScreen({super.key, required this.record});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(DateFormat('MMM dd, yyyy').format(record.date)),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Header Summary
          Container(
            padding: const EdgeInsets.all(20),
            color: AppTheme.primaryBlue,
            width: double.infinity,
            child: Column(
              children: [
                const Text(
                  'Total Collected',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 8),
                Text(
                  'Rs. ${record.totalCollected.toStringAsFixed(0)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.people_alt_rounded, color: Colors.white, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        '${record.studentCount} Students Registered',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Student List
          Expanded(
            child: record.students.isEmpty
                ? const Center(child: Text('No students found.'))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: record.students.length,
                    itemBuilder: (context, index) {
                      final student = record.students[index];
                      return _buildStudentCard(context, student, isDark);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentCard(BuildContext context, StudentModel student, bool isDark) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => StudentDetailScreen(student: student),
            ),
          );
        },
        leading: Hero(
          tag: 'daily_student_${student.id}',
          child: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: AppTheme.primaryBlue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: student.profilePicUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: student.profilePicUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => const Center(
                        child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                      ),
                      errorWidget: (_, __, ___) => const Icon(Icons.person_rounded, color: AppTheme.primaryBlue),
                    )
                  : Center(
                      child: Text(
                        student.initials.isNotEmpty ? student.initials : 'S',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: AppTheme.primaryBlue),
                      ),
                    ),
            ),
          ),
        ),
        title: Text(
          student.name,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Text(
            'Collected: Rs. ${student.feeSubmitted.toStringAsFixed(0)}',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ),
        trailing: _buildFeeBadge(student),
      ),
    );
  }

  Widget _buildFeeBadge(StudentModel student) {
    final bool isClear = student.feeRemaining <= 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isClear ? Colors.green.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        isClear ? 'SUBMITTED' : 'PENDING',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: isClear ? Colors.green : Colors.red,
        ),
      ),
    );
  }
}
