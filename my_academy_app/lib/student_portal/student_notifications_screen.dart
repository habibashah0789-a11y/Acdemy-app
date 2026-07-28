import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
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

  @override
  void initState() {
    super.initState();
    _loadNotices();
  }

  Future<void> _loadNotices() async {
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

      final snapshot = await FirebaseFirestore.instance
          .collection('notifications')
          .orderBy('timestamp', descending: true)
          .limit(100)
          .get()
          .timeout(const Duration(seconds: 10));

      final allNotices = snapshot.docs
          .map((doc) => NotificationModel.fromMap(doc.data(), doc.id))
          .toList();

      _notices = allNotices.where((n) {
        return n.studentId.isEmpty || n.studentId == _studentId;
      }).toList();

    } catch (e) {
      debugPrint('Student notification fetch error: $e');
      setState(() => _errorMessage = 'Failed to load notifications.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackground : AppTheme.lightBackground,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(
          'Academy Announcements',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadNotices,
          ),
        ],
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
                  onAction: _loadNotices,
                )
              : _notices.isEmpty
                  ? EmptyStateWidget(
                      title: 'No Announcements Yet',
                      description: 'All official notices and updates will appear here.',
                      icon: Icons.notifications_off_outlined,
                      actionLabel: 'Refresh',
                      onAction: _loadNotices,
                    )
                  : RefreshIndicator(
                      onRefresh: _loadNotices,
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
                          } else if (item.notificationType == 'broadcast') {
                            leadingIcon = Icons.campaign_rounded;
                            themeColor = AppTheme.accentOrange;
                            bgActiveColor = AppTheme.accentOrange.withValues(alpha: 0.12);
                          }

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 14),
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
                                        ),
                                        const SizedBox(height: 10),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              'Issued by: ${item.registeredBy.isNotEmpty ? item.registeredBy : "Administration"}',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                                                fontStyle: FontStyle.italic,
                                              ),
                                            ),
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
                          ).animate().fadeIn(delay: (index * 40).ms).slideY(begin: 0.05);
                        },
                      ),
                    ),
    );
  }
}
