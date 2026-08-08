import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/notification_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/notification_model.dart';
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

class _StudentNotificationsScreenState extends State<StudentNotificationsScreen> {
  String? _studentId;
  bool _isLoading = true;
  String? _errorMessage;
  List<NotificationModel> _notices = [];
  StreamSubscription<QuerySnapshot>? _noticesSubscription;

  @override
  void initState() {
    super.initState();
    _initRealTimeNotices();
  }

  @override
  void dispose() {
    _noticesSubscription?.cancel();
    super.dispose();
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

      _noticesSubscription?.cancel();
      _noticesSubscription = FirebaseFirestore.instance
          .collection('notifications')
          .orderBy('timestamp', descending: true)
          .snapshots()
          .listen((snapshot) {
        final allNotices = snapshot.docs
            .map((doc) => NotificationModel.fromMap(doc.data(), doc.id))
            .toList();

        final filteredNotices = allNotices.where((n) {
          return n.studentId.isEmpty || n.studentId == _studentId;
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
    await Future.delayed(const Duration(milliseconds: 500));
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
                  : RefreshIndicator(
                      onRefresh: _refreshData,
                      color: AppTheme.primaryBlue,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(20),
                        itemCount: _notices.length,
                        itemBuilder: (context, index) {
                          final item = _notices[index];
                          
                          IconData leadingIcon = Icons.campaign_rounded;
                          Color themeColor = AppTheme.primaryBlue;
                          Color bgActiveColor = AppTheme.primaryBlue.withValues(alpha: 0.12);

                          if (item.notificationType == 'student_registered') {
                            leadingIcon = Icons.school_rounded;
                            themeColor = AppTheme.accentIndigo;
                            bgActiveColor = AppTheme.accentIndigo.withValues(alpha: 0.12);
                          } else if (item.notificationType == 'fee_payment' || item.notificationType == 'second_installment') {
                            leadingIcon = Icons.payments_rounded;
                            themeColor = AppTheme.secondaryGreen;
                            bgActiveColor = AppTheme.secondaryGreen.withValues(alpha: 0.12);
                          } else if (item.notificationType == 'fee_reminder') {
                            leadingIcon = Icons.credit_card_rounded;
                            themeColor = AppTheme.warningRed;
                            bgActiveColor = AppTheme.warningRed.withValues(alpha: 0.12);
                          } else if (item.notificationType == 'broadcast') {
                            leadingIcon = Icons.campaign_rounded;
                            themeColor = AppTheme.accentOrange;
                            bgActiveColor = AppTheme.accentOrange.withValues(alpha: 0.12);
                          }

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: GestureDetector(
                              onTap: () => _openNotificationDetail(item, themeColor, leadingIcon),
                              child: CustomCard(
                                padding: const EdgeInsets.all(18),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: bgActiveColor,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(leadingIcon, color: themeColor, size: 22),
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
                                                child: Text(
                                                  'Issued by: ${item.registeredBy.isNotEmpty ? item.registeredBy : "Administration"}',
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
                          ).animate().fadeIn(delay: (index * 40).ms).slideY(begin: 0.05);
                        },
                      ),
                    ),
    );
  }

  void _openNotificationDetail(
    NotificationModel item,
    Color themeColor,
    IconData leadingIcon,
  ) {
    // Mark notification as read in Firestore silently
    FirebaseFirestore.instance
        .collection('notifications')
        .doc(item.id)
        .update({'isRead': true}).catchError((_) {});

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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: themeColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              item.notificationType.replaceAll('_', ' ').toUpperCase(),
                              style: TextStyle(
                                color: themeColor,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            DateFormat('MMM dd, yyyy • hh:mm a').format(item.timestamp),
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                            ),
                          ),
                        ],
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
                      const SizedBox(height: 24),
                      // Footer — issued by
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark ? Colors.white12 : Colors.grey.shade200,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.admin_panel_settings_rounded, size: 16, color: themeColor),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Issued by: ${item.registeredBy.isNotEmpty ? item.registeredBy : "Administration"}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
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
}
