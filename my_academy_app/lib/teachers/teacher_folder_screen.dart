import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/student_model.dart';
import '../services/database_service.dart';
import '../students/add_student_screen.dart';
import '../students/student_detail_screen.dart';
import '../theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Constants
// ─────────────────────────────────────────────────────────────────────────────
const List<String> kSubjects = ['Biology', 'Physics', 'Chemistry', 'English', 'Math'];

const Map<String, List<String>> kGrades = {
  'FSc': ['First Year', 'Second Year'],
  'Matric': ['Ninth', 'Tenth'],
};

const Map<String, IconData> kSubjectIcons = {
  'Biology': Icons.biotech_rounded,
  'Physics': Icons.science_rounded,
  'Chemistry': Icons.colorize_rounded,
  'English': Icons.menu_book_rounded,
  'Math': Icons.calculate_rounded,
};

const Map<String, Color> kSubjectColors = {
  'Biology': Color(0xFF4CAF50),
  'Physics': Color(0xFF2196F3),
  'Chemistry': Color(0xFFFF9800),
  'English': Color(0xFF9C27B0),
  'Math': Color(0xFF00897B),
};

const List<String> kScheduleSlots = [
  '7:00 AM', '8:00 AM', '9:00 AM', '10:00 AM', '11:00 AM',
  '12:00 PM', '1:00 PM', '2:00 PM', '3:00 PM', '4:00 PM',
  '5:00 PM', '6:00 PM', '7:00 PM', '8:00 PM', '9:00 PM', '10:00 PM',
];

// ─────────────────────────────────────────────────────────────────────────────
// LEVEL 0 — Two main folders: FSc Teachers & Matric Teachers
// ─────────────────────────────────────────────────────────────────────────────
class TeacherFolderScreen extends StatelessWidget {
  const TeacherFolderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Teachers')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select Category',
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Browse teachers by class type',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            ),
            const SizedBox(height: 28),
            _FolderCard(
              title: 'FSc Teachers',
              subtitle: 'First Year & Second Year',
              icon: Icons.school_rounded,
              gradient: const [Color(0xFF1565C0), Color(0xFF42A5F5)],
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const SubjectListScreen(classType: 'FSc'),
                ),
              ),
            ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.15),
            const SizedBox(height: 16),
            _FolderCard(
              title: 'Matric Teachers',
              subtitle: 'Ninth & Tenth Class',
              icon: Icons.auto_stories_rounded,
              gradient: const [Color(0xFF2E7D32), Color(0xFF66BB6A)],
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const SubjectListScreen(classType: 'Matric'),
                ),
              ),
            ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.15),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LEVEL 1 — Five subject folders for the selected class type
// ─────────────────────────────────────────────────────────────────────────────
class SubjectListScreen extends StatelessWidget {
  final String classType;
  const SubjectListScreen({super.key, required this.classType});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('$classType Subjects')),
      body: ListView.separated(
        padding: const EdgeInsets.all(20),
        itemCount: kSubjects.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final subject = kSubjects[index];
          final color = kSubjectColors[subject]!;
          final icon = kSubjectIcons[subject]!;
          return _FolderCard(
            title: subject,
            subtitle: classType == 'FSc'
                ? 'First Year · Second Year'
                : 'Ninth · Tenth',
            icon: icon,
            gradient: [color, color.withOpacity(0.7)],
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => GradeListScreen(
                  classType: classType,
                  subject: subject,
                ),
              ),
            ),
          ).animate().fadeIn(delay: (index * 80).ms).slideX(begin: 0.08);
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LEVEL 2 — Grade subfolders (First Year/Second Year or Ninth/Tenth)
// ─────────────────────────────────────────────────────────────────────────────
class GradeListScreen extends StatelessWidget {
  final String classType;
  final String subject;
  const GradeListScreen({super.key, required this.classType, required this.subject});

  @override
  Widget build(BuildContext context) {
    final grades = kGrades[classType]!;
    final color = kSubjectColors[subject] ?? AppTheme.primaryBlue;

    return Scaffold(
      appBar: AppBar(title: Text('$subject — $classType')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select Grade',
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Choose a year / class to view students',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            ),
            const SizedBox(height: 28),
            ...grades.asMap().entries.map((e) {
              final idx = e.key;
              final grade = e.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _FolderCard(
                  title: grade,
                  subtitle: '$subject — $classType',
                  icon: Icons.folder_open_rounded,
                  gradient: [color, color.withOpacity(0.6)],
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ClassRoomScreen(
                        classType: classType,
                        subject: subject,
                        grade: grade,
                      ),
                    ),
                  ),
                ).animate().fadeIn(delay: (idx * 120).ms).slideY(begin: 0.12),
              );
            }),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LEVEL 3 — Classroom view: schedule + student list
// ─────────────────────────────────────────────────────────────────────────────
class ClassRoomScreen extends StatefulWidget {
  final String classType;
  final String subject;
  final String grade;
  const ClassRoomScreen({
    super.key,
    required this.classType,
    required this.subject,
    required this.grade,
  });

  @override
  State<ClassRoomScreen> createState() => _ClassRoomScreenState();
}

class _ClassRoomScreenState extends State<ClassRoomScreen> {
  List<StudentModel> get _students => DatabaseService.getStudentsByClass(
    classType: widget.classType,
    subject: widget.subject,
    grade: widget.grade,
  );

  @override
  Widget build(BuildContext context) {
    final students = _students;
    final color = kSubjectColors[widget.subject] ?? AppTheme.primaryBlue;

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.grade} — ${widget.subject}'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ── Schedule Banner ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [color, color.withOpacity(0.7)]),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.25),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.schedule_rounded, color: Colors.white, size: 24),
                    const SizedBox(width: 10),
                    Text(
                      'Class Schedule',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  '7:00 AM — 10:00 PM',
                  style: GoogleFonts.poppins(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${widget.classType} · ${widget.subject} · ${widget.grade}',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.1),

          const SizedBox(height: 12),

          // ── Schedule time slots ──
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: kScheduleSlots.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: color.withOpacity(0.2)),
                  ),
                  child: Text(
                    kScheduleSlots[index],
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                );
              },
            ),
          ).animate().fadeIn(delay: 200.ms),

          const SizedBox(height: 28),

          // ── Students header ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Enrolled Students (${students.length})',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton.icon(
                onPressed: () => _addStudent(),
                icon: const Icon(Icons.person_add_rounded, size: 18),
                label: const Text('Add'),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (students.isEmpty)
            _buildEmptyStudents()
          else
            ...students.asMap().entries.map((e) {
              final idx = e.key;
              final s = e.value;
              return _buildStudentTile(s, idx);
            }),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addStudent,
        icon: const Icon(Icons.person_add_rounded),
        label: const Text('Add Student'),
        backgroundColor: color,
      ).animate().scale(delay: 300.ms),
    );
  }

  void _addStudent() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddStudentScreen(
          presetClassType: widget.classType,
          presetSubject: widget.subject,
          presetGrade: widget.grade,
        ),
      ),
    ).then((_) => setState(() {}));
  }

  Widget _buildStudentTile(StudentModel s, int index) {
    final bool isPaid = s.feeRemaining <= 0;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => StudentDetailScreen(student: s)),
        ).then((_) => setState(() {})),
        leading: CircleAvatar(
          backgroundColor: AppTheme.primaryBlue.withOpacity(0.1),
          child: s.profilePicUrl.isNotEmpty
              ? ClipOval(
                  child: CachedNetworkImage(
                    imageUrl: s.profilePicUrl,
                    width: 40,
                    height: 40,
                    fit: BoxFit.cover,
                  ),
                )
              : Text(
                  s.name.isNotEmpty ? s.name[0].toUpperCase() : 'S',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryBlue,
                  ),
                ),
        ),
        title: Text(s.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(
          '${s.phone}  •  Schedule: ${s.schedule}',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isPaid ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            isPaid ? 'PAID' : 'Rs ${s.feeRemaining.toStringAsFixed(0)}',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: isPaid ? Colors.green : Colors.red,
            ),
          ),
        ),
      ),
    ).animate().fadeIn(delay: (index * 60).ms).slideX(begin: 0.06);
  }

  Widget _buildEmptyStudents() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            Icon(Icons.people_outline_rounded, size: 56, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            const Text(
              'No students enrolled yet',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              'Tap "Add Student" to enroll a student in this class',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
            ),
          ],
        ),
      ),
    ).animate().fadeIn();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared Folder Card Widget
// ─────────────────────────────────────────────────────────────────────────────
class _FolderCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> gradient;
  final VoidCallback onTap;

  const _FolderCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: gradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: gradient.first.withOpacity(0.25),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: Colors.white, size: 30),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withOpacity(0.85),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: Colors.white.withOpacity(0.7),
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
