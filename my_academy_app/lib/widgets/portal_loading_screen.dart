import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../models/teacher_model.dart';
import '../screens/main_wrapper.dart';
import '../teacher_portal/teacher_main_wrapper.dart';
import '../student_portal/student_main_wrapper.dart';
import '../main.dart';

enum PortalRoleType { admin, teacher, student, general }

/// Premium, high-tech animated portal loading & transition screen.
/// Gives users clear visual feedback that their portal is securely loading,
/// with stepped verification messages, role badge, pulsing branding, and gradient progress.
/// Automatically and reliably navigates into the target portal when loading completes.
class PortalLoadingScreen extends StatefulWidget {
  final PortalRoleType roleType;
  final String title;
  final String subtitle;
  final String? userName;
  final Widget? targetScreen;
  final WidgetBuilder? targetBuilder;
  final VoidCallback? onComplete;
  final Duration duration;

  const PortalLoadingScreen({
    super.key,
    required this.roleType,
    required this.title,
    required this.subtitle,
    this.userName,
    this.targetScreen,
    this.targetBuilder,
    this.onComplete,
    this.duration = const Duration(milliseconds: 1200),
  });

  /// Factory for Admin Portal Access
  factory PortalLoadingScreen.admin({
    Key? key,
    Widget? targetScreen,
    WidgetBuilder? targetBuilder,
    VoidCallback? onComplete,
    String? adminName,
    Duration duration = const Duration(milliseconds: 1200),
  }) {
    return PortalLoadingScreen(
      key: key,
      roleType: PortalRoleType.admin,
      title: 'Administrator Portal',
      subtitle: 'Securing administrative console & controls',
      userName: adminName ?? 'Administrator',
      targetScreen: targetScreen ?? const MainWrapper(),
      targetBuilder: targetBuilder,
      onComplete: onComplete,
      duration: duration,
    );
  }

  /// Factory for Teacher Portal Access
  factory PortalLoadingScreen.teacher({
    Key? key,
    TeacherModel? teacher,
    Widget? targetScreen,
    WidgetBuilder? targetBuilder,
    VoidCallback? onComplete,
    String? teacherName,
    String? subject,
    Duration duration = const Duration(milliseconds: 1200),
  }) {
    final subText = subject != null && subject.isNotEmpty
        ? ' ($subject)'
        : (teacher?.subject != null && teacher!.subject.isNotEmpty ? ' (${teacher.subject})' : '');
    return PortalLoadingScreen(
      key: key,
      roleType: PortalRoleType.teacher,
      title: 'Teacher Portal',
      subtitle: 'Preparing classroom records & student rosters$subText',
      userName: teacherName ?? teacher?.name ?? 'Teacher',
      targetScreen: targetScreen ?? (teacher != null ? TeacherMainWrapper(teacher: teacher) : null),
      targetBuilder: targetBuilder,
      onComplete: onComplete,
      duration: duration,
    );
  }

  /// Factory for Student Portal Access
  factory PortalLoadingScreen.student({
    Key? key,
    Widget? targetScreen,
    WidgetBuilder? targetBuilder,
    VoidCallback? onComplete,
    String? studentName,
    String? studentCode,
    Duration duration = const Duration(milliseconds: 1200),
  }) {
    final codeText = studentCode != null && studentCode.isNotEmpty ? ' [$studentCode]' : '';
    return PortalLoadingScreen(
      key: key,
      roleType: PortalRoleType.student,
      title: 'Student Portal',
      subtitle: 'Syncing your schedule, attendance & fee record$codeText',
      userName: studentName ?? 'Student',
      targetScreen: targetScreen ?? const StudentMainWrapper(),
      targetBuilder: targetBuilder,
      onComplete: onComplete,
      duration: duration,
    );
  }

  /// Factory for General Startup / Role Verification
  factory PortalLoadingScreen.general({
    Key? key,
    Widget? targetScreen,
    WidgetBuilder? targetBuilder,
    VoidCallback? onComplete,
    String title = 'Quaid Academy',
    String subtitle = 'Loading academy services...',
    Duration duration = const Duration(milliseconds: 1200),
  }) {
    return PortalLoadingScreen(
      key: key,
      roleType: PortalRoleType.general,
      title: title,
      subtitle: subtitle,
      targetScreen: targetScreen,
      targetBuilder: targetBuilder,
      onComplete: onComplete,
      duration: duration,
    );
  }

  @override
  State<PortalLoadingScreen> createState() => _PortalLoadingScreenState();
}

class _PortalLoadingScreenState extends State<PortalLoadingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _progressController;
  late Animation<double> _progressAnimation;
  int _currentStepIndex = 0;
  Timer? _stepTimer;
  Timer? _safetyTimer;
  bool _hasNavigated = false;

  late final List<String> _steps;

  @override
  void initState() {
    super.initState();

    switch (widget.roleType) {
      case PortalRoleType.admin:
        _steps = [
          'Verifying administrative credentials & security...',
          'Loading student databases, fee ledgers & staff records...',
          'Launching Administrator Management Console...',
        ];
        break;
      case PortalRoleType.teacher:
        _steps = [
          'Authenticating faculty credentials & permissions...',
          'Loading assigned class rosters, schedules & attendance...',
          'Launching Teacher Workspace & Classroom Portal...',
        ];
        break;
      case PortalRoleType.student:
        _steps = [
          'Verifying student enrollment & security token...',
          'Synchronizing personal timetable, fee balance & notices...',
          'Launching Student Portal & Dashboard...',
        ];
        break;
      case PortalRoleType.general:
        _steps = [
          'Connecting to Quaid Academy servers...',
          'Checking local cache & preferences...',
          'Preparing application interface...',
        ];
        break;
    }

    _progressController = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    _progressAnimation = CurvedAnimation(
      parent: _progressController,
      curve: Curves.easeInOutCubic,
    );

    // Step status updates
    final stepDurationMs = widget.duration.inMilliseconds ~/ _steps.length;
    _stepTimer = Timer.periodic(Duration(milliseconds: stepDurationMs), (timer) {
      if (!mounted) return;
      if (_currentStepIndex < _steps.length - 1) {
        setState(() {
          _currentStepIndex++;
        });
      } else {
        timer.cancel();
      }
    });

    // 1. Controller status completion listener
    _progressController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _completeAndNavigate();
      }
    });

    // 2. Controller forward future completion
    _progressController.forward().then((_) {
      if (mounted) {
        _completeAndNavigate();
      }
    }).catchError((e) {
      debugPrint('[PortalLoadingScreen] Animation ticker error: $e');
      if (mounted) {
        _completeAndNavigate();
      }
    });

    // 3. Fallback safety timer to ensure navigation occurs even if ticker is paused
    _safetyTimer = Timer(widget.duration + const Duration(milliseconds: 250), () {
      if (mounted && !_hasNavigated) {
        debugPrint('[PortalLoadingScreen] Safety timer triggered navigation');
        _completeAndNavigate();
      }
    });
  }

  void _completeAndNavigate() {
    if (_hasNavigated || !mounted) return;
    _hasNavigated = true;
    _stepTimer?.cancel();
    _safetyTimer?.cancel();

    // 1. If explicit onComplete callback was provided, try executing it safely
    if (widget.onComplete != null) {
      try {
        widget.onComplete!();
        return;
      } catch (e) {
        debugPrint('[PortalLoadingScreen] onComplete error: $e. Falling back to self-navigation.');
      }
    }

    // 2. Safe internal navigation using this State's own context or appNavigatorKey
    final nav = (mounted ? Navigator.maybeOf(context) : null) ?? appNavigatorKey.currentState;
    if (nav == null) {
      debugPrint('[PortalLoadingScreen] Navigator unavailable!');
      return;
    }

    Widget? destination = widget.targetScreen;
    if (destination == null && widget.targetBuilder != null && mounted) {
      destination = widget.targetBuilder!(context);
    }

    // Fallback based on roleType if not specified
    if (destination == null) {
      switch (widget.roleType) {
        case PortalRoleType.admin:
          destination = const MainWrapper();
          break;
        case PortalRoleType.student:
          destination = const StudentMainWrapper();
          break;
        case PortalRoleType.teacher:
          break;
        case PortalRoleType.general:
          break;
      }
    }

    if (destination != null) {
      nav.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => destination!),
        (route) => false,
      );
    }
  }

  @override
  void dispose() {
    _safetyTimer?.cancel();
    _stepTimer?.cancel();
    _progressController.dispose();
    super.dispose();
  }

  Color get _primaryColor {
    switch (widget.roleType) {
      case PortalRoleType.admin:
        return const Color(0xFF1E3A8A); // Royal Blue
      case PortalRoleType.teacher:
        return const Color(0xFF0D9488); // Emerald / Teal
      case PortalRoleType.student:
        return const Color(0xFF2563EB); // Vibrant Blue
      case PortalRoleType.general:
        return AppTheme.primaryBlue;
    }
  }

  Color get _accentColor {
    switch (widget.roleType) {
      case PortalRoleType.admin:
        return const Color(0xFFF59E0B); // Amber / Gold
      case PortalRoleType.teacher:
        return const Color(0xFF10B981); // Bright Emerald
      case PortalRoleType.student:
        return const Color(0xFF38BDF8); // Sky Blue
      case PortalRoleType.general:
        return const Color(0xFF60A5FA);
    }
  }

  IconData get _roleIcon {
    switch (widget.roleType) {
      case PortalRoleType.admin:
        return Icons.admin_panel_settings_rounded;
      case PortalRoleType.teacher:
        return Icons.school_rounded;
      case PortalRoleType.student:
        return Icons.person_pin_rounded;
      case PortalRoleType.general:
        return Icons.verified_user_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAurora = AppTheme.isAurora(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: false,
      child: Scaffold(
      body: Stack(
        children: [
          // Background Gradient
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isAurora
                      ? [
                          const Color(0xFF070B14),
                          const Color(0xFF0D1527),
                          const Color(0xFF1E1B4B),
                        ]
                      : (isDark
                          ? [
                              const Color(0xFF020617),
                              const Color(0xFF0F172A),
                              const Color(0xFF1E1B4B),
                            ]
                          : [
                              const Color(0xFFF8FAFC),
                              const Color(0xFFF1F5F9),
                              const Color(0xFFE2E8F0),
                            ]),
                ),
              ),
            ),
          ),

          // Floating Ambient Glow Orbs
          Positioned(
            top: -60,
            right: -60,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: (isAurora ? AppTheme.auroraCyanHighlight : _primaryColor)
                    .withValues(alpha: isDark ? 0.22 : 0.12),
              ),
            )
                .animate(onPlay: (controller) => controller.repeat(reverse: true))
                .scale(begin: const Offset(1, 1), end: const Offset(1.2, 1.2), duration: 3.seconds)
                .move(begin: const Offset(0, 0), end: const Offset(-20, 20), duration: 4.seconds),
          ),
          Positioned(
            bottom: -60,
            left: -60,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _accentColor.withValues(alpha: isDark ? 0.20 : 0.10),
              ),
            )
                .animate(onPlay: (controller) => controller.repeat(reverse: true))
                .scale(begin: const Offset(1, 1), end: const Offset(1.25, 1.25), duration: 4.seconds)
                .move(begin: const Offset(0, 0), end: const Offset(20, -20), duration: 3.seconds),
          ),

          // Main Center Content
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Glowing Academy Emblem with Breathing Animation
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: _primaryColor.withValues(alpha: isDark ? 0.5 : 0.25),
                            blurRadius: 36,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isDark ? const Color(0xFF1E293B) : Colors.white,
                          border: Border.all(
                            color: _primaryColor.withValues(alpha: 0.4),
                            width: 2.5,
                          ),
                        ),
                        child: ClipOval(
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Image.asset(
                              'assets/images/Quaid Academy logo.png',
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => Icon(
                                Icons.school_rounded,
                                size: 54,
                                color: _primaryColor,
                              ),
                            ),
                          ),
                        ),
                      ),
                    )
                        .animate(onPlay: (controller) => controller.repeat(reverse: true))
                        .scale(begin: const Offset(1.0, 1.0), end: const Offset(1.06, 1.06), duration: 1800.ms, curve: Curves.easeInOut),

                    const SizedBox(height: 28),

                    // Role Badge Pill
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            _primaryColor.withValues(alpha: 0.15),
                            _accentColor.withValues(alpha: 0.15),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                          color: _primaryColor.withValues(alpha: 0.4),
                          width: 1.2,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_roleIcon, size: 18, color: _primaryColor),
                          const SizedBox(width: 8),
                          Text(
                            widget.title.toUpperCase(),
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                              color: _primaryColor,
                            ),
                          ),
                        ],
                      ),
                    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.3, end: 0),

                    const SizedBox(height: 16),

                    // Personalized Welcome Title
                    if (widget.userName != null) ...[
                      Text(
                        'Welcome, ${widget.userName}!',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2, end: 0),
                      const SizedBox(height: 6),
                    ],

                    Text(
                      widget.subtitle,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                        fontWeight: FontWeight.w400,
                      ),
                    ).animate().fadeIn(delay: 300.ms),

                    const SizedBox(height: 32),

                    // Glassmorphic Progress Container
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: isAurora
                            ? AppTheme.auroraGlassCard
                            : (isDark
                                ? const Color(0xFF1E293B).withValues(alpha: 0.7)
                                : Colors.white.withValues(alpha: 0.85)),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isAurora
                              ? AppTheme.auroraBorder
                              : (isDark
                                  ? Colors.white.withValues(alpha: 0.1)
                                  : Colors.black.withValues(alpha: 0.05)),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: (isAurora ? const Color(0xFF020617) : Colors.black)
                                .withValues(alpha: isDark ? 0.3 : 0.06),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                          if (isAurora)
                            BoxShadow(
                              color: AppTheme.auroraPrimaryBlue.withValues(alpha: 0.12),
                              blurRadius: 22,
                              offset: const Offset(0, 4),
                            ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // Dynamic Step Text with animated switch
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            child: Row(
                              key: ValueKey<int>(_currentStepIndex),
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(_primaryColor),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _steps[_currentStepIndex],
                                    style: GoogleFonts.poppins(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w500,
                                      color: isDark ? Colors.grey.shade300 : const Color(0xFF334155),
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 18),

                          // Animated Gradient Progress Bar
                          AnimatedBuilder(
                            animation: _progressAnimation,
                            builder: (context, _) {
                              final percent = (_progressAnimation.value * 100).toInt();
                              return Column(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: SizedBox(
                                      height: 8,
                                      child: Stack(
                                        children: [
                                          Container(
                                            color: isDark ? Colors.white10 : Colors.grey.shade200,
                                          ),
                                          FractionallySizedBox(
                                            widthFactor: _progressAnimation.value.clamp(0.02, 1.0),
                                            child: Container(
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                  colors: [_primaryColor, _accentColor],
                                                ),
                                                borderRadius: BorderRadius.circular(8),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: _primaryColor.withValues(alpha: 0.5),
                                                    blurRadius: 8,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        percent >= 100
                                            ? 'Ready! Opening Portal...'
                                            : 'Securing Session...',
                                        style: GoogleFonts.poppins(
                                          fontSize: 11,
                                          fontWeight: percent >= 100 ? FontWeight.w600 : FontWeight.normal,
                                          color: percent >= 100
                                              ? _primaryColor
                                              : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                                        ),
                                      ),
                                      Text(
                                        '$percent%',
                                        style: GoogleFonts.poppins(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: _primaryColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.15, end: 0),

                    const SizedBox(height: 24),

                    // Trust & Security Indicator
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.lock_outline_rounded,
                          size: 14,
                          color: isDark ? Colors.grey.shade500 : Colors.grey.shade400,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '256-Bit Encrypted Academy Portal',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: isDark ? Colors.grey.shade500 : Colors.grey.shade500,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ).animate().fadeIn(delay: 600.ms),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    ),
    );
  }
}

/// Standalone Beautiful Loading Widget for in-app data loading states
class BeautifulLoadingWidget extends StatelessWidget {
  final String? message;
  final double size;
  final Color? color;

  const BeautifulLoadingWidget({
    super.key,
    this.message,
    this.size = 64,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? AppTheme.primaryBlue;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: effectiveColor.withValues(alpha: 0.25),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
                border: Border.all(
                  color: effectiveColor.withValues(alpha: 0.3),
                  width: 2,
                ),
              ),
              child: ClipOval(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Image.asset(
                    'assets/images/Quaid Academy logo.png',
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Icon(
                      Icons.school_rounded,
                      size: size * 0.5,
                      color: effectiveColor,
                    ),
                  ),
                ),
              ),
            )
                .animate(onPlay: (controller) => controller.repeat(reverse: true))
                .scale(begin: const Offset(0.95, 0.95), end: const Offset(1.05, 1.05), duration: 1200.ms),
            const SizedBox(height: 16),
            SizedBox(
              width: 140,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  minHeight: 3.5,
                  backgroundColor: isDark ? Colors.white12 : Colors.black12,
                  valueColor: AlwaysStoppedAnimation<Color>(effectiveColor),
                ),
              ),
            ),
            if (message != null && message!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 12.5,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ).animate().fadeIn(),
            ],
          ],
        ),
      ),
    );
  }
}
