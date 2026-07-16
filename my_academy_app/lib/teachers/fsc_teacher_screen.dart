import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/student_model.dart';
import '../services/database_service.dart';
import '../students/add_student_screen.dart';
import '../students/student_detail_screen.dart';
import '../theme/app_theme.dart';
import 'teacher_folder_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// LEVEL 1 — FSc Subject List Screen
// ─────────────────────────────────────────────────────────────────────────────
class FscSubjectListScreen extends StatelessWidget {
  const FscSubjectListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('FSc Subjects')),
      body: ListView.separated(
        padding: const EdgeInsets.all(20),
        itemCount: kSubjects.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final subject = kSubjects[index];
          final color = kSubjectColors[subject]!;
          final icon = kSubjectIcons[subject]!;
          return FolderCard(
            title: subject,
            subtitle: 'First Year · Second Year',
            icon: icon,
            gradient: [color, color.withValues(alpha: 0.7)],
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => FscGradeListScreen(subject: subject),
              ),
            ),
          ).animate().fadeIn(delay: (index * 80).ms).slideX(begin: 0.08);
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LEVEL 2 — FSc Grade List Screen (First Year / Second Year)
// ─────────────────────────────────────────────────────────────────────────────
class FscGradeListScreen extends StatelessWidget {
  final String subject;
  const FscGradeListScreen({super.key, required this.subject});

  @override
  Widget build(BuildContext context) {
    final grades = kGrades['FSc']!;
    final color = kSubjectColors[subject] ?? AppTheme.primaryBlue;

    return Scaffold(
      appBar: AppBar(title: Text('$subject — FSc')),
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
                child: FolderCard(
                  title: grade,
                  subtitle: '$subject — FSc',
                  icon: Icons.folder_open_rounded,
                  gradient: [color, color.withValues(alpha: 0.6)],
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => FscClassRoomScreen(
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
// LEVEL 3 — FSc Classroom Screen (Interactive schedule + student list)
// ─────────────────────────────────────────────────────────────────────────────
class FscClassRoomScreen extends StatefulWidget {
  final String subject;
  final String grade;
  const FscClassRoomScreen({
    super.key,
    required this.subject,
    required this.grade,
  });

  @override
  State<FscClassRoomScreen> createState() => _FscClassRoomScreenState();
}

class _FscClassRoomScreenState extends State<FscClassRoomScreen> {
  // Start and end indexes for selected schedule sequence
  int? _startSlotIdx;
  int? _endSlotIdx;

  List<StudentModel> get _students => DatabaseService.getStudentsByClass(
    classType: 'FSc',
    subject: widget.subject,
    grade: widget.grade,
  );

  String _getRangeText() {
    if (_startSlotIdx == null) {
      return '7:00 AM — 10:00 PM';
    }
    if (_endSlotIdx == null) {
      return '${kScheduleSlots[_startSlotIdx!]} — Select End';
    }
    return '${kScheduleSlots[_startSlotIdx!]} — ${kScheduleSlots[_endSlotIdx!]}';
  }

  String get _currentRangeForStudent {
    if (_startSlotIdx == null) return '7:00 AM';
    if (_endSlotIdx == null) return kScheduleSlots[_startSlotIdx!];
    return '${kScheduleSlots[_startSlotIdx!]} - ${kScheduleSlots[_endSlotIdx!]}';
  }

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
              gradient: LinearGradient(colors: [color, color.withValues(alpha: 0.7)]),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.25),
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
                  _getRangeText(),
                  style: GoogleFonts.poppins(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'FSc · ${widget.subject} · ${widget.grade}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.1),

          const SizedBox(height: 12),

          // ── Interactive Schedule time slots ──
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: kScheduleSlots.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final isSelected = (_endSlotIdx != null)
                    ? (index >= _startSlotIdx! && index <= _endSlotIdx!)
                    : (index == _startSlotIdx);
                
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      if (_startSlotIdx == null || (_startSlotIdx != null && _endSlotIdx != null)) {
                        _startSlotIdx = index;
                        _endSlotIdx = null;
                      } else {
                        if (index >= _startSlotIdx!) {
                          _endSlotIdx = index;
                        } else {
                          _startSlotIdx = index;
                          _endSlotIdx = null;
                        }
                      }
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isSelected ? color : color.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: isSelected ? color : color.withValues(alpha: 0.2)),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: color.withValues(alpha: 0.3),
                                blurRadius: 6,
                                offset: const Offset(0, 3),
                              )
                            ]
                          : [],
                    ),
                    child: Text(
                      kScheduleSlots[index],
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? Colors.white : color,
                      ),
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
          presetClassType: 'FSc',
          presetSubject: widget.subject,
          presetGrade: widget.grade,
          presetSchedule: _currentRangeForStudent,
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
          backgroundColor: AppTheme.primaryBlue.withValues(alpha: 0.1),
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
            color: isPaid ? Colors.green.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
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
