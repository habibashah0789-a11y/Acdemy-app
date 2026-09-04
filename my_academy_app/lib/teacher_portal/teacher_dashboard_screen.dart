import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../models/teacher_model.dart';
import '../services/teacher_service.dart';
import '../theme/app_theme.dart';

import '../widgets/about_developers_widget.dart';
import '../screens/app_info_screens.dart';

class TeacherDashboardScreen extends StatefulWidget {
  final TeacherModel teacher;
  const TeacherDashboardScreen({super.key, required this.teacher});

  @override
  State<TeacherDashboardScreen> createState() =>
      _TeacherDashboardScreenState();
}

class _TeacherDashboardScreenState extends State<TeacherDashboardScreen> {
  TeacherStats? _stats;
  bool _loadingStats = true;
  late TeacherModel _teacher;

  final _currencyFormat = NumberFormat('#,##0', 'en_US');

  @override
  void initState() {
    super.initState();
    _teacher = widget.teacher;
    _loadStats();
    // Listen for teacher profile changes
    TeacherService.getCurrentTeacherStream().listen((t) {
      if (t != null && mounted) setState(() => _teacher = t);
    });
  }

  Future<void> _loadStats() async {
    setState(() => _loadingStats = true);
    final stats = await TeacherService.getSubjectStats(_teacher);
    if (mounted) setState(() {
      _stats = stats;
      _loadingStats = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;
    final isWide = size.width >= 700;
    final subjectColor = _subjectColor(_teacher.subject);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Dashboard',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline_rounded),
            tooltip: 'About App',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AboutAppScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadStats,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadStats,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.all(isWide ? 24 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Welcome Header ──
              _buildWelcomeBanner(subjectColor, isDark, isWide),
              const SizedBox(height: 24),

              // ── Stats Section ──
              Text(
                'Subject Overview',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${_teacher.subject} — ${_teacher.section}',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: AppTheme.lightTextSecondary,
                ),
              ),
              const SizedBox(height: 16),

              if (_loadingStats)
                _buildStatsShimmer(isWide)
              else
                _buildStatsGrid(isWide, subjectColor),

              const SizedBox(height: 24),

              // ── Assigned Classes ──
              _buildAssignedClassesBanner(subjectColor),

              const SizedBox(height: 24),

              // ── About App Card ──
              _buildAboutAppTile(context, isDark),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeBanner(Color subjectColor, bool isDark, bool isWide) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isWide ? 28 : 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primaryDarkBlue, subjectColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: subjectColor.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome back,',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _teacher.name,
                  style: GoogleFonts.poppins(
                    fontSize: isWide ? 22 : 19,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _teacher.tagLine,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          _buildTeacherAvatar(size: 70),
        ],
      ),
    ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.08);
  }

  Widget _buildAboutAppTile(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                )
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.school_rounded,
                  color: AppTheme.primaryBlue,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'About Quaid Academy',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Management System v1.0.0',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: AppTheme.lightTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Empowering education with student registration, roll number management, instant announcement dispatches, and push notifications.',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: isDark ? Colors.grey.shade300 : const Color(0xFF475569),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AboutAppScreen()),
                );
              },
              icon: const Icon(Icons.info_outline_rounded, size: 18),
              label: Text(
                'LEARN MORE ABOUT APP',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                side: const BorderSide(color: AppTheme.primaryBlue),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.06);
  }

  Widget _buildStatsGrid(bool isWide, Color subjectColor) {
    final stats = _stats ?? const TeacherStats();
    final items = [
      _StatCard(
        label: 'Total Students',
        value: '${stats.totalStudents}',
        icon: Icons.people_rounded,
        color: subjectColor,
      ),
      _StatCard(
        label: 'Active Students',
        value: '${stats.activeStudents}',
        icon: Icons.check_circle_rounded,
        color: AppTheme.secondaryGreen,
      ),
      _StatCard(
        label: 'Fees Collected',
        value: 'Rs ${_currencyFormat.format(stats.feesCollected)}',
        icon: Icons.payments_rounded,
        color: AppTheme.accentIndigo,
      ),
      _StatCard(
        label: 'Pending Fees',
        value: 'Rs ${_currencyFormat.format(stats.feesPending)}',
        icon: Icons.pending_rounded,
        color: AppTheme.accentOrange,
      ),
      _StatCard(
        label: 'New (30 days)',
        value: '${stats.newRegistrations}',
        icon: Icons.person_add_rounded,
        color: const Color(0xFF8B5CF6),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 500 ? 3 : 2;
        return GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.4,
          ),
          itemCount: items.length,
          itemBuilder: (context, i) {
            final item = items[i];
            return _buildStatCard(item, i);
          },
        );
      },
    );
  }

  Widget _buildStatCard(_StatCard item, int index) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: item.color.withValues(alpha: 0.18),
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: item.color.withValues(alpha: 0.07),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: item.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(item.icon, color: item.color, size: 20),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.value,
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: item.color,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                item.label,
                style: TextStyle(
                  fontSize: 11,
                  color: AppTheme.lightTextSecondary,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(delay: (300 + index * 80).ms).slideY(begin: 0.1);
  }

  Widget _buildStatsShimmer(bool isWide) {
    return GridView.count(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      crossAxisCount: isWide ? 3 : 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.4,
      children: List.generate(
        5,
        (_) => Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(16),
          ),
        )
            .animate(onPlay: (c) => c.repeat(reverse: true))
            .shimmer(duration: 1000.ms),
      ),
    );
  }

  Widget _buildAssignedClassesBanner(Color subjectColor) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: subjectColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: subjectColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.class_rounded, color: subjectColor, size: 18),
              const SizedBox(width: 8),
              Text(
                'Assigned Classes',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: subjectColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _teacher.assignedClasses.isEmpty
                ? [
                    Chip(
                      label: const Text('All Classes'),
                      backgroundColor: subjectColor.withValues(alpha: 0.15),
                      labelStyle: TextStyle(color: subjectColor, fontSize: 12),
                    )
                  ]
                : _teacher.assignedClasses
                    .map((cls) => Chip(
                          label: Text(cls),
                          backgroundColor:
                              subjectColor.withValues(alpha: 0.15),
                          labelStyle:
                              TextStyle(color: subjectColor, fontSize: 12),
                        ))
                    .toList(),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 600.ms);
  }

  Widget _buildTeacherAvatar({double size = 60}) {
    if (_teacher.profilePicUrl.isNotEmpty) {
      return CircleAvatar(
        radius: size / 2,
        backgroundColor: Colors.white.withValues(alpha: 0.2),
        child: ClipOval(
          child: CachedNetworkImage(
            imageUrl: _teacher.profilePicUrl,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorWidget: (_, __, ___) => _buildInitialsAvatar(size),
          ),
        ),
      );
    }
    return _buildInitialsAvatar(size);
  }

  Widget _buildInitialsAvatar(double size) {
    final initials = _teacher.name.isNotEmpty
        ? _teacher.name
            .split(' ')
            .take(2)
            .map((w) => w.isNotEmpty ? w[0].toUpperCase() : '')
            .join()
        : 'T';
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: Colors.white.withValues(alpha: 0.25),
      child: Text(
        initials,
        style: TextStyle(
          fontSize: size * 0.35,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }

  Color _subjectColor(String subject) {
    switch (subject.toLowerCase()) {
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
}

class _StatCard {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _StatCard(
      {required this.label,
      required this.value,
      required this.icon,
      required this.color});
}
