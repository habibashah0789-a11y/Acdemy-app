import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/teacher_model.dart';
import '../models/student_model.dart';
import '../widgets/student_avatar.dart';
import '../services/teacher_service.dart';
import '../theme/app_theme.dart';
import 'teacher_student_detail_screen.dart';

const List<String> kDefaultScheduleSlots = [
  '7:00 AM', '8:00 AM', '9:00 AM', '10:00 AM', '11:00 AM',
  '12:00 PM', '1:00 PM', '2:00 PM', '3:00 PM', '4:00 PM',
  '5:00 PM', '6:00 PM', '7:00 PM', '8:00 PM', '9:00 PM', '10:00 PM',
];

class TeacherStudentsScreen extends StatefulWidget {
  final TeacherModel teacher;
  const TeacherStudentsScreen({super.key, required this.teacher});

  @override
  State<TeacherStudentsScreen> createState() => _TeacherStudentsScreenState();
}

class _TeacherStudentsScreenState extends State<TeacherStudentsScreen>
    with TickerProviderStateMixin {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  TabController? _tabController;

  // Selected schedule hour slot per class tab (key: className, value: slot string or null for all)
  final Map<String, String?> _selectedSlotByClass = {};

  List<String> get _availableClasses {
    if (widget.teacher.assignedClasses.isNotEmpty) {
      return widget.teacher.assignedClasses;
    }
    final sec = widget.teacher.section.trim().toLowerCase();
    if (sec.contains('matric')) {
      return ['9th Grade', '10th Grade'];
    }
    return ['First Year', 'Second Year'];
  }

  @override
  void initState() {
    super.initState();
    _initTabController();
  }

  void _initTabController() {
    final classes = _availableClasses;
    if (classes.length > 1) {
      _tabController = TabController(length: classes.length, vsync: this);
    } else {
      _tabController?.dispose();
      _tabController = null;
    }
  }

  @override
  void didUpdateWidget(covariant TeacherStudentsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.teacher.assignedClasses != widget.teacher.assignedClasses) {
      _tabController?.dispose();
      _initTabController();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController?.dispose();
    super.dispose();
  }

  Color get _subjectColor {
    switch (widget.teacher.subject.toLowerCase()) {
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

  bool _studentMatchesGrade(StudentModel student, String gradeName) {
    final sGrade = student.grade.trim().toLowerCase();
    final target = gradeName.trim().toLowerCase();
    if (sGrade == target) return true;
    if (target.contains('first') &&
        (sGrade.contains('first') || sGrade.contains('11'))) return true;
    if (target.contains('second') &&
        (sGrade.contains('second') || sGrade.contains('12'))) return true;
    if ((target.contains('9') || target.contains('ninth')) &&
        (sGrade.contains('9') || sGrade.contains('ninth'))) return true;
    if ((target.contains('10') || target.contains('tenth')) &&
        (sGrade.contains('10') || sGrade.contains('tenth'))) return true;
    return sGrade.contains(target) || target.contains(sGrade);
  }

  List<StudentModel> _getStudentsForClass(
      List<StudentModel> allStudents, String className) {
    return allStudents
        .where((s) => _studentMatchesGrade(s, className))
        .toList();
  }

  bool _matchesSchedule(StudentModel student, String slot) {
    if (slot == 'All') return true;
    final sch = student
        .getScheduleForSubject(widget.teacher.subject)
        .trim()
        .toLowerCase();
    if (slot == 'Not Scheduled') {
      return sch.isEmpty || sch == 'not scheduled';
    }
    final target = slot.trim().toLowerCase();
    if (sch == target) return true;
    if (sch.contains(target) || target.contains(sch)) return true;

    // Check if slot starts with the same hour (e.g. 8:00 AM in 8:00 AM - 9:00 AM)
    final cleanTarget = target.replaceAll(RegExp(r'\s+'), '');
    final cleanSch = sch.replaceAll(RegExp(r'\s+'), '');
    return cleanSch.contains(cleanTarget) || cleanTarget.contains(cleanSch);
  }

  List<StudentModel> _applySearch(List<StudentModel> students) {
    if (_searchQuery.isEmpty) return students;
    final q = _searchQuery.toLowerCase();
    return students.where((s) {
      return s.name.toLowerCase().contains(q) ||
          s.studentCode.toLowerCase().contains(q) ||
          s.phone.contains(q) ||
          s.grade.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final classes = _availableClasses;
    final hasMultipleClasses = classes.length > 1 && _tabController != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'My Students',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(hasMultipleClasses ? 116 : 66),
          child: Column(
            children: [
              // Search input
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
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
                    fillColor: isDark ? (AppTheme.isAurora(context) ? AppTheme.auroraGlassCard : AppTheme.darkSurface) : Colors.white,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: AppTheme.borderColor(context),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: AppTheme.borderColor(context),
                      ),
                    ),
                  ),
                ),
              ),

              // Top Class Selector TabBar (Only shown if teacher has > 1 assigned classes)
              if (hasMultipleClasses)
                TabBar(
                  controller: _tabController,
                  indicatorColor: _subjectColor,
                  indicatorWeight: 3,
                  labelColor: isDark ? Colors.white : Colors.black87,
                  unselectedLabelColor: Colors.grey.shade500,
                  indicatorSize: TabBarIndicatorSize.tab,
                  labelStyle: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  unselectedLabelStyle: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                  tabs: classes.map((cls) => Tab(text: cls)).toList(),
                ),
            ],
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
          if (allStudents.isEmpty) {
            return _buildEmptyState();
          }

          if (hasMultipleClasses) {
            return TabBarView(
              controller: _tabController,
              children: classes.map((cls) {
                return _buildClassView(cls, allStudents, isDark);
              }).toList(),
            );
          } else {
            return _buildClassView(classes.first, allStudents, isDark);
          }
        },
      ),
    );
  }

  Widget _buildClassView(
      String className, List<StudentModel> allStudents, bool isDark) {
    final classStudents = _getStudentsForClass(allStudents, className);
    final activeSlot = _selectedSlotByClass[className];

    // Compute distinct hour/schedule batches from students of this class
    final Map<String, int> slotCounts = {};
    for (final s in classStudents) {
      String sch = s.getScheduleForSubject(widget.teacher.subject).trim();
      if (sch.isEmpty) {
        sch = 'Not Scheduled';
      }
      slotCounts[sch] = (slotCounts[sch] ?? 0) + 1;
    }

    // Sort slots logically
    final sortedSlots = slotCounts.keys.toList()
      ..sort((a, b) {
        if (a == 'Not Scheduled') return 1;
        if (b == 'Not Scheduled') return -1;
        return a.compareTo(b);
      });

    // Filter displayed students based on selected slot and search query
    List<StudentModel> displayedStudents = classStudents;
    if (activeSlot != null && activeSlot.isNotEmpty) {
      displayedStudents = displayedStudents
          .where((s) => _matchesSchedule(s, activeSlot))
          .toList();
    }
    displayedStudents = _applySearch(displayedStudents);

    return RefreshIndicator(
      onRefresh: () async {},
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
        children: [
          // ── Section 1: Hourly Batch Cards ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.schedule_rounded, size: 18, color: _subjectColor),
                  const SizedBox(width: 8),
                  Text(
                    'Daily Batches & Hours',
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : AppTheme.primaryDarkBlue,
                    ),
                  ),
                ],
              ),
              if (activeSlot != null)
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedSlotByClass[className] = null;
                    });
                  },
                  child: Text(
                    'Reset Filter',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: _subjectColor,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),

          // Horizontal scroll of compact Hour Cards
          SizedBox(
            height: 84,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                // "All Batches" Card
                _buildHourBatchCard(
                  timeLabel: 'All Batches',
                  subjectLabel: widget.teacher.subject,
                  count: classStudents.length,
                  isSelected: activeSlot == null,
                  isDark: isDark,
                  onTap: () {
                    setState(() {
                      _selectedSlotByClass[className] = null;
                    });
                  },
                ),

                // Cards for each active slot
                ...sortedSlots.map((slot) {
                  final isSelected = activeSlot == slot;
                  final count = slotCounts[slot] ?? 0;
                  return _buildHourBatchCard(
                    timeLabel: slot,
                    subjectLabel: widget.teacher.subject,
                    count: count,
                    isSelected: isSelected,
                    isDark: isDark,
                    onTap: () {
                      setState(() {
                        if (_selectedSlotByClass[className] == slot) {
                          _selectedSlotByClass[className] = null; // Toggle off
                        } else {
                          _selectedSlotByClass[className] = slot;
                        }
                      });
                    },
                  );
                }),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ── Section 2: Active Batch Header ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: _subjectColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _subjectColor.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Icon(
                  activeSlot != null ? Icons.access_time_filled_rounded : Icons.groups_rounded,
                  size: 18,
                  color: _subjectColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    activeSlot != null
                        ? '$className • $activeSlot (${displayedStudents.length} ${displayedStudents.length == 1 ? "student" : "students"})'
                        : '$className • All Batches (${displayedStudents.length} ${displayedStudents.length == 1 ? "student" : "students"})',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _subjectColor,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (activeSlot != null)
                  InkWell(
                    onTap: () => setState(() => _selectedSlotByClass[className] = null),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(2),
                      child: Icon(Icons.close_rounded, size: 16, color: _subjectColor),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // ── Section 3: Student List ──
          if (classStudents.isEmpty)
            _buildEmptyClass(className)
          else if (displayedStudents.isEmpty && _searchQuery.isNotEmpty)
            _buildNoResults()
          else if (displayedStudents.isEmpty)
            _buildNoStudentsInBatch(activeSlot ?? 'selected batch', className)
          else
            ...displayedStudents.asMap().entries.map((entry) {
              final idx = entry.key;
              final student = entry.value;
              return _buildStudentTile(student, idx, isDark);
            }),
        ],
      ),
    );
  }

  Widget _buildHourBatchCard({
    required String timeLabel,
    required String subjectLabel,
    required int count,
    required bool isSelected,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Container(
      width: 154,
      margin: const EdgeInsets.only(right: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isSelected
                  ? _subjectColor
                  : (isDark ? (AppTheme.isAurora(context) ? AppTheme.auroraGlassCard : AppTheme.darkCard) : Colors.white),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected
                    ? _subjectColor
                    : (isDark ? (AppTheme.isAurora(context) ? AppTheme.auroraBorder : AppTheme.darkBorder) : _subjectColor.withValues(alpha: 0.2)),
                width: isSelected ? 2 : 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: isSelected
                      ? _subjectColor.withValues(alpha: 0.3)
                      : Colors.black.withValues(alpha: 0.03),
                  blurRadius: isSelected ? 8 : 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Icon(
                      timeLabel == 'All Batches'
                          ? Icons.groups_rounded
                          : Icons.access_time_rounded,
                      size: 16,
                      color: isSelected ? Colors.white : _subjectColor,
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.white.withValues(alpha: 0.25)
                            : _subjectColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '$count Stud.',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? Colors.white : _subjectColor,
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  timeLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isSelected
                        ? Colors.white
                        : (isDark ? Colors.white : AppTheme.primaryDarkBlue),
                  ),
                ),
                Text(
                  subjectLabel,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: isSelected
                        ? Colors.white.withValues(alpha: 0.85)
                        : Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStudentTile(StudentModel student, int idx, bool isDark) {
    final isPaid = student.isSubjectPaid(widget.teacher.subject);
    final remaining = student.getSubjectRemaining(widget.teacher.subject);
    final schedule = student.getScheduleForSubject(widget.teacher.subject).trim();
    final isAurora = AppTheme.isAurora(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: isAurora ? 0 : 1,
      color: isDark ? (isAurora ? AppTheme.auroraGlassCard : AppTheme.darkCard) : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: isAurora ? const BorderSide(color: AppTheme.auroraBorder) : BorderSide.none,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TeacherStudentDetailScreen(
              student: student,
              teacher: widget.teacher,
            ),
          ),
        ),
        leading: StudentAvatar(
          student: student,
          size: 44,
          isCircle: true,
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
            const SizedBox(height: 2),
            Row(
              children: [
                Text(
                  student.studentCode,
                  style: const TextStyle(
                    fontSize: 11,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (schedule.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: _subjectColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '⏰ $schedule',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: _subjectColor,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            if (student.phone.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                student.phone,
                style: const TextStyle(fontSize: 11, color: AppTheme.lightTextSecondary),
              ),
            ],
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
    ).animate().fadeIn().slideX(begin: 0.03);
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

  Widget _buildEmptyClass(String className) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.people_outline_rounded, size: 56, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text(
              'No Students in $className',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'No students are enrolled in ${widget.teacher.subject} for $className yet.',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoStudentsInBatch(String batch, String className) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.event_busy_rounded, size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text(
              'No Students in this Batch',
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'No students in $className are scheduled for "$batch".',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _selectedSlotByClass[className] = null;
                });
              },
              icon: const Icon(Icons.people_alt_rounded, size: 14),
              style: ElevatedButton.styleFrom(
                backgroundColor: _subjectColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              label: const Text('Show All Batches', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
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
            Icon(Icons.people_outline_rounded, size: 72, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              'No Students Yet',
              style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold),
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
            Icon(Icons.search_off_rounded, size: 72, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              'No Results',
              style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold),
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
            Text('Failed to load students',
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(error,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
