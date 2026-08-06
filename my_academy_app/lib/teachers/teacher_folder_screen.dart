import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'fsc_teacher_screen.dart';
import 'matric_teacher_screen.dart';
import '../screens/fee_reminders_screen.dart';
import '../services/database_service.dart';
import '../services/sync_service.dart';
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
// Class Item Metadata
// ─────────────────────────────────────────────────────────────────────────────
class ClassItem {
  final String classType;
  final String subject;
  final String grade;
  final IconData icon;
  final Color color;

  ClassItem({
    required this.classType,
    required this.subject,
    required this.grade,
    required this.icon,
    required this.color,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Level 0 — Tabbed list of FSc and Matric subject-years
// ─────────────────────────────────────────────────────────────────────────────
class TeacherFolderScreen extends StatefulWidget {
  const TeacherFolderScreen({super.key});

  @override
  State<TeacherFolderScreen> createState() => _TeacherFolderScreenState();
}

class _TeacherFolderScreenState extends State<TeacherFolderScreen> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  List<ClassItem> _getClasses(String classType) {
    final List<ClassItem> items = [];
    final grades = kGrades[classType] ?? [];
    for (final subject in kSubjects) {
      for (final grade in grades) {
        items.add(ClassItem(
          classType: classType,
          subject: subject,
          grade: grade,
          icon: kSubjectIcons[subject] ?? Icons.book_rounded,
          color: kSubjectColors[subject] ?? AppTheme.primaryBlue,
        ));
      }
    }
    return items;
  }

  String _getClassSchedule(String classType, String subject, String grade) {
    final students = DatabaseService.getStudentsByClass(
      classType: classType,
      subject: subject,
      grade: grade,
    );
    if (students.isEmpty) {
      return 'Not Scheduled';
    }
    final schedules = students
        .map((s) => s.getScheduleForSubject(subject))
        .where((sch) => sch.isNotEmpty)
        .toList();
    if (schedules.isEmpty) {
      return 'Not Scheduled';
    }
    final counts = <String, int>{};
    for (final sch in schedules) {
      counts[sch] = (counts[sch] ?? 0) + 1;
    }
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.first.key;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Listen to SyncService so that this screen rebuilds on real-time sync updates
    Provider.of<SyncService>(context);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'Teachers',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              fontSize: 22,
            ),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(115),
            child: Column(
              children: [
                // Global Search Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (val) {
                        setState(() {
                          _searchQuery = val;
                        });
                      },
                      style: const TextStyle(fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Search subject or year (e.g. Physics First)...',
                        hintStyle: TextStyle(color: Colors.grey.shade500),
                        prefixIcon: Icon(Icons.search_rounded, color: Colors.grey.shade600),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: Icon(Icons.clear_rounded, color: Colors.grey.shade600),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {
                                    _searchQuery = '';
                                  });
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ),
                // Tabs
                TabBar(
                  indicatorColor: AppTheme.primaryBlue,
                  labelColor: AppTheme.primaryBlue,
                  unselectedLabelColor: Colors.grey.shade600,
                  indicatorSize: TabBarIndicatorSize.tab,
                  labelStyle: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  unselectedLabelStyle: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                  tabs: const [
                    Tab(text: 'FSc Classes'),
                    Tab(text: 'Matric Classes'),
                  ],
                ),
              ],
            ),
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const FeeRemindersScreen()),
            );
          },
          backgroundColor: const Color(0xFF25D366),
          foregroundColor: Colors.white,
          tooltip: 'Fee Reminders',
          child: const Icon(Icons.message_rounded),
        ),
        body: TabBarView(
          children: [
            _buildTabContent('FSc'),
            _buildTabContent('Matric'),
          ],
        ),
      ),
    );
  }

  Widget _buildTabContent(String classType) {
    final allItems = _getClasses(classType);
    final filteredItems = allItems.where((item) {
      if (_searchQuery.isEmpty) return true;
      final tokens = _searchQuery.toLowerCase().split(' ').where((t) => t.isNotEmpty);
      final target = '${item.classType} ${item.subject} ${item.grade}'.toLowerCase();
      return tokens.every((token) => target.contains(token));
    }).toList();

    if (filteredItems.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.search_off_rounded, size: 64, color: Colors.grey.shade300),
              const SizedBox(height: 16),
              Text(
                'No classes found',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Try a different subject or year search query',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
              ),
            ],
          ),
        ),
      ).animate().fadeIn();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 320,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.35,
          ),
          itemCount: filteredItems.length,
          itemBuilder: (context, index) {
            final item = filteredItems[index];
            final students = DatabaseService.getStudentsByClass(
              classType: item.classType,
              subject: item.subject,
              grade: item.grade,
            );
            final studentCount = students.length;
            final nextClassTime = _getClassSchedule(item.classType, item.subject, item.grade);

            return Card(
              elevation: 0,
              margin: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: item.color.withValues(alpha: 0.15), width: 1.5),
              ),
              color: item.color.withValues(alpha: 0.05),
              child: InkWell(
                onTap: () {
                  if (item.classType == 'FSc') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => FscClassRoomScreen(
                          subject: item.subject,
                          grade: item.grade,
                        ),
                      ),
                    );
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MatricClassRoomScreen(
                          subject: item.subject,
                          grade: item.grade,
                        ),
                      ),
                    );
                  }
                },
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: item.color.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(item.icon, color: item.color, size: 24),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: (item.classType == 'FSc' ? Colors.blue : Colors.green).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              item.classType,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: item.classType == 'FSc' ? Colors.blue.shade700 : Colors.green.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Text(
                        item.subject,
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      Text(
                        item.grade,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Spacer(),
                      const Divider(height: 12, thickness: 0.5),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.people_outline_rounded, size: 14, color: Colors.grey.shade600),
                              const SizedBox(width: 4),
                              Text(
                                '$studentCount Stud.',
                                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                          Expanded(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Icon(Icons.schedule_rounded, size: 14, color: Colors.grey.shade600),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    nextClassTime,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade600,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ).animate().fadeIn(delay: (index * 40).ms).slideY(begin: 0.05);
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared Folder Card Widget (Retained for backwards-compatibility)
// ─────────────────────────────────────────────────────────────────────────────
class FolderCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> gradient;
  final VoidCallback onTap;

  const FolderCard({
    super.key,
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
                color: gradient.first.withValues(alpha: 0.25),
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
                  color: Colors.white.withValues(alpha: 0.2),
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
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: Colors.white.withValues(alpha: 0.7),
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
