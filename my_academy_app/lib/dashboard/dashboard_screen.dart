import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/database_service.dart';
import '../theme/app_theme.dart';
import '../models/student_model.dart';

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

class ExplorerNode {
  final String id;
  final String title;
  final String trailingLabel;
  final bool isCurrency;
  final IconData? icon;
  final Color? iconColor;
  final List<ExplorerNode> children;

  const ExplorerNode({
    required this.id,
    required this.title,
    required this.trailingLabel,
    this.isCurrency = false,
    this.icon,
    this.iconColor,
    this.children = const [],
  });

  bool get hasChildren => children.isNotEmpty;
}

const Map<String, List<String>> _subjectFilters = {
  'Bio': ['biology', 'bio'],
  'Physics': ['physics'],
  'Chemistry': ['chemistry'],
  'Maths': ['math', 'mathematics'],
  'English': ['english'],
};

const Map<String, IconData> _subjectIcons = {
  'Bio': Icons.biotech_rounded,
  'Physics': Icons.science_rounded,
  'Chemistry': Icons.colorize_rounded,
  'Maths': Icons.calculate_rounded,
  'English': Icons.menu_book_rounded,
};

const Map<String, Color> _subjectColors = {
  'Bio': Color(0xFF4CAF50),
  'Physics': Color(0xFF2196F3),
  'Chemistry': Color(0xFFFF9800),
  'Maths': Color(0xFF00897B),
  'English': Color(0xFF9C27B0),
};

const List<String> _matricGradeLevels = ['9th Class', '10th Class'];

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _isRefreshing = false;
  final _fmt = NumberFormat.currency(symbol: 'Rs', decimalDigits: 0);
  final Map<String, bool> _expandedNodes = {};

  Stream<List<StudentModel>> get _studentSnapshotStream =>
      FirebaseFirestore.instance.collection('students').snapshots().map(
            (snap) => snap.docs
                .map((doc) => StudentModel.fromMap(
                    doc.data(), doc.id))
                .toList(),
          );

  bool _isExpanded(String nodeId) => _expandedNodes[nodeId] ?? false;

  void _toggleExpanded(String nodeId) {
    setState(() {
      _expandedNodes[nodeId] = !(_expandedNodes[nodeId] ?? false);
    });
  }

  void _setAllExpanded(ExplorerNode root, bool expanded) {
    void recurse(ExplorerNode node) {
      _expandedNodes[node.id] = expanded;
      for (final child in node.children) {
        recurse(child);
      }
    }

    setState(() {
      recurse(root);
    });
  }

  Future<void> _refreshData() async {
    setState(() => _isRefreshing = true);
    await DatabaseService.syncFromFirestore();
    if (mounted) setState(() => _isRefreshing = false);
  }

  void _showFscDetails(List<StudentModel> students) {
    final fscStudents = students.where((s) => _isFsc(s.classType)).toList();
    _showDetailsBottomSheet('FSC Subjects Breakdown', _buildSubjectBreakdown(fscStudents));
  }

  void _showMatricDetails(List<StudentModel> students) {
    final matricStudents = students.where((s) => _isMatric(s.classType)).toList();
    _showDetailsBottomSheet('Matric Classes Breakdown', Column(
      children: _matricGradeLevels.map((grade) {
        final gradeStudents = matricStudents.where((s) => s.grade.contains(grade.split(' ').first)).toList();
        return _buildDetailTile(
          title: grade,
          students: gradeStudents,
          icon: Icons.folder_open_rounded,
          iconColor: const Color(0xFF2E7D32),
          onTap: () {
            Navigator.pop(context);
            _showGradeDetails(grade, gradeStudents);
          },
        );
      }).toList(),
    ));
  }

  void _showGradeDetails(String grade, List<StudentModel> students) {
    _showDetailsBottomSheet('$grade Subjects Breakdown', _buildSubjectBreakdown(students));
  }

  void _showDetailsBottomSheet(String title, Widget content) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(title, style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
                ],
              ),
            ),
            const Divider(),
            Expanded(child: SingleChildScrollView(padding: const EdgeInsets.all(20), child: content)),
          ],
        ),
      ),
    );
  }

  Widget _buildSubjectBreakdown(List<StudentModel> students) {
    const subjects = ['Bio', 'Physics', 'Chemistry', 'Maths', 'English'];
    return Column(
      children: subjects.map((sub) {
        final subStudents = students.where((s) => _matchesSubject(s, sub)).toList();
        return _buildDetailTile(
          title: sub,
          students: subStudents,
          icon: _subjectIcons[sub] ?? Icons.book_rounded,
          iconColor: _subjectColors[sub] ?? AppTheme.primaryBlue,
        );
      }).toList(),
    );
  }

  Widget _buildDetailTile({
    required String title,
    required List<StudentModel> students,
    required IconData icon,
    required Color iconColor,
    VoidCallback? onTap,
  }) {
    double collected = _sumAmount(students, true);
    double pending = _sumAmount(students, false);
    double total = collected + pending;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                    child: Icon(icon, color: iconColor, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold)),
                        Text('${students.length} Registered Students', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                      ],
                    ),
                  ),
                  if (onTap != null) const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildMiniStat('Total', total, AppTheme.primaryBlue),
                  _buildMiniStat('Collected', collected, Colors.green),
                  _buildMiniStat('Pending', pending, Colors.red),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMiniStat(String label, double amount, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
        Text(_fmt.format(amount), style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  bool _isFsc(String classType) => classType.toLowerCase().contains('fsc');
  bool _isMatric(String classType) =>
      classType.toLowerCase().contains('matric');

  bool _matchesSubject(StudentModel student, String subjectKey) {
    final raw = student.subject.toLowerCase();
    final filters = _subjectFilters[subjectKey]!;
return filters.any(raw.contains);
  }

  String _formatCurrency(double amount) => _fmt.format(amount);

  ExplorerNode _buildGradeTree(List<StudentModel> students) {
    final fscStudents = students.where((s) => _isFsc(s.classType)).toList();
    final matricStudents =
        students.where((s) => _isMatric(s.classType)).toList();

    final fscNode = ExplorerNode(
      id: 'grade_fsc',
      title: 'FSC Students',
      trailingLabel: '${fscStudents.length}',
      icon: Icons.school_rounded,
      iconColor: const Color(0xFF1565C0),
      children: _buildFscGradeChildren(fscStudents),
    );

    final matricNode = ExplorerNode(
      id: 'grade_matric',
      title: 'Matric Students',
      trailingLabel: '${matricStudents.length}',
      icon: Icons.auto_stories_rounded,
      iconColor: const Color(0xFF2E7D32),
      children: _buildMatricGradeChildren(matricStudents),
    );

    return ExplorerNode(
      id: 'grade_total',
      title: 'Total Students',
      trailingLabel: '${students.length}',
      icon: Icons.folder_rounded,
      iconColor: AppTheme.primaryBlue,
      children: [fscNode, matricNode],
    );
  }

  List<ExplorerNode> _buildFscGradeChildren(List<StudentModel> students) {
    const subjects = ['Bio', 'Physics', 'Chemistry', 'Maths', 'English'];
    return subjects.map((subject) {
      final subjectList =
          students.where((s) => _matchesSubject(s, subject)).toList();
      return ExplorerNode(
        id: 'grade_fsc_$subject',
        title: subject,
        trailingLabel: '${subjectList.length}',
        icon: _subjectIcons[subject],
        iconColor: _subjectColors[subject],
        children: [
          ExplorerNode(
            id: 'grade_fsc_${subject}_first',
            title: '1st Year $subject Students',
            trailingLabel:
                "${subjectList.where((s) => s.grade.toLowerCase().contains('first')).length}",
            icon: Icons.folder_open_rounded,
            iconColor: _subjectColors[subject]?.withValues(alpha: 0.7),
          ),
          ExplorerNode(
            id: 'grade_fsc_${subject}_second',
            title: '2nd Year $subject Students',
            trailingLabel:
                "${subjectList.where((s) => s.grade.toLowerCase().contains('second')).length}",
            icon: Icons.folder_open_rounded,
            iconColor: _subjectColors[subject]?.withValues(alpha: 0.7),
          ),
        ],
      );
    }).toList();
  }

  List<ExplorerNode> _buildMatricGradeChildren(List<StudentModel> students) {
    return _matricGradeLevels.map((gradeLabel) {
      final classList = students
          .where((s) => s.grade
              .toLowerCase()
              .contains(gradeLabel.toLowerCase().split(' ').first))
          .toList();
      return ExplorerNode(
        id: 'grade_matric_${gradeLabel.replaceAll(' ', '_')}',
        title: gradeLabel,
        trailingLabel: '${classList.length}',
        icon: Icons.folder_open_rounded,
        iconColor: const Color(0xFF2E7D32).withValues(alpha: 0.7),
        children: ['Bio', 'Physics', 'Chemistry', 'Maths', 'English'].map((subject) {
          final subjectList =
              classList.where((s) => _matchesSubject(s, subject)).toList();
          return ExplorerNode(
            id: 'grade_matric_${gradeLabel.replaceAll(' ', '_')}_$subject',
            title: subject,
            trailingLabel: '${subjectList.length}',
            icon: _subjectIcons[subject],
            iconColor: _subjectColors[subject],
          );
        }).toList(),
      );
    }).toList();
  }

  ExplorerNode _buildAmountTree(
    List<StudentModel> students,
    String rootId,
    String rootTitle,
    bool collected,
  ) {
    final fscStudents = students.where((s) => _isFsc(s.classType)).toList();
    final matricStudents =
        students.where((s) => _isMatric(s.classType)).toList();

    final fscNode = ExplorerNode(
      id: '${rootId}_fsc',
      title: 'FSC',
      trailingLabel: _formatCurrency(_sumAmount(fscStudents, collected)),
      isCurrency: true,
      icon: Icons.school_rounded,
      iconColor: const Color(0xFF1565C0),
      children: _buildFscAmountChildren(fscStudents, collected),
    );

    final matricNode = ExplorerNode(
      id: '${rootId}_matric',
      title: 'Matric',
      trailingLabel: _formatCurrency(_sumAmount(matricStudents, collected)),
      isCurrency: true,
      icon: Icons.auto_stories_rounded,
      iconColor: const Color(0xFF2E7D32),
      children: _buildMatricAmountChildren(matricStudents, collected),
    );

    return ExplorerNode(
      id: rootId,
      title: rootTitle,
      trailingLabel: _formatCurrency(_sumAmount(students, collected)),
      isCurrency: true,
      icon: Icons.folder_rounded,
      iconColor: AppTheme.primaryBlue,
      children: [fscNode, matricNode],
    );
  }

  List<ExplorerNode> _buildFscAmountChildren(
      List<StudentModel> students, bool collected) {
    const subjects = ['Bio', 'Physics', 'Chemistry', 'Maths', 'English'];
    return subjects.map((subject) {
      final subjectList =
          students.where((s) => _matchesSubject(s, subject)).toList();
      final firstYearSum = _sumAmount(
          subjectList
              .where((s) => s.grade.toLowerCase().contains('first'))
              .toList(),
          collected);
      final secondYearSum = _sumAmount(
          subjectList
              .where((s) => s.grade.toLowerCase().contains('second'))
              .toList(),
          collected);
      return ExplorerNode(
        id: 'amount_fsc_$subject',
        title: subject,
        trailingLabel: _formatCurrency(_sumAmount(subjectList, collected)),
        isCurrency: true,
        icon: _subjectIcons[subject],
        iconColor: _subjectColors[subject],
        children: [
          ExplorerNode(
            id: 'amount_fsc_${subject}_first',
            title: '1st Year $subject',
            trailingLabel: _formatCurrency(firstYearSum),
            isCurrency: true,
            icon: Icons.folder_open_rounded,
            iconColor: _subjectColors[subject]?.withValues(alpha: 0.7),
          ),
          ExplorerNode(
            id: 'amount_fsc_${subject}_second',
            title: '2nd Year $subject',
            trailingLabel: _formatCurrency(secondYearSum),
            isCurrency: true,
            icon: Icons.folder_open_rounded,
            iconColor: _subjectColors[subject]?.withValues(alpha: 0.7),
          ),
        ],
      );
    }).toList();
  }

  List<ExplorerNode> _buildMatricAmountChildren(
      List<StudentModel> students, bool collected) {
    return _matricGradeLevels.map((gradeLabel) {
      final classList = students
          .where((s) => s.grade
              .toLowerCase()
              .contains(gradeLabel.toLowerCase().split(' ').first))
          .toList();
      return ExplorerNode(
        id: 'amount_matric_${gradeLabel.replaceAll(' ', '_')}',
        title: gradeLabel,
        trailingLabel: _formatCurrency(_sumAmount(classList, collected)),
        isCurrency: true,
        icon: Icons.folder_open_rounded,
        iconColor: const Color(0xFF2E7D32).withValues(alpha: 0.7),
        children:
            ['Bio', 'Physics', 'Chemistry', 'Maths', 'English'].map((subject) {
          final subjectList =
              classList.where((s) => _matchesSubject(s, subject)).toList();
          return ExplorerNode(
            id: 'amount_matric_${gradeLabel.replaceAll(' ', '_')}_$subject',
            title: subject,
            trailingLabel: _formatCurrency(_sumAmount(subjectList, collected)),
            isCurrency: true,
            icon: _subjectIcons[subject],
            iconColor: _subjectColors[subject],
          );
        }).toList(),
      );
    }).toList();
  }

  double _sumAmount(List<StudentModel> students, bool collected) {
    return students.fold(0, (total, student) {
      return total + (collected ? student.feeSubmitted : student.feeRemaining);
    });
  }

  Widget _buildExplorerSection(String title, ExplorerNode root) {
    return Card(
      margin: const EdgeInsets.only(bottom: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(title,
                      style: GoogleFonts.poppins(
                          fontSize: 18, fontWeight: FontWeight.w600)),
                ),
                TextButton(
                  onPressed: () => _setAllExpanded(root, true),
                  child: const Text('Expand All'),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => _setAllExpanded(root, false),
                  child: const Text('Collapse All'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildTreeNode(root),
          ],
        ),
      ),
    );
  }

  Widget _buildTreeNode(ExplorerNode node, {int depth = 0}) {
    final isExpandable = node.hasChildren;
    final nodeId = node.id;
    final expanded = _isExpanded(nodeId);

    return Column(
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: isExpandable ? () => _toggleExpanded(nodeId) : null,
          child: Container(
            padding: EdgeInsets.fromLTRB(12 + depth * 16, 12, 12, 12),
            decoration: BoxDecoration(
              color: depth == 0 ? Colors.transparent : null,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(
                  node.icon ?? (isExpandable
                      ? (expanded ? Icons.folder_open_rounded : Icons.folder_rounded)
                      : Icons.description_rounded),
                  color: node.iconColor ?? (depth == 0 ? AppTheme.primaryBlue : Colors.grey),
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(node.title,
                          style: GoogleFonts.poppins(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: depth == 0 ? null : null)),
                      if (depth > 0 && isExpandable) const SizedBox(height: 2),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: node.isCurrency
                        ? AppTheme.primaryBlue.withValues(alpha: 0.1)
                        : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(node.trailingLabel,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: node.isCurrency
                            ? AppTheme.primaryBlue
                            : Colors.black87,
                      )),
                ),
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: 200.ms,
          curve: Curves.easeInOut,
          child: Column(
            children: expanded
                ? node.children
                    .map((child) => _buildTreeNode(child, depth: depth + 1))
                    .toList()
                : const [],
          ),
        ),
      ],
    );
  }

  Widget _buildGradeExplorer() {
    return StreamBuilder<List<StudentModel>>(
      stream: _studentSnapshotStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text('Unable to load grade view: ${snapshot.error}',
                style: const TextStyle(color: Colors.red)),
          );
        }

        final students = snapshot.data ?? [];
        final gradeTree = _buildGradeTree(students);
        final collectedTree = _buildAmountTree(
            students, 'collected_amount', 'Collected Amount', true);
        final pendingTree = _buildAmountTree(
            students, 'pending_amount', 'Pending Amount', false);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildExplorerSection('Students Strength', gradeTree),
            _buildExplorerSection('Collected Amount', collectedTree),
            _buildExplorerSection('Pending Amount', pendingTree),
          ],
        );
      },
    );
  }

  Future<List<_ActivityItem>> _fetchRecentActivities() async {
    final since = Timestamp.fromDate(
      DateTime.now().subtract(const Duration(hours: 24)),
    );
    final items = <_ActivityItem>[];

    try {
      final snap = await FirebaseFirestore.instance
          .collection('students')
          .where('createdAt', isGreaterThanOrEqualTo: since)
          .orderBy('createdAt', descending: true)
          .get();

      for (final doc in snap.docs) {
        final d = doc.data();
        final ts = d['createdAt'];
        final firstName = d['firstName'] ?? '';
        final lastName = d['lastName'] ?? '';
        final fullName = '$firstName $lastName'.trim().isNotEmpty
            ? '$firstName $lastName'.trim()
            : (d['name'] ?? 'Unknown');
        items.add(_ActivityItem(
          title: 'Student Admission',
          subtitle:
              '$fullName registered in ${d['classType'] ?? ''} (${d['grade'] ?? ''})',
          time: ts is Timestamp ? ts.toDate() : DateTime.now(),
          icon: Icons.person_add_rounded,
          color: Colors.blue,
        ));
      }
    } catch (_) {}

    try {
      final snap = await FirebaseFirestore.instance
          .collection('fees')
          .where('createdAt', isGreaterThanOrEqualTo: since)
          .orderBy('createdAt', descending: true)
          .get();

      for (final doc in snap.docs) {
        final d = doc.data();
        final ts = d['createdAt'];
        items.add(_ActivityItem(
          title: 'Fee Payment',
          subtitle:
              '${d['studentName'] ?? 'Unknown'} paid Rs ${d['amount'] ?? 0}',
          time: ts is Timestamp ? ts.toDate() : DateTime.now(),
          icon: Icons.payments_rounded,
          color: Colors.green,
        ));
      }
    } catch (_) {}

    items.sort((a, b) => b.time.compareTo(a.time));
    return items;
  }

  String _relativeTime(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Academy Dashboard'),
        actions: [
          IconButton(
            onPressed: _refreshData,
            icon: _isRefreshing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2),
                  )
                : const Icon(Icons.sync),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildGreeting(),
            const SizedBox(height: 24),
            _buildStatsGrid(),
            const SizedBox(height: 32),
            _buildSectionTitle('Students & Fee Explorer'),
            const SizedBox(height: 16),
            _buildGradeExplorer(),
            const SizedBox(height: 32),
            _buildSectionTitle('Revenue Overview'),
            const SizedBox(height: 16),
            _buildRevenueChart(),
            const SizedBox(height: 32),
            _buildSectionTitle('Recent Activities (Last 24 h)'),
            const SizedBox(height: 16),
            _buildRecentActivityList(),
          ],
        ),
      ),
    );
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

  /*Widget _buildStatsGrid() {
    final w = MediaQuery.of(context).size.width;
    return Center(
      child: Container(
        width: w * 0.5,
        constraints: const BoxConstraints(maxWidth: 400, minWidth: 280),
        child: GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 12, 
          mainAxisSpacing: 12,  
          childAspectRatio: 2.1, 
          
          children: [
            _buildStatCard('Total Students', '${DatabaseService.totalStudents}',
                Icons.school_rounded, Colors.blue),
            _buildStatCard(
                'Collected',
                _fmt.format(DatabaseService.totalFeesCollected),
                Icons.payments_rounded,
                Colors.orange),
            _buildStatCard(
                'Pending',
                _fmt.format(DatabaseService.totalPendingFees),
                Icons.warning_amber_rounded,
                Colors.red),
          ],
        ),
      ),
    ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1);
  }*/
Widget _buildStatsGrid() {
  final screenWidth = MediaQuery.of(context).size.width;

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
            '${DatabaseService.totalStudents}',
            Icons.school_rounded,
            Colors.blue,
          );

        case 1:
          return _buildStatCard(
            'Collected',
            _fmt.format(DatabaseService.totalFeesCollected),
            Icons.payments_rounded,
            Colors.orange,
          );

        default:
          return _buildStatCard(
            'Pending',
            _fmt.format(DatabaseService.totalPendingFees),
            Icons.warning_amber_rounded,
            Colors.red,
          );
      }
    },
  ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1);
}
  /*Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    style: GoogleFonts.poppins(
                        fontSize: 18, fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                Text(title,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: isDark
                          ? AppTheme.darkTextSecondary
                          : AppTheme.lightTextSecondary,
                    )),
              ],
            ),
          ],
        ),
      ),
    );
  }*/
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

  Widget _buildRevenueChart() {
    return StreamBuilder<List<StudentModel>>(
      stream: _studentSnapshotStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final students = snapshot.data ?? [];
        final fscStudents = students.where((s) => _isFsc(s.classType)).toList();
        final matricStudents =
            students.where((s) => _isMatric(s.classType)).toList();

        return Column(
          children: [
            _buildClassRevenueChart('FSC Revenue', fscStudents, () => _showFscDetails(students)),
            const SizedBox(height: 20),
            _buildClassRevenueChart('Matric Revenue', matricStudents, () => _showMatricDetails(students)),
          ],
        );
      },
    );
  }

  Widget _buildClassRevenueChart(String title, List<StudentModel> students, VoidCallback onTap) {
    double collected = _sumAmount(students, true);
    double pending = _sumAmount(students, false);
    double total = collected + pending;

    double maxVal = total > 0 ? total : 5000;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color ??
              (isDark ? AppTheme.darkCard : AppTheme.lightCard),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
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
                Text(title, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold)),
                const Icon(Icons.open_in_new_rounded, size: 18, color: Colors.grey),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 180,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxVal * 1.2,
                  barTouchData: BarTouchData(enabled: false),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (double value, TitleMeta meta) {
                          const style = TextStyle(fontWeight: FontWeight.bold, fontSize: 11);
                          final labels = ['Total', 'Collected', 'Pending'];
                          final label = (value >= 0 && value < labels.length) ? labels[value.toInt()] : '';
                          return SideTitleWidget(meta: meta, space: 4, child: Text(label, style: style));
                        },
                      ),
                    ),
                    leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
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
            width: 14, // ✅ FIXED: was 18, now 14 so 5 bars fit nicely
            borderRadius: BorderRadius.circular(4),
          )
        ],
      );

  Widget _buildRecentActivityList() {
    return FutureBuilder<List<_ActivityItem>>(
      future: _fetchRecentActivities(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text('Could not load activities: ${snapshot.error}',
                  style: const TextStyle(color: Colors.red)),
            ),
          );
        }

        final items = snapshot.data ?? [];

        if (items.isEmpty) {
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 32),
            alignment: Alignment.center,
            child: Column(
              children: [
                Icon(Icons.inbox_rounded,
                    size: 48, color: Colors.grey.shade400),
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
      },
    );
  }

  Widget _buildActivityItem(_ActivityItem item) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: item.color.withValues(alpha: 0.1),
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
}
