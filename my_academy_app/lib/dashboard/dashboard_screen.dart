import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_theme.dart';
import '../models/student_model.dart';
import '../models/notification_model.dart';
import '../services/notification_service.dart';
import '../screens/notifications_screen.dart';

class _ActivityItem {
  final String title;
  final String subtitle;
  final DateTime time;
  final IconData icon;
  final Color color;

  const _ActivityItem({
    required this.title,
    required this.subtitle,
    required this.time,
    required this.icon,
    required this.color,
  });
}

const Map<String, List<String>> _subjectFilters = {
  'Bio': ['biology', 'bio'],
  'Physics': ['physics'],
  'Chemistry': ['chemistry'],
  'Maths': ['math', 'mathematics'],
  'English': ['english'],
};

const Map<String, Color> _subjectColors = {
  'Bio': Color(0xFF4CAF50),
  'Physics': Color(0xFF2196F3),
  'Chemistry': Color(0xFFFF9800),
  'Maths': Color(0xFF00897B),
  'English': Color(0xFF9C27B0),
};

const List<String> _subjectsList = [
  'Bio',
  'Physics',
  'Chemistry',
  'Maths',
  'English'
];

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _fmt = NumberFormat.currency(symbol: 'Rs', decimalDigits: 0);

  late final Stream<List<StudentModel>> _studentSnapshotStream;

  @override
  void initState() {
    super.initState();
    _studentSnapshotStream =
        FirebaseFirestore.instance.collection('students').snapshots().map(
              (snap) => snap.docs
                  .map((doc) => StudentModel.fromFirestore(doc))
                  .toList(),
            );
  }

  bool _isFsc(String classType) => classType.toLowerCase().contains('fsc');
  bool _isMatric(String classType) =>
      classType.toLowerCase().contains('matric');

  double _sumAmount(List<StudentModel> students, bool collected) {
    return students.fold(0, (total, student) {
      return total + (collected ? student.feeSubmitted : student.feeRemaining);
    });
  }

  Widget _buildGreeting() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Welcome Back,',
          style: GoogleFonts.poppins(
            fontSize: 16,
            color: isDark
                ? AppTheme.darkTextSecondary
                : AppTheme.lightTextSecondary,
          ),
        ),
        Text(
          'Administrator',
          style: GoogleFonts.poppins(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color:
                isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
          ),
        ),
      ],
    ).animate().fadeIn(duration: 600.ms).slideX(begin: -0.1);
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold),
    );
  }

  Widget _buildStatsGrid(List<StudentModel> students) {
    final screenWidth = MediaQuery.of(context).size.width;
    double collected = _sumAmount(students, true);
    double pending = _sumAmount(students, false);

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 3,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: screenWidth < 600 ? 1 : 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: screenWidth < 600 ? 2.8 : 2.2,
      ),
      itemBuilder: (context, index) {
        switch (index) {
          case 0:
            return _buildStatCard(
              'Total Students',
              '${students.length}',
              Icons.school_rounded,
              Colors.blue,
            );
          case 1:
            return _buildStatCard(
              'Collected',
              _fmt.format(collected),
              Icons.payments_rounded,
              Colors.orange,
            );
          default:
            return _buildStatCard(
              'Pending',
              _fmt.format(pending),
              Icons.warning_amber_rounded,
              Colors.red,
            );
        }
      },
    ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1);
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: color,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: isDark
                          ? AppTheme.darkTextSecondary
                          : AppTheme.lightTextSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentStrengthChart(List<StudentModel> students) {
    final fsc1st = students
        .where((s) =>
            _isFsc(s.classType) && s.grade.toLowerCase().contains('first'))
        .length
        .toDouble();
    final fsc2nd = students
        .where((s) =>
            _isFsc(s.classType) && s.grade.toLowerCase().contains('second'))
        .length
        .toDouble();
    final matric9th = students
        .where((s) =>
            _isMatric(s.classType) && s.grade.toLowerCase().contains('ninth'))
        .length
        .toDouble();
    final matric10th = students
        .where((s) =>
            _isMatric(s.classType) && s.grade.toLowerCase().contains('tenth'))
        .length
        .toDouble();

    final maxVal =
        [fsc1st, fsc2nd, matric9th, matric10th].reduce((a, b) => a > b ? a : b);
    final maxY = maxVal > 0 ? maxVal * 1.25 : 10.0;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisSize: MainAxisSize.min,
               // mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Student Strength Breakdown',
                        style: GoogleFonts.poppins(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Active enrollments by class level',
                        style:
                            TextStyle(fontSize: 11, color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${students.length} Total',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryBlue,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxY,
                  barTouchData: BarTouchData(
                    touchCallback: (FlTouchEvent event, barTouchResponse) {
                      if (event is! FlTapUpEvent) {
                        return;
                      }
                      if (barTouchResponse == null ||
                          barTouchResponse.spot == null) {
                        return;
                      }
                      final index = barTouchResponse.spot!.touchedBarGroupIndex;

                      String title = '';
                      String classType = '';
                      String grade = '';
                      if (index == 0) {
                        title = 'FSc 1st Year';
                        classType = 'FSc';
                        grade = 'First Year';
                      } else if (index == 1) {
                        title = 'FSc 2nd Year';
                        classType = 'FSc';
                        grade = 'Second Year';
                      } else if (index == 2) {
                        title = 'Matric 9th Class';
                        classType = 'Matric';
                        grade = 'Ninth';
                      } else if (index == 3) {
                        title = 'Matric 10th Class';
                        classType = 'Matric';
                        grade = 'Tenth';
                      }

                      if (title.isNotEmpty) {
                        showDialog(
                          context: context,
                          builder: (context) => StudentStrengthDetailDialog(
                            title: title,
                            classType: classType,
                            grade: grade,
                            students: students,
                          ),
                        );
                      }
                    },
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (group) =>
                          isDark ? Colors.grey.shade800 : Colors.white,
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        return BarTooltipItem(
                          '${rod.toY.toInt()} Students',
                          TextStyle(
                            color: rod.color,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        getTitlesWidget: (double value, TitleMeta meta) {
                          const style = TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 10);
                          final labels = [
                            '1st Year',
                            '2nd Year',
                            '9th Class',
                            '10th Class'
                          ];
                          final label = (value >= 0 && value < labels.length)
                              ? labels[value.toInt()]
                              : '';
                          return SideTitleWidget(
                              meta: meta,
                              space: 6,
                              child: Text(label, style: style));
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 24,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            value.toInt().toString(),
                            style: TextStyle(
                                color: Colors.grey.shade600, fontSize: 9),
                          );
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: Colors.grey.withValues(alpha: 0.1),
                      strokeWidth: 1,
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: [
                    _barGroup(0, fsc1st, maxY, Colors.blue),
                    _barGroup(1, fsc2nd, maxY, Colors.cyan),
                    _barGroup(2, matric9th, maxY, Colors.indigo),
                    _barGroup(3, matric10th, maxY, Colors.teal),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Legend
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildLegendItem('FSC 1st Yr', Colors.blue),
                _buildLegendItem('FSC 2nd Yr', Colors.cyan),
                _buildLegendItem('Matric 9th', Colors.indigo),
                _buildLegendItem('Matric 10th', Colors.teal),
              ],
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 450.ms).slideY(begin: 0.05);
  }

  BarChartGroupData _barGroup(int x, double y, double maxY, Color color) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: y,
          color: color,
          width: 18,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(6),
            topRight: Radius.circular(6),
          ),
          backDrawRodData: BackgroundBarChartRodData(
            show: true,
            toY: maxY,
            color: Colors.grey.withValues(alpha: 0.05),
          ),
        ),
      ],
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
              fontSize: 9, fontWeight: FontWeight.w600, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildClassRevenueChart(String title, List<StudentModel> students,
      void Function(String metric) onMetricTap) {
    double collected = _sumAmount(students, true);
    double pending = _sumAmount(students, false);
    double total = collected + pending;
    double maxVal = total > 0 ? total : 5000;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: () => onMetricTap('Total'),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color ??
              (isDark ? AppTheme.darkCard : AppTheme.lightCard),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: GoogleFonts.poppins(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text('Tap a bar to open direct breakdown',
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey.shade500)),
                  ],
                ),
                const Icon(Icons.open_in_new_rounded,
                    size: 18, color: Colors.grey),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 180,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxVal * 1.2,
                  barTouchData: BarTouchData(
                    touchCallback: (FlTouchEvent event, barTouchResponse) {
                      if (event is! FlTapUpEvent) return;
                      if (barTouchResponse == null ||
                          barTouchResponse.spot == null) {
                        return;
                      }
                      final index = barTouchResponse.spot!.touchedBarGroupIndex;
                      if (index == 0) onMetricTap('Total');
                      if (index == 1) onMetricTap('Collected');
                      if (index == 2) onMetricTap('Pending');
                    },
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (double value, TitleMeta meta) {
                          const style = TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 11);
                          final labels = ['Total', 'Collected', 'Pending'];
                          final label = (value >= 0 && value < labels.length)
                              ? labels[value.toInt()]
                              : '';
                          return SideTitleWidget(
                              meta: meta,
                              space: 4,
                              child: Text(label, style: style));
                        },
                      ),
                    ),
                    leftTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  barGroups: [
                    _bar(0, total, AppTheme.primaryBlue),
                    _bar(1, collected, Colors.green),
                    _bar(2, pending, Colors.red),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  BarChartGroupData _bar(int x, double y, Color color) => BarChartGroupData(
        x: x,
        barRods: [
          BarChartRodData(
            toY: y,
            color: color,
            width: 14,
            borderRadius: BorderRadius.circular(4),
          )
        ],
      );

  Widget _buildRecentActivityListDirect(List<StudentModel> students) {
    final since = DateTime.now().subtract(const Duration(hours: 24));
    final items = <_ActivityItem>[];

    for (final s in students) {
      if (s.createdAt.isAfter(since)) {
        items.add(_ActivityItem(
          title: 'Student Admission',
          subtitle: '${s.name} registered in ${s.classType} (${s.grade})',
          time: s.createdAt,
          icon: Icons.person_add_rounded,
          color: Colors.blue,
        ));
      }
    }

    // Sort descending by time
    items.sort((a, b) => b.time.compareTo(a.time));

    if (items.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 32),
        alignment: Alignment.center,
        child: Column(
          children: [
            Icon(Icons.inbox_rounded, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 8),
            Text(
              'No activities in the last 24 hours',
              style: TextStyle(color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }

    return Column(
      children: items.map((item) => _buildActivityItem(item)).toList(),
    ).animate().fadeIn(delay: 600.ms);
  }

  Widget _buildActivityItem(_ActivityItem item) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: item.color.withValues(),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(item.icon, color: item.color, size: 24),
        ),
        title: Text(item.title,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(item.subtitle, style: const TextStyle(fontSize: 12)),
        trailing: Text(
          _relativeTime(item.time),
          style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
        ),
      ),
    );
  }

  String _relativeTime(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  void _openDrillDown(
      String title, String classType, List<StudentModel> students,
      {String? initialMetric}) {
    showDialog(
      context: context,
      builder: (context) => RevenueDrillDownDialog(
        title: title,
        classType: classType,
        students: students,
        initialMetric: initialMetric,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Academy Dashboard'),
        actions: [
          StreamBuilder<List<NotificationModel>>(
            stream: NotificationService.notificationsStream(),
            builder: (context, snapshot) {
              final list = snapshot.data ?? NotificationService.getCachedNotifications();
              final unread = list.where((n) => !n.isRead).length;

              return Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_rounded),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const NotificationsScreen()),
                      );
                    },
                  ),
                  if (unread > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.redAccent,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          '$unread',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: StreamBuilder<List<StudentModel>>(
        stream: _studentSnapshotStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error loading dashboard: ${snapshot.error}',
                style: const TextStyle(color: Colors.red),
              ),
            );
          }

          final students = snapshot.data ?? [];

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildGreeting(),
                const SizedBox(height: 24),
                _buildStatsGrid(students),
                const SizedBox(height: 32),
                _buildSectionTitle('Students Strength'),
                const SizedBox(height: 16),
                _buildStudentStrengthChart(students),
                const SizedBox(height: 32),
                _buildSectionTitle('Revenue Overview'),
                const SizedBox(height: 16),
                _buildRevenueChartDirect(students),
                const SizedBox(height: 32),
                _buildSectionTitle('Recent Activities (Last 24 h)'),
                const SizedBox(height: 16),
                _buildRecentActivityListDirect(students),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildRevenueChartDirect(List<StudentModel> students) {
    final fscStudents = students.where((s) => _isFsc(s.classType)).toList();
    final matricStudents =
        students.where((s) => _isMatric(s.classType)).toList();

    return Column(
      children: [
        _buildClassRevenueChart(
          'FSC Revenue',
          fscStudents,
          (metric) => _openDrillDown('FSC Revenue', 'FSc', students,
              initialMetric: metric),
        ),
        const SizedBox(height: 20),
        _buildClassRevenueChart(
          'Matric Revenue',
          matricStudents,
          (metric) => _openDrillDown('Matric Revenue', 'Matric', students,
              initialMetric: metric),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Interactive Drill Down Modal Screen
// ─────────────────────────────────────────────────────────────────────────────
class RevenueDrillDownDialog extends StatefulWidget {
  final String title;
  final String classType;
  final List<StudentModel> students;
  final String? initialMetric;

  const RevenueDrillDownDialog({
    super.key,
    required this.title,
    required this.classType,
    required this.students,
    this.initialMetric,
  });

  @override
  State<RevenueDrillDownDialog> createState() => _RevenueDrillDownDialogState();
}

class _RevenueDrillDownDialogState extends State<RevenueDrillDownDialog> {
  final _fmt = NumberFormat.currency(symbol: 'Rs', decimalDigits: 0);

  String? _selectedMetric;
  String? _selectedGrade;
  String? _selectedSubject;

  @override
  void initState() {
    super.initState();
    _selectedMetric = widget.initialMetric;
  }

  bool _isFsc(String classType) => classType.toLowerCase().contains('fsc');
  bool _isMatric(String classType) =>
      classType.toLowerCase().contains('matric');

  bool _matchesSubject(StudentModel student, String subjectKey) {
    final raw = student.subject.toLowerCase();
    final key = subjectKey == 'Math'
        ? 'Maths'
        : (subjectKey == 'Maths' ? 'Maths' : subjectKey);
    final filters = _subjectFilters[key] ?? [subjectKey.toLowerCase()];
    return filters.any(raw.contains);
  }

  List<StudentModel> _filterStudents({
    required String classType,
    String? grade,
    String? subject,
  }) {
    return widget.students.where((s) {
      final isType =
          classType == 'FSc' ? _isFsc(s.classType) : _isMatric(s.classType);
      if (!isType) return false;

      if (grade != null) {
        if (classType == 'FSc') {
          if (!s.grade
              .toLowerCase()
              .contains(grade.toLowerCase().split(' ').first)) {
            return false;
          }
        } else {
          if (!s.grade
              .toLowerCase()
              .contains(grade.toLowerCase().split(' ').first)) {
            return false;
          }
        }
      }

      if (subject != null) {
        if (!_matchesSubject(s, subject)) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  double _getMetricValue(List<StudentModel> students, String metric) {
    if (metric == 'Total') {
      return _sumAmount(students, true) + _sumAmount(students, false);
    } else if (metric == 'Collected') {
      return _sumAmount(students, true);
    } else {
      return _sumAmount(students, false);
    }
  }

  double _sumAmount(List<StudentModel> students, bool collected) {
    return students.fold(0, (total, student) {
      return total + (collected ? student.feeSubmitted : student.feeRemaining);
    });
  }

  BarChartGroupData _bar(int x, double y, Color color) => BarChartGroupData(
        x: x,
        barRods: [
          BarChartRodData(
            toY: y,
            color: color,
            width: 14,
            borderRadius: BorderRadius.circular(4),
          )
        ],
      );

  @override
  Widget build(BuildContext context) {
    // Determine level layout:
    Widget content;
    String currentSubTitle = '';

    if (_selectedMetric == null) {
      // Level 0: Main total/collected/pending for this class type
      final filtered = _filterStudents(classType: widget.classType);
      double col = _sumAmount(filtered, true);
      double pen = _sumAmount(filtered, false);
      double tot = col + pen;
      double maxVal = tot > 0 ? tot : 5000;
      currentSubTitle = 'Click a bar (Total, Collected, Pending) to drill down';

      content = SizedBox(
        key: const ValueKey('level0'),
        height: 200,
        child: BarChart(
          BarChartData(
            alignment: BarChartAlignment.spaceAround,
            maxY: maxVal * 1.2,
            barTouchData: BarTouchData(
              touchCallback: (FlTouchEvent event, barTouchResponse) {
                if (event is! FlTapUpEvent) {
                  return;
                }
                if (barTouchResponse == null || barTouchResponse.spot == null) {
                  return;
                }
                final index = barTouchResponse.spot!.touchedBarGroupIndex;
                setState(() {
                  if (index == 0) _selectedMetric = 'Total';
                  if (index == 1) _selectedMetric = 'Collected';
                  if (index == 2) _selectedMetric = 'Pending';
                });
              },
            ),
            titlesData: FlTitlesData(
              show: true,
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (double value, TitleMeta meta) {
                    const style =
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 11);
                    final labels = ['Total', 'Collected', 'Pending'];
                    final label = (value >= 0 && value < labels.length)
                        ? labels[value.toInt()]
                        : '';
                    return SideTitleWidget(
                        meta: meta, space: 4, child: Text(label, style: style));
                  },
                ),
              ),
              leftTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            gridData: const FlGridData(show: false),
            borderData: FlBorderData(show: false),
            barGroups: [
              _bar(0, tot, AppTheme.primaryBlue),
              _bar(1, col, Colors.green),
              _bar(2, pen, Colors.red),
            ],
          ),
        ),
      );
    } else if (_selectedGrade == null) {
      // Level 1: Breakdown by Grade
      final isFsc = widget.classType == 'FSc';
      final grade1 = isFsc ? 'First Year' : 'Ninth';
      final grade2 = isFsc ? 'Second Year' : 'Tenth';
      final label1 = isFsc ? 'First Year' : '9th Class';
      final label2 = isFsc ? 'Second Year' : '10th Class';

      final list1 = _filterStudents(classType: widget.classType, grade: grade1);
      final list2 = _filterStudents(classType: widget.classType, grade: grade2);

      double val1 = _getMetricValue(list1, _selectedMetric!);
      double val2 = _getMetricValue(list2, _selectedMetric!);
      double maxVal = (val1 > val2 ? val1 : val2);
      if (maxVal == 0) maxVal = 5000;
      currentSubTitle = '${widget.classType} > $_selectedMetric';

      final metricColor = _selectedMetric == 'Collected'
          ? Colors.green
          : (_selectedMetric == 'Pending' ? Colors.red : AppTheme.primaryBlue);
      final metricColor2 = _selectedMetric == 'Collected'
          ? Colors.green.withValues()
          : (_selectedMetric == 'Pending'
              ? Colors.red.withValues()
              : AppTheme.primaryBlue.withValues());

      content = SizedBox(
        key: const ValueKey('level1'),
        height: 200,
        child: BarChart(
          BarChartData(
            alignment: BarChartAlignment.spaceAround,
            maxY: maxVal * 1.2,
            barTouchData: BarTouchData(
              touchCallback: (FlTouchEvent event, barTouchResponse) {
                if (event is! FlTapUpEvent) {
                  return;
                }
                if (barTouchResponse == null || barTouchResponse.spot == null) {
                  return;
                }
                final index = barTouchResponse.spot!.touchedBarGroupIndex;
                setState(() {
                  if (index == 0) _selectedGrade = grade1;
                  if (index == 1) _selectedGrade = grade2;
                });
              },
            ),
            titlesData: FlTitlesData(
              show: true,
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (double value, TitleMeta meta) {
                    const style =
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 11);
                    final labels = [label1, label2];
                    final label = (value >= 0 && value < labels.length)
                        ? labels[value.toInt()]
                        : '';
                    return SideTitleWidget(
                        meta: meta, space: 4, child: Text(label, style: style));
                  },
                ),
              ),
              leftTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            gridData: const FlGridData(show: false),
            borderData: FlBorderData(show: false),
            barGroups: [
              _bar(0, val1, metricColor),
              _bar(1, val2, metricColor2),
            ],
          ),
        ),
      );
    } else if (_selectedSubject == null) {
      // Level 2: Breakdown by Subject
      final filtered =
          _filterStudents(classType: widget.classType, grade: _selectedGrade);
      final subVals = _subjectsList.map((sub) {
        final list = filtered.where((s) => _matchesSubject(s, sub)).toList();
        return _getMetricValue(list, _selectedMetric!);
      }).toList();

      double maxVal = subVals.reduce((a, b) => a > b ? a : b);
      if (maxVal == 0) maxVal = 5000;
      currentSubTitle =
          '${widget.classType} > $_selectedMetric > $_selectedGrade';

      final baseColor = _selectedMetric == 'Collected'
          ? Colors.green
          : (_selectedMetric == 'Pending' ? Colors.red : AppTheme.primaryBlue);

      content = SizedBox(
        key: const ValueKey('level2'),
        height: 200,
        child: BarChart(
          BarChartData(
            alignment: BarChartAlignment.spaceAround,
            maxY: maxVal * 1.2,
            barTouchData: BarTouchData(
              touchCallback: (FlTouchEvent event, barTouchResponse) {
                if (event is! FlTapUpEvent) {
                  return;
                }
                if (barTouchResponse == null || barTouchResponse.spot == null) {
                  return;
                }
                final index = barTouchResponse.spot!.touchedBarGroupIndex;
                if (index >= 0 && index < _subjectsList.length) {
                  setState(() {
                    _selectedSubject = _subjectsList[index];
                  });
                }
              },
            ),
            titlesData: FlTitlesData(
              show: true,
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (double value, TitleMeta meta) {
                    const style =
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 10);
                    final label = (value >= 0 && value < _subjectsList.length)
                        ? _subjectsList[value.toInt()]
                        : '';
                    return SideTitleWidget(
                        meta: meta, space: 4, child: Text(label, style: style));
                  },
                ),
              ),
              leftTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            gridData: const FlGridData(show: false),
            borderData: FlBorderData(show: false),
            barGroups: List.generate(_subjectsList.length, (idx) {
              final color = baseColor.withValues(alpha: 0.4 + (idx * 0.12));
              return _bar(idx, subVals[idx], color);
            }),
          ),
        ),
      );
    } else {
      // Level 3: Subject Detail View
      final finalStudents = _filterStudents(
        classType: widget.classType,
        grade: _selectedGrade,
        subject: _selectedSubject,
      );
      double col = _sumAmount(finalStudents, true);
      double pen = _sumAmount(finalStudents, false);
      double tot = col + pen;
      currentSubTitle =
          '${widget.classType} > $_selectedMetric > $_selectedGrade > $_selectedSubject';

      List<StudentModel> studentsToShow;
      Widget metricRow;

      if (_selectedMetric == 'Collected') {
        studentsToShow =
            finalStudents.where((s) => s.feeSubmitted > 0).toList();
        metricRow = Row(
          children: [
            _buildDetailMetricCard('Collected Fee', col, Colors.green),
          ],
        );
      } else if (_selectedMetric == 'Pending') {
        studentsToShow =
            finalStudents.where((s) => s.feeRemaining > 0).toList();
        metricRow = Row(
          children: [
            _buildDetailMetricCard('Pending Fee', pen, Colors.red),
          ],
        );
      } else {
        studentsToShow = finalStudents;
        metricRow = Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildDetailMetricCard('Total Fee', tot, AppTheme.primaryBlue),
            _buildDetailMetricCard('Collected', col, Colors.green),
            _buildDetailMetricCard('Pending', pen, Colors.red),
          ],
        );
      }

      content = Column(
        key: const ValueKey('level3'),
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          metricRow,
          const SizedBox(height: 16),
          Text(
            'Students (${studentsToShow.length})',
            style:
                GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          if (studentsToShow.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  _selectedMetric == 'Collected'
                      ? 'No collected fees for this subject'
                      : (_selectedMetric == 'Pending'
                          ? 'No pending fees for this subject'
                          : 'No students in this class/subject'),
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
              ),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 150),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: studentsToShow.length,
                itemBuilder: (context, idx) {
                  final s = studentsToShow[idx];

                  Widget trailingText;
                  if (_selectedMetric == 'Collected') {
                    trailingText = Text(
                      'Rs ${s.feeSubmitted.toStringAsFixed(0)}',
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.green),
                    );
                  } else if (_selectedMetric == 'Pending') {
                    trailingText = Text(
                      'Rs ${s.feeRemaining.toStringAsFixed(0)}',
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.red),
                    );
                  } else {
                    final isPaid = s.feeRemaining <= 0;
                    trailingText = Text(
                      isPaid
                          ? 'PAID'
                          : 'Rs ${s.feeRemaining.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isPaid ? Colors.green : Colors.red,
                      ),
                    );
                  }

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            s.name,
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w500),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        trailingText,
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      );
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: GoogleFonts.poppins(
                            fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      if (currentSubTitle.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          currentSubTitle,
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ]
                    ],
                  ),
                ),
                if (_selectedMetric != null)
                  IconButton(
                    onPressed: () {
                      setState(() {
                        if (_selectedSubject != null) {
                          _selectedSubject = null;
                        } else if (_selectedGrade != null) {
                          _selectedGrade = null;
                        } else {
                          _selectedMetric = null;
                        }
                      });
                    },
                    icon: const Icon(Icons.arrow_back_rounded),
                    tooltip: 'Back',
                  )
                else
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            AnimatedSwitcher(
              duration: 250.ms,
              child: content,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailMetricCard(String label, double amount, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(
              _fmt.format(amount),
              style: GoogleFonts.poppins(
                  fontSize: 12, fontWeight: FontWeight.bold, color: color),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Interactive Student Strength Breakdown Dialog
// ─────────────────────────────────────────────────────────────────────────────
class StudentStrengthDetailDialog extends StatefulWidget {
  final String title;
  final String classType;
  final String grade;
  final List<StudentModel> students;

  const StudentStrengthDetailDialog({
    super.key,
    required this.title,
    required this.classType,
    required this.grade,
    required this.students,
  });

  @override
  State<StudentStrengthDetailDialog> createState() =>
      _StudentStrengthDetailDialogState();
}

class _StudentStrengthDetailDialogState
    extends State<StudentStrengthDetailDialog> {
  String? _selectedSubject;

  bool _matchesSubject(StudentModel student, String subjectKey) {
    final raw = student.subject.toLowerCase();
    final key = subjectKey == 'Math'
        ? 'Maths'
        : (subjectKey == 'Maths' ? 'Maths' : subjectKey);
    final filters = _subjectFilters[key] ?? [subjectKey.toLowerCase()];
    return filters.any(raw.contains);
  }

  @override
  Widget build(BuildContext context) {
    final filtered = widget.students.where((s) {
      final isFsc = widget.classType.toLowerCase().contains('fsc');
      final isType = isFsc
          ? s.classType.toLowerCase().contains('fsc')
          : s.classType.toLowerCase().contains('matric');
      if (!isType) return false;
      return s.grade
          .toLowerCase()
          .contains(widget.grade.toLowerCase().split(' ').first);
    }).toList();

    final Map<String, int> subjectCounts = {};
    int maxCount = 0;
    for (final sub in _subjectsList) {
      final count = filtered.where((s) => _matchesSubject(s, sub)).length;
      subjectCounts[sub] = count;
      if (count > maxCount) maxCount = count;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 450),
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SingleChildScrollView(
                  
                   
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.title,
                              style: GoogleFonts.poppins(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Class Strength Breakdown',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey.shade500),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${filtered.length} Students',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryBlue,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // Subjects breakdown list
              ..._subjectsList.map((sub) {
                final count = subjectCounts[sub] ?? 0;
                final pct = maxCount > 0 ? count / maxCount : 0.0;
                final color = _subjectColors[sub] ?? Colors.blue;
                final isSelected = _selectedSubject == sub;

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        if (_selectedSubject == sub) {
                          _selectedSubject = null;
                        } else {
                          _selectedSubject = sub;
                        }
                      });
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 8, horizontal: 10),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? color.withValues(alpha: 0.08)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? color.withValues(alpha: 0.3)
                              : Colors.transparent,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: color,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    sub,
                                    style: GoogleFonts.poppins(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                '$count ${count == 1 ? 'Student' : 'Students'}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isDark
                                      ? Colors.grey.shade300
                                      : Colors.grey.shade700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Stack(
                            children: [
                              Container(
                                height: 6,
                                decoration: BoxDecoration(
                                  color: Colors.grey.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                              AnimatedContainer(
                                duration: 300.ms,
                                height: 6,
                                width: pct > 0
                                    ? (MediaQuery.of(context).size.width *
                                        0.55 *
                                        pct)
                                    : 0,
                                constraints:
                                    const BoxConstraints(maxWidth: 240),
                                decoration: BoxDecoration(
                                  color: color,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),

              // Selected Subject Student List
              if (_selectedSubject != null) ...[
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                Text(
                  'Enrolled in $_selectedSubject',
                  style: GoogleFonts.poppins(
                      fontSize: 13, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Builder(
                  builder: (context) {
                    final list = filtered
                        .where((s) => _matchesSubject(s, _selectedSubject!))
                        .toList();
                    if (list.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          'No students enrolled',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade500),
                        ),
                      );
                    }
                    return ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 120),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: list.length,
                        itemBuilder: (context, idx) {
                          final s = list[idx];
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Text(
                              '•  ${s.name}',
                              style: const TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w500),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ],
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
