import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../student_portal/student_login_screen.dart';
import '../teacher_portal/teacher_login_screen.dart';
import '../login/login_screen.dart';
import '../theme/app_theme.dart';

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen>
    with TickerProviderStateMixin {
  late AnimationController _bgController;

  @override
  void initState() {
    super.initState();
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _bgController.dispose();
    super.dispose();
  }

  void _navigateToStudent(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const StudentLoginScreen()),
    );
  }

  void _navigateToTeacher(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const TeacherLoginScreen()),
    );
  }

  void _navigateToAdmin(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isWide = size.width >= 700;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: [
          // ── Animated Gradient Background ──
          AnimatedBuilder(
            animation: _bgController,
            builder: (context, _) {
              return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFF0F172A),
                      Color.lerp(
                        const Color(0xFF1E3A8A),
                        const Color(0xFF1E40AF),
                        _bgController.value,
                      )!,
                      const Color(0xFF0F172A),
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
              );
            },
          ),

          // ── Decorative Circles ──
          Positioned(
            top: -80,
            right: -60,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.04),
              ),
            ),
          ),
          Positioned(
            bottom: -100,
            left: -70,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF3B82F6).withValues(alpha: 0.08),
              ),
            ),
          ),

          // ── Main Content ──
          SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: isWide ? size.width * 0.12 : 24,
                vertical: 32,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 24),

                  // Logo
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: Image.asset(
                        'assets/images/Quaid Academy logo.png',
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.school_rounded,
                          size: 54,
                          color: AppTheme.primaryBlue,
                        ),
                      ),
                    ),
                  )
                      .animate()
                      .fadeIn(duration: 700.ms)
                      .scale(begin: const Offset(0.7, 0.7)),

                  const SizedBox(height: 20),

                  // Academy Name
                  Text(
                    'QUAID ACADEMY',
                    style: GoogleFonts.poppins(
                      fontSize: isWide ? 34 : 28,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 2.5,
                    ),
                  ).animate().fadeIn(delay: 200.ms),

                  const SizedBox(height: 6),

                  // Tagline
                  Text(
                    '"From here it is possible."',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontStyle: FontStyle.italic,
                      color: Colors.white.withValues(alpha: 0.70),
                      letterSpacing: 0.5,
                    ),
                  ).animate().fadeIn(delay: 350.ms),

                  const SizedBox(height: 48),

                  // Welcome subtitle
                  Text(
                    'Welcome to Quaid Academy',
                    style: GoogleFonts.poppins(
                      fontSize: isWide ? 22 : 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ).animate().fadeIn(delay: 450.ms),

                  const SizedBox(height: 8),

                  Text(
                    'How would you like to continue?',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.65),
                    ),
                    textAlign: TextAlign.center,
                  ).animate().fadeIn(delay: 550.ms),

                  const SizedBox(height: 40),

                  // ── Role Cards ──
                  if (isWide)
                    Row(
                      children: [
                        Expanded(child: _buildRoleCard(context, _RoleCardData.student)),
                        const SizedBox(width: 20),
                        Expanded(child: _buildRoleCard(context, _RoleCardData.teacher)),
                        const SizedBox(width: 20),
                        Expanded(child: _buildRoleCard(context, _RoleCardData.admin)),
                      ],
                    )
                  else
                    Column(
                      children: [
                        _buildRoleCard(context, _RoleCardData.student),
                        const SizedBox(height: 16),
                        _buildRoleCard(context, _RoleCardData.teacher),
                        const SizedBox(height: 16),
                        _buildRoleCard(context, _RoleCardData.admin),
                      ],
                    ),

                  const SizedBox(height: 48),

                  Text(
                    '© 2026 Quaid Academy — All Rights Reserved',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.35),
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleCard(BuildContext context, _RoleCardData data) {
    final index = [
      _RoleCardData.student,
      _RoleCardData.teacher,
      _RoleCardData.admin
    ].indexOf(data);

    return GestureDetector(
      onTap: () {
        switch (data) {
          case _RoleCardData.student:
            _navigateToStudent(context);
            break;
          case _RoleCardData.teacher:
            _navigateToTeacher(context);
            break;
          case _RoleCardData.admin:
            _navigateToAdmin(context);
            break;
        }
      },
      child: _RoleCard(data: data)
          .animate()
          .fadeIn(delay: (600 + index * 120).ms, duration: 500.ms)
          .slideY(begin: 0.15, delay: (600 + index * 120).ms),
    );
  }
}

enum _RoleCardData { student, teacher, admin }

class _RoleCard extends StatefulWidget {
  final _RoleCardData data;
  const _RoleCard({required this.data});

  @override
  State<_RoleCard> createState() => _RoleCardState();
}

class _RoleCardState extends State<_RoleCard> {
  bool _hovered = false;

  String get _emoji {
    switch (widget.data) {
      case _RoleCardData.student:
        return '👨‍🎓';
      case _RoleCardData.teacher:
        return '👨‍🏫';
      case _RoleCardData.admin:
        return '🛡️';
    }
  }

  String get _title {
    switch (widget.data) {
      case _RoleCardData.student:
        return 'Student';
      case _RoleCardData.teacher:
        return 'Teacher';
      case _RoleCardData.admin:
        return 'Administration';
    }
  }

  String get _description {
    switch (widget.data) {
      case _RoleCardData.student:
        return 'Access your personal profile, fees, notifications, and academic records.';
      case _RoleCardData.teacher:
        return 'View your students, subject fees, and subject-specific notifications.';
      case _RoleCardData.admin:
        return 'Full academy management: students, teachers, fees, and settings.';
    }
  }

  List<Color> get _gradient {
    switch (widget.data) {
      case _RoleCardData.student:
        return [const Color(0xFF059669), const Color(0xFF10B981)];
      case _RoleCardData.teacher:
        return [const Color(0xFF1E3A8A), const Color(0xFF3B82F6)];
      case _RoleCardData.admin:
        return [const Color(0xFF7C3AED), const Color(0xFFA855F7)];
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 700;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        transform: Matrix4.identity()
          ..scale(_hovered ? 1.03 : 1.0),
        transformAlignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: _gradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: _gradient.first.withValues(alpha: _hovered ? 0.5 : 0.3),
              blurRadius: _hovered ? 28 : 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: null, // handled by parent GestureDetector
            child: Padding(
              padding: EdgeInsets.all(isWide ? 28 : 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        _emoji,
                        style: TextStyle(fontSize: isWide ? 40 : 34),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.arrow_forward_ios_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _title,
                    style: GoogleFonts.poppins(
                      fontSize: isWide ? 22 : 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _description,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.85),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
