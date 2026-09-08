import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../models/student_model.dart';
import '../widgets/student_avatar.dart';
import '../services/database_service.dart';
import '../services/sync_service.dart';
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
          ).animate().fadeIn().slideX(begin: 0.08);
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
                ).animate().fadeIn().slideY(begin: 0.12),
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

  List<StudentModel> get _allStudents => DatabaseService.getStudentsByClass(
    classType: 'FSc',
    subject: widget.subject,
    grade: widget.grade,
  );

  /// Filter students by whether their schedule for this subject contains
  /// the selected time slot text
  List<StudentModel> get _filteredStudents {
    final all = _allStudents;
    if (_startSlotIdx == null) return all;

    // Build the selected time string to match against student schedules
    final selectedSlot = kScheduleSlots[_startSlotIdx!];

    return all.where((s) {
      final schedule = s.getScheduleForSubject(widget.subject).trim().toLowerCase();
      if (schedule.isEmpty) return false;

      // If only a single slot is selected, match if the schedule contains that time
      if (_endSlotIdx == null) {
        return schedule.contains(selectedSlot.toLowerCase());
      }

      // If a range is selected, check if the student's schedule overlaps
      final rangeStart = selectedSlot.toLowerCase();
      final rangeEnd = kScheduleSlots[_endSlotIdx!].toLowerCase();

      // Check if the student schedule contains the start time, end time,
      // or the full range string
      final fullRange = '$rangeStart - $rangeEnd';
      final fullRangeDash = '$rangeStart — $rangeEnd';

      if (schedule.contains(fullRange) || schedule.contains(fullRangeDash)) return true;
      if (schedule.contains(rangeStart) || schedule.contains(rangeEnd)) return true;

      // Also check if any slot in the selected range is mentioned in the schedule
      for (int i = _startSlotIdx!; i <= _endSlotIdx!; i++) {
        if (schedule.contains(kScheduleSlots[i].toLowerCase())) return true;
      }
      return false;
    }).toList();
  }

  bool get _isFiltering => _startSlotIdx != null;

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

  void _clearScheduleFilter() {
    setState(() {
      _startSlotIdx = null;
      _endSlotIdx = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Listen to SyncService so that this screen rebuilds on real-time sync updates
    Provider.of<SyncService>(context);
    final allStudents = _allStudents;
    final students = _filteredStudents;
    final color = kSubjectColors[widget.subject] ?? AppTheme.primaryBlue;

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.grade} — ${widget.subject}'),
        actions: [
          if (_isFiltering)
            TextButton.icon(
              onPressed: _clearScheduleFilter,
              icon: const Icon(Icons.clear_rounded, color: Colors.white, size: 18),
              label: Text(
                'Show All',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ── Breadcrumbs ──
          _buildBreadcrumbs(context),
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
          ).animate().fadeIn().slideY(begin: 0.1),

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
                      _startSlotIdx = index;
                      _endSlotIdx = (index + 1 < kScheduleSlots.length) ? index + 1 : index;
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
          ).animate().fadeIn(),

          const SizedBox(height: 28),

          // ── Filter Active Banner ──
          if (_isFiltering)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color.withValues(alpha: 0.25)),
              ),
              child: Row(
                children: [
                  Icon(Icons.filter_alt_rounded, color: color, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Showing ${students.length} of ${allStudents.length} students scheduled at ${_getRangeText()}',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: _clearScheduleFilter,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.close_rounded, color: color, size: 16),
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn().slideY(begin: 0.05),

          // ── Students header ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  _isFiltering
                      ? 'Filtered Students (${students.length})'
                      : 'Enrolled Students (${students.length})',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (students.isEmpty)
            _isFiltering
                ? _buildNoScheduleMatch(color)
                : _buildEmptyStudents()
          else
            ...students.asMap().entries.map((e) {
              final idx = e.key;
              final s = e.value;
              return _buildStudentTile(s, idx);
            }),
        ],
      ),
    );
  }

  Widget _buildStudentTile(StudentModel s, int index) {
    final bool isSubjectPaid = s.isSubjectPaid(widget.subject);
    final double subjectRemaining = s.getSubjectRemaining(widget.subject);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => StudentDetailScreen(student: s)),
        ).then((_) => setState(() {})),
        leading: StudentAvatar(
          student: s,
          size: 40,
          isCircle: true,
        ),
        title: Text(s.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(
          '${s.phone}  •  Schedule: ${s.getScheduleForSubject(widget.subject)}',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isSubjectPaid ? Colors.green.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            isSubjectPaid ? 'PAID' : 'Rs ${subjectRemaining.toStringAsFixed(0)}',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: isSubjectPaid ? Colors.green : Colors.red,
            ),
          ),
        ),
      ),
    ).animate().fadeIn().slideX(begin: 0.06);
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
              'Students added to this class will appear here',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
            ),
          ],
        ),
      ),
    ).animate().fadeIn();
  }

  Widget _buildNoScheduleMatch(Color color) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            Icon(Icons.schedule_rounded, size: 56, color: color.withValues(alpha: 0.3)),
            const SizedBox(height: 12),
            Text(
              'No students at this time',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: color),
            ),
            const SizedBox(height: 6),
            Text(
              'No students are scheduled for ${widget.subject} at ${_getRangeText()}',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: _clearScheduleFilter,
              icon: const Icon(Icons.clear_all_rounded),
              label: const Text('Show All Students'),
            ),
          ],
        ),
      ),
    ).animate().fadeIn();
  }

  Widget _buildBreadcrumbs(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            child: Text(
              'Teacher',
              style: TextStyle(
                color: AppTheme.primaryBlue,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Icon(Icons.chevron_right_rounded, size: 16, color: Colors.grey.shade400),
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Text(
              'FSc',
              style: TextStyle(
                color: AppTheme.primaryBlue,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Icon(Icons.chevron_right_rounded, size: 16, color: Colors.grey.shade400),
          Text(
            widget.subject,
            style: const TextStyle(
              color: Colors.black87,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          Icon(Icons.chevron_right_rounded, size: 16, color: Colors.grey.shade400),
          Expanded(
            child: Text(
              widget.grade,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
