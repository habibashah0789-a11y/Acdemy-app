import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/teacher_model.dart';
import '../models/student_model.dart';
import '../services/teacher_service.dart';
import '../theme/app_theme.dart';
import 'teacher_student_detail_screen.dart';

class TeacherStudentsScreen extends StatefulWidget {
  final TeacherModel teacher;
  const TeacherStudentsScreen({super.key, required this.teacher});

  @override
  State<TeacherStudentsScreen> createState() => _TeacherStudentsScreenState();
}

class _TeacherStudentsScreenState extends State<TeacherStudentsScreen> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Color get _subjectColor {
    switch (widget.teacher.subject.toLowerCase()) {
      case 'biology': return const Color(0xFF059669);
      case 'physics': return const Color(0xFF2563EB);
      case 'chemistry': return const Color(0xFFD97706);
      case 'mathematics': case 'math': return const Color(0xFF0891B2);
      case 'english': return const Color(0xFF7C3AED);
      default: return AppTheme.primaryBlue;
    }
  }

  List<StudentModel> _applySearch(List<StudentModel> students) {
    if (_searchQuery.isEmpty) return students;
    final q = _searchQuery.toLowerCase();
    return students.where((s) =>
      s.name.toLowerCase().contains(q) ||
      s.studentCode.toLowerCase().contains(q) ||
      s.phone.contains(q) ||
      s.grade.toLowerCase().contains(q)
    ).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'My Students',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(66),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _searchQuery = v),
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Search by name, ID or phone...',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: isDark ? AppTheme.darkSurface : Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      body: StreamBuilder<List<StudentModel>>(
        stream: TeacherService.getTeacherStudentsStream(widget.teacher),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _buildError(snapshot.error.toString());
          }

          final allStudents = snapshot.data ?? [];
          final filtered = _applySearch(allStudents);
          final grouped = TeacherService.groupStudentsByClass(filtered, widget.teacher);

          if (allStudents.isEmpty) {
            return _buildEmptyState();
          }

          if (filtered.isEmpty && _searchQuery.isNotEmpty) {
            return _buildNoResults();
          }

          return RefreshIndicator(
            onRefresh: () async {},
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: grouped.keys.length,
              itemBuilder: (context, groupIdx) {
                final cls = grouped.keys.elementAt(groupIdx);
                final students = grouped[cls]!;
                return _buildClassGroup(cls, students, groupIdx);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildClassGroup(String cls, List<StudentModel> students, int groupIdx) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (groupIdx > 0) const SizedBox(height: 24),
        // Class Header
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: _subjectColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _subjectColor.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              Icon(Icons.class_rounded, color: _subjectColor, size: 16),
              const SizedBox(width: 8),
              Text(
                '${widget.teacher.subject} — $cls',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: _subjectColor,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _subjectColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${students.length} ${students.length == 1 ? "student" : "students"}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: _subjectColor,
                  ),
                ),
              ),
            ],
          ),
        ).animate().fadeIn(delay: (groupIdx * 100).ms),

        if (students.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: Text(
                'No students in this class',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
              ),
            ),
          )
        else
          ...students.asMap().entries.map((e) {
            final idx = e.key;
            final student = e.value;
            return _buildStudentTile(student, groupIdx * 10 + idx);
          }),
      ],
    );
  }

  Widget _buildStudentTile(StudentModel student, int idx) {
    final isPaid = student.isSubjectPaid(widget.teacher.subject);
    final remaining = student.getSubjectRemaining(widget.teacher.subject);


    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TeacherStudentDetailScreen(
              student: student,
              teacher: widget.teacher,
            ),
          ),
        ),
        leading: CircleAvatar(
          radius: 22,
          backgroundColor: _subjectColor.withValues(alpha: 0.1),
          child: student.profilePicUrl.isNotEmpty
              ? ClipOval(
                  child: CachedNetworkImage(
                    imageUrl: student.profilePicUrl,
                    width: 44,
                    height: 44,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => _buildInitials(student),
                  ),
                )
              : _buildInitials(student),
        ),
        title: Text(
          student.name,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              student.studentCode,
              style: TextStyle(
                fontSize: 11,
                color: AppTheme.lightTextSecondary,
                fontFamily: 'monospace',
              ),
            ),
            if (student.phone.isNotEmpty)
              Text(
                student.phone,
                style: const TextStyle(fontSize: 11, color: AppTheme.lightTextSecondary),
              ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: isPaid
                    ? Colors.green.withValues(alpha: 0.1)
                    : Colors.red.withValues(alpha: 0.1), 
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                isPaid ? 'PAID' : 'Rs ${remaining.toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isPaid ? Colors.green : Colors.red,
                ),
              ),
            ),
            const SizedBox(height: 4),
            const Icon(Icons.chevron_right_rounded,
                size: 16, color: AppTheme.lightTextSecondary),
          ],
        ),
      ),
    ).animate().fadeIn(delay: (idx * 40).ms).slideX(begin: 0.04);
  }

  Widget _buildInitials(StudentModel student) {
    return Text(
      student.name.isNotEmpty ? student.name[0].toUpperCase() : 'S',
      style: TextStyle(
        fontWeight: FontWeight.bold,
        color: _subjectColor,
        fontSize: 16,
      ),
    );
  }

  Widget _buildEmptyState() {
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
              'No Students Yet',
              style: GoogleFonts.poppins(
                  fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'No students are enrolled in ${widget.teacher.subject} (${widget.teacher.section}) yet.\nStudents will appear here once registered by administration.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
            ),
          ],
        ),
      ),
    ).animate().fadeIn();
  }

  Widget _buildNoResults() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off_rounded,
                size: 72, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              'No Results',
              style: GoogleFonts.poppins(
                  fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'No students match "$_searchQuery"',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
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
            const Icon(Icons.wifi_off_rounded, size: 56, color: AppTheme.warningRed),
            const SizedBox(height: 16),
            Text('Failed to load students', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(error, style: const TextStyle(fontSize: 12, color: Colors.grey), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
