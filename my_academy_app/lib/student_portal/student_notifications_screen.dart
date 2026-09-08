import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/notification_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/notification_model.dart';
import '../models/student_model.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_card.dart';
import '../widgets/empty_state_widget.dart';
import '../widgets/shimmer_loading_widget.dart';
import 'student_auth_service.dart';

class StudentNotificationsScreen extends StatefulWidget {
  const StudentNotificationsScreen({super.key});

  @override
  State<StudentNotificationsScreen> createState() => _StudentNotificationsScreenState();
}

class _StudentNotificationsScreenState extends State<StudentNotificationsScreen> with SingleTickerProviderStateMixin {
  String? _studentId;
  TabController? _tabController;
  StudentModel? _student;
  bool _isLoading = true;
  String? _errorMessage;
  List<NotificationModel> _notices = [];
  StreamSubscription<QuerySnapshot>? _noticesSubscription;
  StreamSubscription<void>? _readStatusSubscription;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initRealTimeNotices();
    _readStatusSubscription = NotificationService.readStatusStream.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _noticesSubscription?.cancel();
    _readStatusSubscription?.cancel();
    _tabController?.dispose();
    super.dispose();
  }

  bool _isNoticeTargetedForStudent(NotificationModel n, StudentModel? student, String studentId) {
    return NotificationService.isNotificationForStudent(student, studentId, n);
  }

  void _initRealTimeNotices() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final session = await StudentAuthService.getLocalSession();
      if (session == null) {
        setState(() => _errorMessage = 'Session expired.');
        return;
      }
      _studentId = session['studentId'] as String;

      // Load student profile for grade & subject matching
      _student = await StudentAuthService.fetchCurrentStudent(studentId: _studentId!);
      if (_student == null) {
        if (mounted) {
          setState(() {
            _errorMessage = 'Student profile not found.';
            _isLoading = false;
          });
        }
        return;
      }

      final studentSubjects = _student!.subject
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
          
      if (studentSubjects.isEmpty) {
        studentSubjects.add('NONE');
      }

      _noticesSubscription?.cancel();
      _noticesSubscription = FirebaseFirestore.instance
          .collection('notifications')
          .orderBy('timestamp', descending: true)
          .snapshots()
          .listen((snapshot) {
        final allNotices = snapshot.docs
            .map((doc) => NotificationModel.fromMap(doc.data(), doc.id))
            .toList();

        // Still keep client-side filtering as a fallback and to handle complex matching if needed
        final filteredNotices = allNotices.where((n) {
          return _isNoticeTargetedForStudent(n, _student, _studentId!);
        }).toList();

        if (mounted) {
          setState(() {
            _notices = filteredNotices;
            _isLoading = false;
          });
        }
      }, onError: (e) {
        debugPrint('Student notification fetch error: $e');
        if (mounted) {
          setState(() {
            _errorMessage = 'Failed to load notifications.';
            _isLoading = false;
          });
        }
      });

    } catch (e) {
      debugPrint('Student notification initialization error: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load notifications.';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _refreshData() async {
    _initRealTimeNotices();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackground : AppTheme.lightBackground,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(
          _isLoading ? 'Academy Announcements' : 'Academy Announcements (${_notices.length})',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white.withOpacity(0.7),
          labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14),
          unselectedLabelStyle: GoogleFonts.poppins(fontWeight: FontWeight.normal, fontSize: 14),
          tabs: const [
            Tab(text: 'Administration'),
            Tab(text: 'Teachers'),
          ],
        ),
      ),
      body: _isLoading
          ? ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: 4,
              itemBuilder: (_, __) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: ShimmerLoadingWidget.listTilePlaceholder(context),
              ),
            )
          : _errorMessage != null
              ? EmptyStateWidget(
                  title: 'Notice Board Error',
                  description: _errorMessage!,
                  icon: Icons.error_outline_rounded,
                  actionLabel: 'Retry',
                  onAction: _initRealTimeNotices,
                )
              : _notices.isEmpty
                  ? EmptyStateWidget(
                      title: 'No Announcements Yet',
                      description: 'All official notices and updates will appear here.',
                      icon: Icons.notifications_off_outlined,
                      actionLabel: 'Refresh',
                      onAction: _refreshData,
                    )
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildNoticesList(_notices.where((n) => !n.isTeacherAnnouncement).toList()),
                        _buildNoticesList(_notices.where((n) => n.isTeacherAnnouncement).toList()),
                      ],
                    ),
    );
  }

  Widget _buildNoticesList(List<NotificationModel> currentNotices) {
    if (currentNotices.isEmpty) {
      return EmptyStateWidget(
        title: 'No Announcements Yet',
        description: 'All official notices and updates will appear here.',
        icon: Icons.notifications_off_outlined,
        actionLabel: 'Refresh',
        onAction: _refreshData,
      );
    }
    
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return RefreshIndicator(
      onRefresh: _refreshData,
      color: AppTheme.primaryBlue,
      child: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: currentNotices.length,
        itemBuilder: (context, index) {
          final item = currentNotices[index];
                          
                          IconData leadingIcon = Icons.campaign_rounded;
                          Color themeColor = AppTheme.primaryBlue;
                          Color bgActiveColor = AppTheme.primaryBlue.withValues(alpha: 0.12);

                          if (item.isTeacherAnnouncement) {
                            leadingIcon = Icons.record_voice_over_rounded;
                            themeColor = AppTheme.primaryBlue;
                            bgActiveColor = AppTheme.primaryBlue.withValues(alpha: 0.12);
                          } else if (item.notificationType == 'student_registered') {
                            leadingIcon = Icons.school_rounded;
                            themeColor = AppTheme.accentIndigo;
                            bgActiveColor = AppTheme.accentIndigo.withValues(alpha: 0.12);
                          } else if (item.notificationType == 'fee_payment' || item.notificationType == 'second_installment' || item.notificationType == 'fee_payment_verified') {
                            leadingIcon = Icons.payments_rounded;
                            themeColor = AppTheme.secondaryGreen;
                            bgActiveColor = AppTheme.secondaryGreen.withValues(alpha: 0.12);
                          } else if (item.notificationType == 'fee_reminder' || item.notificationType == 'fee_payment_rejected') {
                            leadingIcon = Icons.credit_card_rounded;
                            themeColor = AppTheme.warningRed;
                            bgActiveColor = AppTheme.warningRed.withValues(alpha: 0.12);
                          } else if (item.notificationType == 'broadcast') {
                            leadingIcon = Icons.campaign_rounded;
                            themeColor = AppTheme.accentOrange;
                            bgActiveColor = AppTheme.accentOrange.withValues(alpha: 0.12);
                          }

                          final bool isUnread = !NotificationService.isNoticeRead(item.id);

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: GestureDetector(
                              onTap: () => _openNotificationDetail(item, themeColor, leadingIcon),
                              child: CustomCard(
                                padding: const EdgeInsets.all(18),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Stack(
                                      clipBehavior: Clip.none,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: bgActiveColor,
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(leadingIcon, color: themeColor, size: 22),
                                        ),
                                        if (isUnread)
                                          Positioned(
                                            right: -2,
                                            top: -2,
                                            child: Container(
                                              width: 12,
                                              height: 12,
                                              decoration: const BoxDecoration(
                                                color: Colors.redAccent,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Expanded(
                                                child: Row(
                                                  children: [
                                                    if (isUnread) ...[
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                        decoration: BoxDecoration(
                                                          color: Colors.redAccent.withValues(alpha: 0.15),
                                                          borderRadius: BorderRadius.circular(4),
                                                        ),
                                                        child: const Text(
                                                          'NEW',
                                                          style: TextStyle(
                                                            color: Colors.redAccent,
                                                            fontSize: 9,
                                                            fontWeight: FontWeight.bold,
                                                          ),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 6),
                                                    ],
                                                    Expanded(
                                                      child: Text(
                                                        item.title,
                                                        style: GoogleFonts.poppins(
                                                          fontWeight: FontWeight.bold,
                                                          fontSize: 14,
                                                        ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Text(
                                                DateFormat('MMM dd').format(item.timestamp),
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            item.message,
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                                              height: 1.4,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 10),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Expanded(
                                                child: item.isTeacherAnnouncement
                                                    ? Wrap(
                                                        spacing: 6,
                                                        runSpacing: 4,
                                                        children: [
                                                          Container(
                                                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                                            decoration: BoxDecoration(
                                                              color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                                                              borderRadius: BorderRadius.circular(6),
                                                              border: Border.all(color: AppTheme.primaryBlue.withValues(alpha: 0.2)),
                                                            ),
                                                            child: Row(
                                                              mainAxisSize: MainAxisSize.min,
                                                              children: [
                                                                const Icon(Icons.school_rounded, size: 13, color: AppTheme.primaryBlue),
                                                                const SizedBox(width: 4),
                                                                Flexible(
                                                                  child: Text(
                                                                    item.authorDisplay,
                                                                    style: GoogleFonts.poppins(
                                                                      fontSize: 11,
                                                                      fontWeight: FontWeight.w600,
                                                                      color: AppTheme.primaryBlue,
                                                                    ),
                                                                    overflow: TextOverflow.ellipsis,
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        ],
                                                      )
                                                    : Text(
                                                        'Issued by: Administration / Admin',
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                                                          fontStyle: FontStyle.italic,
                                                        ),
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                DateFormat('hh:mm a').format(item.timestamp),
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ).animate().fadeIn().slideY(begin: 0.05);
                        },
                      ),
                    );
  }

  void _openNotificationDetail(
    NotificationModel item,
    Color themeColor,
    IconData leadingIcon,
  ) {
    // Mark notice as read locally
    NotificationService.markNoticeAsRead(item.id);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        builder: (_, scrollController) => Container(
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkSurface : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              // Drag handle
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              // Icon banner
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: themeColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(leadingIcon, color: themeColor, size: 36),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      Text(
                        item.title,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : AppTheme.primaryDarkBlue,
                        ),
                      ),
                      const SizedBox(height: 6),
                      // Time + Type badge
                      Center(
                        child: Wrap(
                          alignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: themeColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                item.isTeacherAnnouncement
                                    ? 'TEACHER ANNOUNCEMENT'
                                    : item.notificationType.replaceAll('_', ' ').toUpperCase(),
                                style: TextStyle(
                                  color: themeColor,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            if (item.isTeacherAnnouncement && item.teacherSubjectDisplay.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppTheme.secondaryGreen.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  item.teacherSubjectDisplay.toUpperCase(),
                                  style: const TextStyle(
                                    color: AppTheme.secondaryGreen,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            if (item.isTeacherAnnouncement && item.teacherClassDisplay.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.purple.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  'CLASS: ${item.teacherClassDisplay.toUpperCase()}',
                                  style: const TextStyle(
                                    color: Colors.purple,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            if (item.isTeacherAnnouncement && item.targetHourDisplay.isNotEmpty && item.targetHourDisplay.toLowerCase() != 'all')
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.teal.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  'BATCH: ${item.targetHourDisplay.toUpperCase()}',
                                  style: const TextStyle(
                                    color: Colors.teal,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            Text(
                              DateFormat('MMM dd, yyyy • hh:mm a').format(item.timestamp),
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Divider
                      Divider(color: isDark ? Colors.white12 : Colors.grey.shade200),
                      const SizedBox(height: 16),
                      // Full message
                      Text(
                        item.message,
                        style: TextStyle(
                          fontSize: 15,
                          height: 1.7,
                          color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                        ),
                      ),
                      if (item.mediaUrl.isNotEmpty && item.mediaType != 'none') ...[
                        const SizedBox(height: 16),
                        _buildStudentAttachment(item.mediaUrl, item.mediaType),
                      ],
                      const SizedBox(height: 24),
                      // Footer — Teacher profile card or Admin badge
                      if (item.isTeacherAnnouncement) ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withValues(alpha: 0.05) : AppTheme.primaryBlue.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: AppTheme.primaryBlue.withValues(alpha: 0.25),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 46,
                                height: 46,
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryBlue.withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.school_rounded, color: AppTheme.primaryBlue, size: 24),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Announcement by Teacher',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      item.teacherDisplayName.isNotEmpty ? item.teacherDisplayName : item.registeredBy,
                                      style: GoogleFonts.poppins(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? Colors.white : AppTheme.primaryDarkBlue,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 4,
                                      children: [
                                        if (item.teacherSubjectDisplay.isNotEmpty)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: AppTheme.primaryBlue.withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              'Subject: ${item.teacherSubjectDisplay}',
                                              style: GoogleFonts.poppins(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: AppTheme.primaryBlue,
                                              ),
                                            ),
                                          ),
                                        Container(
                                           padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                           decoration: BoxDecoration(
                                             color: Colors.purple.withValues(alpha: 0.15),
                                             borderRadius: BorderRadius.circular(6),
                                           ),
                                           child: Text(
                                             'Class: ${item.teacherClassDisplay.isNotEmpty ? item.teacherClassDisplay : (item.className.isNotEmpty && item.className.toLowerCase() != "general" ? item.className : "All Registered")}',
                                             style: GoogleFonts.poppins(
                                               fontSize: 11,
                                               fontWeight: FontWeight.w600,
                                               color: Colors.purple,
                                             ),
                                           ),
                                         ),
                                         if (item.targetHourDisplay.isNotEmpty && item.targetHourDisplay.toLowerCase() != 'all')
                                           Container(
                                             padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                             decoration: BoxDecoration(
                                               color: Colors.teal.withValues(alpha: 0.15),
                                               borderRadius: BorderRadius.circular(6),
                                             ),
                                             child: Text(
                                               'Batch: ${item.targetHourDisplay}',
                                               style: GoogleFonts.poppins(
                                                 fontSize: 11,
                                                 fontWeight: FontWeight.w600,
                                                 color: Colors.teal,
                                               ),
                                             ),
                                           ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark ? Colors.white12 : Colors.grey.shade200,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.badge_rounded, size: 16, color: themeColor),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Issued by: Administration / Admin',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Divider(color: isDark ? Colors.white12 : Colors.grey.shade200, height: 1),
                              const SizedBox(height: 12),
                              Text(
                                'Contact Administration:',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              InkWell(
                                onTap: () async {
                                  final uri = Uri.parse('mailto:quaidacademy241992@gmail.com');
                                  if (await canLaunchUrl(uri)) {
                                    await launchUrl(uri);
                                  }
                                },
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.email_rounded, size: 14, color: themeColor),
                                    const SizedBox(width: 6),
                                    Text(
                                      'quaidacademy241992@gmail.com',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: themeColor,
                                        decoration: TextDecoration.underline,
                                        decorationColor: themeColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              InkWell(
                                onTap: () async {
                                  final uri = Uri.parse('tel:03139509505');
                                  if (await canLaunchUrl(uri)) {
                                    await launchUrl(uri);
                                  }
                                },
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.phone_rounded, size: 14, color: themeColor),
                                    const SizedBox(width: 6),
                                    Text(
                                      '03139509505',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: themeColor,
                                        decoration: TextDecoration.underline,
                                        decorationColor: themeColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStudentAttachment(String mediaUrl, String mediaType) {
    if (mediaType == 'image') {
      return ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxHeight: 250),
          color: Colors.black12,
          child: Image.network(
            mediaUrl,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: Text('Failed to load image attachment')),
            ),
          ),
        ),
      );
    } else if (mediaType == 'pdf') {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.picture_as_pdf_rounded, color: Colors.red, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'PDF Document Attached',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.red.shade900,
                ),
              ),
            ),
            ElevatedButton.icon(
              onPressed: () => _launchAttachmentUrl(mediaUrl),
              icon: const Icon(Icons.open_in_new_rounded, size: 14),
              label: const Text('Open PDF'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    } else if (mediaType == 'audio') {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.accentIndigo.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.accentIndigo.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.graphic_eq_rounded, color: AppTheme.accentIndigo, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Voice Note / Audio Attachment',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryDarkBlue,
                ),
              ),
            ),
            ElevatedButton.icon(
              onPressed: () => _launchAttachmentUrl(mediaUrl),
              icon: const Icon(Icons.play_arrow_rounded, size: 18),
              label: const Text('Listen'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentIndigo,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Future<void> _launchAttachmentUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

