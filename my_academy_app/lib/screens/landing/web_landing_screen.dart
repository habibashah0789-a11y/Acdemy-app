import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../provider/theme_provider.dart';
import '../../student_portal/student_login_screen.dart';
import '../../teacher_portal/teacher_login_screen.dart';
import '../../login/login_screen.dart';
import '../../widgets/about_developers_widget.dart';

class WebLandingScreen extends StatefulWidget {
  const WebLandingScreen({super.key});

  @override
  State<WebLandingScreen> createState() => _WebLandingScreenState();
}

class _WebLandingScreenState extends State<WebLandingScreen> {
  final ScrollController _scrollController = ScrollController();

  final GlobalKey _programsKey = GlobalKey();
  final GlobalKey _subjectsKey = GlobalKey();
  final GlobalKey _featuresKey = GlobalKey();
  final GlobalKey _portalsKey = GlobalKey();
  final GlobalKey _contactKey = GlobalKey();

  void _scrollTo(GlobalKey key) {
    final ctx = key.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isAurora = AppTheme.isAurora(context);
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width >= 1024;
    final isTablet = size.width >= 700 && size.width < 1024;

    return Scaffold(
      backgroundColor: isAurora
          ? AppTheme.auroraBackground
          : (isDark ? AppTheme.darkBackground : AppTheme.lightBackground),
      endDrawer: !isDesktop ? _buildMobileDrawer(context) : null,
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // Top Navigation Bar
          SliverAppBar(
            pinned: true,
            elevation: isAurora ? 0 : 2,
            backgroundColor: isAurora
                ? AppTheme.auroraSurface.withValues(alpha: 0.9)
                : (isDark
                    ? AppTheme.darkSurface.withValues(alpha: 0.95)
                    : Colors.white.withValues(alpha: 0.95)),
            titleSpacing: 16,
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/images/Quaid Academy logo.png',
                  width: 38,
                  height: 38,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryBlue,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.school_rounded, color: Colors.white, size: 22),
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'QUAID ACADEMY',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        letterSpacing: 0.8,
                        color: isAurora
                            ? AppTheme.auroraCyanHighlight
                            : (isDark ? Colors.white : AppTheme.primaryBlue),
                      ),
                    ),
                    Text(
                      '"From Here It Is Possible"',
                      style: GoogleFonts.poppins(
                        fontSize: 9,
                        fontStyle: FontStyle.italic,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white70 : AppTheme.secondaryGreen,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              if (isDesktop) ...[
                _navButton('Programs', () => _scrollTo(_programsKey)),
                _navButton('Subjects', () => _scrollTo(_subjectsKey)),
                _navButton('Features', () => _scrollTo(_featuresKey)),
                _navButton('Portals', () => _scrollTo(_portalsKey)),
                _navButton('Contact', () => _scrollTo(_contactKey)),
                const SizedBox(width: 8),
              ],
              _buildThemeToggle(context),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                child: ElevatedButton.icon(
                  onPressed: () => _scrollTo(_portalsKey),
                  icon: const Icon(Icons.login_rounded, size: 16),
                  label: const Text('Portal Login', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isAurora ? AppTheme.auroraPrimaryBlue : AppTheme.primaryBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              if (!isDesktop)
                Builder(
                  builder: (ctx) => IconButton(
                    icon: const Icon(Icons.menu_rounded),
                    onPressed: () => Scaffold.of(ctx).openEndDrawer(),
                  ),
                ),
              const SizedBox(width: 8),
            ],
          ),

          // Main Landing Page Content
          SliverToBoxAdapter(
            child: Column(
              children: [
                _buildHeroSection(context, isDesktop, isTablet),
                _buildStatsBanner(context, isDesktop),
                _buildProgramsSection(context, isDesktop),
                _buildSubjectsSection(context, isDesktop),
                _buildFeaturesSection(context, isDesktop),
                _buildPortalsSection(context, isDesktop),
                _buildContactSection(context, isDesktop),
                _buildFooter(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _navButton(String label, VoidCallback onTap) {
    return TextButton(
      onPressed: onTap,
      child: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : AppTheme.lightTextSecondary,
        ),
      ),
    );
  }

  Widget _buildThemeToggle(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return IconButton(
      tooltip: 'Toggle Theme',
      icon: Icon(isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded, size: 20),
      onPressed: () {
        themeProvider.toggleTheme();
      },
    );
  }

  Widget _buildMobileDrawer(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Drawer(
      backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(
              gradient: AppTheme.primaryGradient,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/images/Quaid Academy logo.png',
                  width: 50,
                  height: 50,
                  errorBuilder: (_, __, ___) => const Icon(Icons.school_rounded, color: Colors.white, size: 36),
                ),
                const SizedBox(height: 10),
                Text(
                  'Quaid Academy',
                  style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                ),
                Text(
                  '"From Here It Is Possible"',
                  style: GoogleFonts.poppins(color: Colors.white70, fontSize: 11, fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.layers_rounded, color: AppTheme.primaryBlue),
            title: const Text('Academic Programs'),
            onTap: () {
              Navigator.pop(context);
              _scrollTo(_programsKey);
            },
          ),
          ListTile(
            leading: const Icon(Icons.science_rounded, color: AppTheme.secondaryGreen),
            title: const Text('Science Subjects'),
            onTap: () {
              Navigator.pop(context);
              _scrollTo(_subjectsKey);
            },
          ),
          ListTile(
            leading: const Icon(Icons.star_rounded, color: AppTheme.accentOrange),
            title: const Text('Key Features'),
            onTap: () {
              Navigator.pop(context);
              _scrollTo(_featuresKey);
            },
          ),
          ListTile(
            leading: const Icon(Icons.login_rounded, color: AppTheme.primaryBlue),
            title: const Text('Portals & Login'),
            onTap: () {
              Navigator.pop(context);
              _scrollTo(_portalsKey);
            },
          ),
          ListTile(
            leading: const Icon(Icons.contact_mail_rounded, color: Colors.purple),
            title: const Text('Contact & Location'),
            onTap: () {
              Navigator.pop(context);
              _scrollTo(_contactKey);
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.code_rounded),
            title: const Text('About Developers'),
            subtitle: const Text('Habiba Shah & Hamza Taif'),
            onTap: () {
              Navigator.pop(context);
              AboutDevelopersDialog.show(context);
            },
          ),
        ],
      ),
    );
  }

  // ── Hero Section ──────────────────────────────────────────────────────────
  Widget _buildHeroSection(BuildContext context, bool isDesktop, bool isTablet) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isAurora = AppTheme.isAurora(context);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 60 : 20,
        vertical: isDesktop ? 70 : 40,
      ),
      decoration: BoxDecoration(
        gradient: isAurora
            ? const LinearGradient(
                colors: [Color(0xFF070B14), Color(0xFF0C1425), Color(0xFF0F1B38)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              )
            : (isDark
                ? const LinearGradient(
                    colors: [Color(0xFF0A0F1D), Color(0xFF131D33)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  )
                : const LinearGradient(
                    colors: [Color(0xFFEEF2FF), Color(0xFFF8FAFC)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  )),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            children: [
              // Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: isAurora
                      ? AppTheme.auroraCyanHighlight.withValues(alpha: 0.15)
                      : AppTheme.primaryBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: isAurora ? AppTheme.auroraCyanHighlight : AppTheme.primaryBlue,
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.verified_rounded,
                      size: 16,
                      color: isAurora ? AppTheme.auroraCyanHighlight : AppTheme.primaryBlue,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Premier Science & Pre-Medical Coaching',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isAurora ? AppTheme.auroraCyanHighlight : AppTheme.primaryBlue,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Title
              Text(
                'Quaid Academy',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: isDesktop ? 52 : (isTablet ? 40 : 32),
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                  height: 1.1,
                  color: isAurora
                      ? Colors.white
                      : (isDark ? Colors.white : AppTheme.primaryDarkBlue),
                ),
              ),
              const SizedBox(height: 12),

              // Motto Quote
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.secondaryGreen.withValues(alpha: 0.2),
                      AppTheme.primaryBlue.withValues(alpha: 0.2),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '“From Here It Is Possible”',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: isDesktop ? 22 : 18,
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.secondaryGreen,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Subtitle
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 780),
                child: Text(
                  'Empowering students towards academic excellence in Matric 9th & 10th and FSc Pre-Medical 1st & 2nd Year. Modern learning management, digital attendance, transparent fee tracking, and teacher-student connectivity.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: isDesktop ? 15 : 13.5,
                    height: 1.6,
                    color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                  ),
                ),
              ),
              const SizedBox(height: 36),

              // CTA Action Buttons
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 16,
                runSpacing: 12,
                children: [
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const StudentLoginScreen()),
                      );
                    },
                    icon: const Icon(Icons.school_rounded, size: 20),
                    label: const Text('Student Portal Access'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      textStyle: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 4,
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const TeacherLoginScreen()),
                      );
                    },
                    icon: const Icon(Icons.person_pin_rounded, size: 20),
                    label: const Text('Teacher Portal'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isDark ? Colors.white : AppTheme.primaryBlue,
                      side: BorderSide(color: isDark ? Colors.white38 : AppTheme.primaryBlue, width: 1.5),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      textStyle: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                      );
                    },
                    icon: const Icon(Icons.admin_panel_settings_rounded, size: 20),
                    label: const Text('Administration'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isAurora ? const Color(0xFF1E1B4B) : const Color(0xFF0F172A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      textStyle: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Stats Banner ──────────────────────────────────────────────────────────
  Widget _buildStatsBanner(BuildContext context, bool isDesktop) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final stats = [
      {'label': 'Academic Classes', 'val': '4 Programs', 'icon': Icons.class_rounded, 'color': AppTheme.primaryBlue},
      {'label': 'Science Core', 'val': '5 Subjects', 'icon': Icons.science_rounded, 'color': AppTheme.secondaryGreen},
      {'label': 'Device Binding', 'val': '1:1 Session', 'icon': Icons.phonelink_lock_rounded, 'color': AppTheme.accentOrange},
      {'label': 'Fee Transparency', 'val': 'Real-Time Sync', 'icon': Icons.sync_rounded, 'color': Colors.purple},
    ];

    return Container(
      width: double.infinity,
      color: isDark ? const Color(0xFF0E1422) : Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: LayoutBuilder(
            builder: (ctx, constraints) {
              final cols = constraints.maxWidth >= 900 ? 4 : (constraints.maxWidth >= 500 ? 2 : 1);
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: stats.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: cols,
                  mainAxisExtent: 80,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                itemBuilder: (context, i) {
                  final s = stats[i];
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.darkSurface : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: (s['color'] as Color).withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(s['icon'] as IconData, color: s['color'] as Color, size: 22),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                s['val'] as String,
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: isDark ? Colors.white : AppTheme.primaryDarkBlue,
                                ),
                              ),
                              Text(
                                s['label'] as String,
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  // ── Programs Section ──────────────────────────────────────────────────────
  Widget _buildProgramsSection(BuildContext context, bool isDesktop) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final programs = [
      {
        'title': 'Matric 9th Grade',
        'sub': 'Secondary School Certificate - Part 1',
        'desc': 'Rigorous foundational coaching in Biology, Physics, Chemistry, Mathematics, and English preparing students for board examination excellence.',
        'badge': 'Matriculation',
        'color': const Color(0xFF1E3A8A),
      },
      {
        'title': 'Matric 10th Grade',
        'sub': 'Secondary School Certificate - Part 2',
        'desc': 'Targeted board examination revision, past-paper diagnostics, practical concepts, and systematic syllabus mastery.',
        'badge': 'Board Batch',
        'color': const Color(0xFF0D9488),
      },
      {
        'title': 'FSc 1st Year (11th)',
        'sub': 'Higher Secondary Pre-Medical - Part 1',
        'desc': 'In-depth conceptual lectures, medical college entrance orientation, daily assessments, and specialized individual student tracking.',
        'badge': 'Pre-Medical',
        'color': const Color(0xFF7C3AED),
      },
      {
        'title': 'FSc 2nd Year (12th)',
        'sub': 'Higher Secondary Pre-Medical - Part 2',
        'desc': 'Final board preparation, comprehensive medical admission test orientation (MDCAT guidance), and syllabus completion drills.',
        'badge': 'Final Pre-Med',
        'color': const Color(0xFFEA580C),
      },
    ];

    return Container(
      key: _programsKey,
      padding: EdgeInsets.symmetric(horizontal: isDesktop ? 60 : 20, vertical: 60),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            children: [
              _sectionHeader(
                'ACADEMIC PROGRAMS',
                'Comprehensive Science Curriculum',
                'Structured learning paths tailored for secondary and higher secondary science education.',
              ),
              const SizedBox(height: 36),
              LayoutBuilder(
                builder: (ctx, constraints) {
                  final cols = constraints.maxWidth >= 900 ? 2 : 1;
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: programs.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: cols,
                      mainAxisExtent: 180,
                      crossAxisSpacing: 20,
                      mainAxisSpacing: 20,
                    ),
                    itemBuilder: (context, i) {
                      final p = programs[i];
                      final col = p['color'] as Color;
                      return Container(
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          color: isDark ? AppTheme.darkSurface : Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: col.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    p['badge'] as String,
                                    style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: col,
                                    ),
                                  ),
                                ),
                                Icon(Icons.school_outlined, size: 20, color: col),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              p['title'] as String,
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                                fontSize: 17,
                                color: isDark ? Colors.white : AppTheme.primaryDarkBlue,
                              ),
                            ),
                            Text(
                              p['sub'] as String,
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: col,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Expanded(
                              child: Text(
                                p['desc'] as String,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Subjects Section ──────────────────────────────────────────────────────
  Widget _buildSubjectsSection(BuildContext context, bool isDesktop) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final subjects = [
      {'name': 'Biology', 'icon': Icons.biotech_rounded, 'color': const Color(0xFF10B981), 'desc': 'Cellular biology, human physiology, genetics, and biotechnology.'},
      {'name': 'Physics', 'icon': Icons.science_rounded, 'color': const Color(0xFF3B82F6), 'desc': 'Mechanics, electromagnetism, modern physics, and practical experiments.'},
      {'name': 'Chemistry', 'icon': Icons.colorize_rounded, 'color': const Color(0xFFF59E0B), 'desc': 'Organic mechanisms, stoichiometry, inorganic compounds, and analytical methods.'},
      {'name': 'Mathematics', 'icon': Icons.calculate_rounded, 'color': const Color(0xFF00897B), 'desc': 'Algebra, calculus, analytical geometry, and mathematical proofs.'},
      {'name': 'English', 'icon': Icons.menu_book_rounded, 'color': const Color(0xFF8B5CF6), 'desc': 'Grammar mastery, comprehension, essay writing, and academic vocabulary.'},
    ];

    return Container(
      key: _subjectsKey,
      width: double.infinity,
      color: isDark ? const Color(0xFF090E1A) : const Color(0xFFF1F5F9),
      padding: EdgeInsets.symmetric(horizontal: isDesktop ? 60 : 20, vertical: 60),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            children: [
              _sectionHeader(
                'CORE SUBJECTS',
                'Academic Disciplines',
                'Specialized faculty coaching across all required science and general tracks.',
              ),
              const SizedBox(height: 36),
              LayoutBuilder(
                builder: (ctx, constraints) {
                  final cols = constraints.maxWidth >= 1000 ? 5 : (constraints.maxWidth >= 600 ? 3 : 1);
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: subjects.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: cols,
                      mainAxisExtent: 160,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                    ),
                    itemBuilder: (context, i) {
                      final s = subjects[i];
                      final col = s['color'] as Color;
                      return Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: isDark ? AppTheme.darkSurface : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: col.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(s['icon'] as IconData, color: col, size: 24),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              s['name'] as String,
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: isDark ? Colors.white : AppTheme.primaryDarkBlue,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Expanded(
                              child: Text(
                                s['desc'] as String,
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                                  height: 1.3,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Features Section ──────────────────────────────────────────────────────
  Widget _buildFeaturesSection(BuildContext context, bool isDesktop) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final features = [
      {
        'title': 'Real-Time Fee Transparency',
        'desc': 'Subject-wise breakdown (Biology, Physics, Chemistry, Math, English), instant remaining balance, and online payment submissions via Bank Transfer, EasyPaisa, and JazzCash.',
        'icon': Icons.account_balance_wallet_rounded,
        'color': AppTheme.secondaryGreen,
      },
      {
        'title': 'Unique Student ID & Digital QR',
        'desc': 'Every student is assigned a permanent unique Student ID and digital QR pass for fast identification and attendance verification.',
        'icon': Icons.qr_code_2_rounded,
        'color': AppTheme.primaryBlue,
      },
      {
        'title': 'Strict One-Device Policy',
        'desc': 'Hardware device binding protects student test papers, notices, and confidential records from unauthorized concurrent sharing.',
        'icon': Icons.security_rounded,
        'color': AppTheme.accentOrange,
      },
      {
        'title': 'Real-Time Timetable & Schedules',
        'desc': 'Class, subject, and teacher schedules synchronized directly from Cloud Firestore with zero unnecessary refresh delays.',
        'icon': Icons.calendar_month_rounded,
        'color': Colors.purple,
      },
      {
        'title': 'Direct Teacher Broadcasts',
        'desc': 'Specialized announcement channel where teachers notify their assigned subject students directly regarding assignments and schedules.',
        'icon': Icons.campaign_rounded,
        'color': const Color(0xFF0D9488),
      },
      {
        'title': 'Multi-Theme & Accessible UI',
        'desc': 'Tailored Dark Mode, Light Mode, and futuristic Aurora Glass theme designed for eye comfort during long study and review sessions.',
        'icon': Icons.palette_rounded,
        'color': const Color(0xFFE11D48),
      },
    ];

    return Container(
      key: _featuresKey,
      padding: EdgeInsets.symmetric(horizontal: isDesktop ? 60 : 20, vertical: 60),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            children: [
              _sectionHeader(
                'WHY CHOOSE QUAID ACADEMY',
                'Modern Digital Academic System',
                'Built from the ground up to support modern science pedagogy and transparent academy governance.',
              ),
              const SizedBox(height: 36),
              LayoutBuilder(
                builder: (ctx, constraints) {
                  final cols = constraints.maxWidth >= 900 ? 3 : (constraints.maxWidth >= 600 ? 2 : 1);
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: features.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: cols,
                      mainAxisExtent: 170,
                      crossAxisSpacing: 20,
                      mainAxisSpacing: 20,
                    ),
                    itemBuilder: (context, i) {
                      final f = features[i];
                      final col = f['color'] as Color;
                      return Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: isDark ? AppTheme.darkSurface : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: col.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(f['icon'] as IconData, color: col, size: 22),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    f['title'] as String,
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: isDark ? Colors.white : AppTheme.primaryDarkBlue,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Expanded(
                              child: Text(
                                f['desc'] as String,
                                style: GoogleFonts.poppins(
                                  fontSize: 11.5,
                                  color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Portals Section ───────────────────────────────────────────────────────
  Widget _buildPortalsSection(BuildContext context, bool isDesktop) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isAurora = AppTheme.isAurora(context);

    final portals = [
      {
        'title': 'Student Portal',
        'sub': 'Access profile, fee status, schedule, and notices',
        'badge': 'Learner Access',
        'icon': Icons.school_rounded,
        'color': AppTheme.primaryBlue,
        'action': () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const StudentLoginScreen()),
          );
        },
      },
      {
        'title': 'Teacher Portal',
        'sub': 'Manage subjects, classes, student lists & notices',
        'badge': 'Faculty Access',
        'icon': Icons.person_pin_rounded,
        'color': const Color(0xFF0D9488),
        'action': () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const TeacherLoginScreen()),
          );
        },
      },
      {
        'title': 'Administration',
        'sub': 'Executive control, admissions, finances & device binding',
        'badge': 'Academy Management',
        'icon': Icons.admin_panel_settings_rounded,
        'color': const Color(0xFF0F172A),
        'action': () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const LoginScreen()),
          );
        },
      },
    ];

    return Container(
      key: _portalsKey,
      width: double.infinity,
      color: isAurora
          ? AppTheme.auroraSurface
          : (isDark ? const Color(0xFF0B101D) : const Color(0xFFEEF2FF)),
      padding: EdgeInsets.symmetric(horizontal: isDesktop ? 60 : 20, vertical: 60),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            children: [
              _sectionHeader(
                'PORTAL ACCESS',
                'Select Your Role To Begin',
                'Secure role-based login verified via Firebase Cloud Authentication.',
              ),
              const SizedBox(height: 36),
              LayoutBuilder(
                builder: (ctx, constraints) {
                  final cols = constraints.maxWidth >= 900 ? 3 : 1;
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: portals.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: cols,
                      mainAxisExtent: 220,
                      crossAxisSpacing: 20,
                      mainAxisSpacing: 20,
                    ),
                    itemBuilder: (context, i) {
                      final p = portals[i];
                      final col = p['color'] as Color;
                      return Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: isDark ? AppTheme.darkSurface : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFCBD5E1),
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
                              blurRadius: 14,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: col.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(p['icon'] as IconData, color: col, size: 26),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: col.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    p['badge'] as String,
                                    style: GoogleFonts.poppins(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.bold,
                                      color: col,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Text(
                              p['title'] as String,
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: isDark ? Colors.white : AppTheme.primaryDarkBlue,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              p['sub'] as String,
                              style: GoogleFonts.poppins(
                                fontSize: 11.5,
                                color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                              ),
                            ),
                            const Spacer(),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: p['action'] as VoidCallback,
                                icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                                label: Text('Enter ${p['title']}'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: col,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Contact Section ───────────────────────────────────────────────────────
  Widget _buildContactSection(BuildContext context, bool isDesktop) {
    return Container(
      key: _contactKey,
      padding: EdgeInsets.symmetric(horizontal: isDesktop ? 60 : 20, vertical: 50),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Container(
            padding: EdgeInsets.all(isDesktop ? 36 : 20),
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryBlue.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              children: [
                Text(
                  'Have Questions or Need Assistance?',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: isDesktop ? 26 : 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Reach out to the Quaid Academy Administration office for admissions, fee inquiries, or technical support.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 24),
                Wrap(
                  spacing: 16,
                  runSpacing: 12,
                  alignment: WrapAlignment.center,
                  children: [
                    _contactPill(Icons.location_on_rounded, 'Quaid Academy Campus'),
                    _contactPill(Icons.phone_rounded, 'Academy Administration'),
                    _contactPill(Icons.verified_rounded, '“From Here It Is Possible”'),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _contactPill(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 8),
          Text(
            text,
            style: GoogleFonts.poppins(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  // ── Footer ────────────────────────────────────────────────────────────────
  Widget _buildFooter(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      color: isDark ? const Color(0xFF070B14) : const Color(0xFF0F172A),
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            children: [
              Text(
                'Quaid Academy — From Here It Is Possible',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: () => AboutDevelopersDialog.show(context),
                child: Text(
                  'Designed & Developed by Habiba Shah & Hamza Taif',
                  style: GoogleFonts.poppins(
                    color: AppTheme.secondaryGreen,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '© ${DateTime.now().year} Quaid Academy. All Rights Reserved.',
                style: GoogleFonts.poppins(
                  color: Colors.white38,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(String overline, String title, String subtitle) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        Text(
          overline,
          style: GoogleFonts.poppins(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: AppTheme.secondaryGreen,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          title,
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : AppTheme.primaryDarkBlue,
          ),
        ),
        const SizedBox(height: 6),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Text(
            subtitle,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
            ),
          ),
        ),
      ],
    );
  }
}
