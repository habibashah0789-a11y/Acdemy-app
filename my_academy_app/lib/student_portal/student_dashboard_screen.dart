import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/student_model.dart';
import '../models/notification_model.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_card.dart';
import '../widgets/empty_state_widget.dart';
import '../widgets/shimmer_loading_widget.dart';
import '../widgets/student_avatar.dart';
import 'student_auth_service.dart';

class StudentDashboardScreen extends StatefulWidget {
  const StudentDashboardScreen({super.key});

  @override
  State<StudentDashboardScreen> createState() => _StudentDashboardScreenState();
}

class _StudentDashboardScreenState extends State<StudentDashboardScreen> {
  StudentModel? _student;
  List<NotificationModel> _recentNotices = [];
  bool _isLoading = true;
  String? _errorMessage;
  int _totalNoticesCount = 0;

  StreamSubscription<DocumentSnapshot>? _studentSubscription;
  StreamSubscription<QuerySnapshot>? _noticesSubscription;

  @override
  void initState() {
    super.initState();
    _initRealTimeListeners();
  }

  @override
  void dispose() {
    _studentSubscription?.cancel();
    _noticesSubscription?.cancel();
    super.dispose();
  }

  void _initRealTimeListeners() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final session = await StudentAuthService.getLocalSession();
      if (session == null) {
        setState(() => _errorMessage = 'Session expired. Please log in again.');
        return;
      }

      final studentId = session['studentId'] as String? ?? '';
      final studentCode = session['studentCode'] as String?;

      final student = await StudentAuthService.fetchCurrentStudent(
        studentId: studentId,
        studentCode: studentCode,
      );

      if (student == null) {
        if (mounted) {
          setState(() {
            _errorMessage = 'Student record not found. Contact the academy.';
            _isLoading = false;
          });
        }
        return;
      }

      _studentSubscription?.cancel();
      _noticesSubscription?.cancel();

      if (mounted) {
        setState(() {
          _student = student;
        });
      }

      // Listen to Student doc in real-time
      _studentSubscription = FirebaseFirestore.instance
          .collection('students')
          .doc(student.id)
          .snapshots()
          .listen((doc) {
        if (doc.exists && mounted) {
          setState(() {
            _student = StudentModel.fromFirestore(doc);
            if (_student != null && _recentNotices.isNotEmpty) {
              _isLoading = false;
            }
          });
        }
      }, onError: (e) {
        if (mounted) {
          setState(() => _errorMessage = 'Connection error. Please try again.');
        }
      });

      // Listen to notifications in real-time
      _noticesSubscription = FirebaseFirestore.instance
          .collection('notifications')
          .orderBy('timestamp', descending: true)
          .snapshots()
          .listen((noticesSnapshot) {
        final noticesList = noticesSnapshot.docs
            .map((doc) => NotificationModel.fromMap(doc.data(), doc.id))
            .where((n) => n.studentId.isEmpty || n.studentId == student.id || n.studentId == studentId)
            .toList();

        if (mounted) {
          setState(() {
            _totalNoticesCount = noticesList.length;
            _recentNotices = noticesList.take(3).toList();
            _isLoading = false;
          });
        }
      }, onError: (e) {
        if (mounted) {
          setState(() => _errorMessage = 'Notice fetch error.');
        }
      });

    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load data. Please try again.';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _refreshData() async {
    _initRealTimeListeners();
    await Future.delayed(const Duration(milliseconds: 500));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isLoading) {
      return Scaffold(
        body: ListView(
          padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 16),
          children: [
            const ShimmerLoadingWidget(width: double.infinity, height: 180, borderRadius: 24),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(child: ShimmerLoadingWidget(width: double.infinity, height: 90, borderRadius: 16)),
                const SizedBox(width: 12),
                Expanded(child: ShimmerLoadingWidget(width: double.infinity, height: 90, borderRadius: 16)),
              ],
            ),
            const SizedBox(height: 24),
            const ShimmerLoadingWidget(width: double.infinity, height: 140, borderRadius: 18),
          ],
        ),
      );
    }

    if (_errorMessage != null || _student == null) {
      return Scaffold(
        body: EmptyStateWidget(
          title: 'Unable to Load Portal',
          description: _errorMessage ?? 'An error occurred while fetching your record.',
          icon: Icons.cloud_off_rounded,
          actionLabel: 'Retry',
          onAction: _initRealTimeListeners,
        ),
      );
    }

    final student = _student!;
    final feePercent = student.totalFee > 0
        ? (student.feeSubmitted / student.totalFee).clamp(0.0, 1.0)
        : 0.0;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackground : AppTheme.lightBackground,
      body: RefreshIndicator(
        onRefresh: _refreshData,
        color: AppTheme.primaryBlue,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // Modern Curved Header
            SliverToBoxAdapter(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(32),
                    bottomRight: Radius.circular(32),
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Top Bar with Actions
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.school_rounded, color: Colors.white, size: 20),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  'Quaid Academy',
                                  style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        // Student Profile Card Info inside Header
                        Row(
                          children: [
                            Container(
                              width: 68,
                              height: 68,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2.5),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.2),
                                    blurRadius: 10,
                                  )
                                ],
                              ),
                              child: StudentAvatar(
                                student: student,
                                size: 48,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Welcome back, 👋',
                                    style: GoogleFonts.poppins(
                                      color: Colors.white.withValues(alpha: 0.85),
                                      fontSize: 13,
                                    ),
                                  ),
                                  Text(
                                    student.name,
                                    style: GoogleFonts.poppins(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(alpha: 0.2),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          student.studentCode,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '${student.classType} • ${student.grade}',
                                        style: TextStyle(
                                          color: Colors.white.withValues(alpha: 0.9),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
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
              ),
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Quick Stats Cards Grid
                    Row(
                      children: [
                        Expanded(
                          child: CustomCard(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: AppTheme.secondaryGreen.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(Icons.check_circle_rounded, color: AppTheme.secondaryGreen, size: 22),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Status',
                                        style: TextStyle(fontSize: 11, color: Colors.grey),
                                      ),
                                      Text(
                                        student.enrollmentStatusText,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: student.enrollmentStatusColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.1, end: 0),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: CustomCard(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryBlue.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(Icons.book_rounded, color: AppTheme.primaryBlue, size: 22),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Subjects',
                                        style: TextStyle(fontSize: 11, color: Colors.grey),
                                      ),
                                      Text(
                                        '${student.subjectSchedules.isNotEmpty ? 
                                        student.subjectSchedules.length : 1} Active',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ).animate().fadeIn(delay: 150.ms).slideY(begin: 0.1, end: 0),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Recent Announcements
                    _buildRecentNoticesSection(),

                    // Fee Overview Section
                    _buildSectionHeader('Fee Overview', Icons.account_balance_wallet_rounded),
                    const SizedBox(height: 12),
                    _buildFeeCard(student, feePercent),

                    const SizedBox(height: 24),

                    // Subjects & Schedule
                    _buildSectionHeader('My Academic Subjects', Icons.auto_stories_rounded),
                    const SizedBox(height: 12),
                    _buildSubjectsCard(student),

                    const SizedBox(height: 24),

                    // Class Information
                    _buildSectionHeader('Enrollment Details', Icons.info_outline_rounded),
                    const SizedBox(height: 12),
                    _buildClassInfoCard(student),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppTheme.primaryBlue),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ],
    );
  }

  Widget _buildFeeCard(StudentModel student, double feePercent) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return CustomCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildFeeStatItem(
                  'Total Fee',
                  'Rs ${student.totalFee.toStringAsFixed(0)}',
                  AppTheme.primaryBlue,
                ),
              ),
              Container(width: 1, height: 44, color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
              Expanded(
                child: _buildFeeStatItem(
                  'Submitted',
                  'Rs ${student.feeSubmitted.toStringAsFixed(0)}',
                  AppTheme.secondaryGreen,
                ),
              ),
              Container(width: 1, height: 44, color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
              Expanded(
                child: _buildFeeStatItem(
                  'Remaining',
                  'Rs ${student.feeRemaining.toStringAsFixed(0)}',
                  student.feeRemaining > 0 ? AppTheme.warningRed : AppTheme.secondaryGreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Stack(
            children: [
              Container(
                height: 12,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              FractionallySizedBox(
                widthFactor: feePercent,
                child: Container(
                  height: 12,
                  decoration: BoxDecoration(
                    gradient: feePercent >= 1.0 ? AppTheme.successGradient : AppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Payment Progress: ${(feePercent * 100).toStringAsFixed(0)}%',
                style: TextStyle(fontSize: 12, color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary, fontWeight: FontWeight.w500),
              ),
              if (student.feeRemaining <= 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.secondaryGreen.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Cleared ✓',
                    style: TextStyle(fontSize: 12, color: AppTheme.secondaryGreen, fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(delay: 200.ms);
  }

  Widget _buildFeeStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildSubjectsCard(StudentModel student) {
    final subjects = student.subjectSchedules;
    if (subjects.isEmpty) {
      return CustomCard(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            const Icon(Icons.class_outlined, color: AppTheme.primaryBlue),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                student.subject.isNotEmpty ? student.subject : 'Standard Course Subjects Enrolled',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      );
    }

    return CustomCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: subjects.entries.map((entry) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: AppTheme.primaryBlue,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      entry.key,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    entry.value,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.primaryBlue,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    ).animate().fadeIn(delay: 300.ms);
  }

  Widget _buildClassInfoCard(StudentModel student) {
    final subjects = student.subject.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    final isMultiSubject = subjects.length > 1;

    return CustomCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildInfoRow(Icons.category_rounded, 'Class Format', student.classType),
          const Divider(height: 20),
          _buildInfoRow(Icons.school_rounded, 'Academic Grade', student.grade),
          if (student.schedule.isNotEmpty || isMultiSubject) ...[
            const Divider(height: 20),
            if (isMultiSubject) ...[
              Row(
                children: [
                  const Icon(Icons.access_time_rounded, size: 20, color: AppTheme.primaryBlue),
                  const SizedBox(width: 12),
                  const Text(
                    'Batch Schedule',
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                  const Spacer(),
                ],
              ),
              const SizedBox(height: 4),
              ...subjects.map((subj) {
                final subjSchedule = student.getScheduleForSubject(subj);
                return Padding(
                  padding: const EdgeInsets.only(left: 32, top: 4, bottom: 4, right: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: AppTheme.primaryBlue,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        subj,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                      const Spacer(),
                      Text(
                        subjSchedule.isNotEmpty ? subjSchedule : 'Not set',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: subjSchedule.isNotEmpty 
                              ? (Theme.of(context).brightness == Brightness.dark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary)
                              : AppTheme.warningRed,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ] else ...[
              _buildInfoRow(Icons.access_time_rounded, 'Batch Schedule', student.schedule),
            ],
          ],
          const Divider(height: 20),
          _buildInfoRow(
            Icons.verified_user_rounded,
            'Enrollment Status',
            student.enrollmentStatusText,
            valueColor: student.enrollmentStatusColor,
          ),
        ],
      ),
    ).animate().fadeIn(delay: 400.ms);
  }



  Widget _buildInfoRow(IconData icon, String label, String value, {Color? valueColor}) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppTheme.primaryBlue),
        const SizedBox(width: 12),
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: Colors.grey),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  Widget _buildRecentNoticesSection() {
    if (_recentNotices.isEmpty) return const SizedBox.shrink();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Recent Announcements ($_totalNoticesCount)', Icons.campaign_rounded),
        const SizedBox(height: 12),
        CustomCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: _recentNotices.map((notice) {
              final isLast = notice == _recentNotices.last;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: AppTheme.accentOrange,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          notice.title,
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        DateFormat('MMM dd').format(notice.timestamp),
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.only(left: 18),
                    child: Text(
                      notice.message,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (!isLast) ...[
                    const SizedBox(height: 12),
                    const Divider(height: 1),
                    const SizedBox(height: 12),
                  ],
                ],
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 24),
      ],
    ).animate().fadeIn(delay: 100.ms);
  }
}
