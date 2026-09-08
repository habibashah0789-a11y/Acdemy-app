import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/teacher_model.dart';
import '../services/teacher_service.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import 'dart:async';

class TeacherNotificationsScreen extends StatefulWidget {
  final TeacherModel? teacher;
  const TeacherNotificationsScreen({super.key, this.teacher});

  @override
  State<TeacherNotificationsScreen> createState() =>
      _TeacherNotificationsScreenState();
}

class _TeacherNotificationsScreenState
    extends State<TeacherNotificationsScreen> {
  TeacherModel? _currentTeacher;
  StreamSubscription<void>? _readStatusSubscription;

  @override
  void initState() {
    super.initState();
    _currentTeacher = widget.teacher;
    if (_currentTeacher == null) {
      _loadTeacherProfile();
    }
    _readStatusSubscription = NotificationService.readStatusStream.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _readStatusSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadTeacherProfile() async {
    final teacher = await TeacherService.getCurrentTeacher();
    if (mounted && teacher != null) {
      setState(() {
        _currentTeacher = teacher;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'Announcements & Notices',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
          ),
          bottom: const TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(text: 'Student & Subject Notices'),
              Tab(text: 'My Announcements'),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _openCreateAnnouncementModal,
          backgroundColor: AppTheme.primaryBlue,
          icon: const Icon(Icons.campaign_rounded, color: Colors.white),
          label: Text(
            'New Announcement',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
        body: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('notifications')
              .orderBy('timestamp', descending: true)
              .limit(100)
              .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Failed to load notifications',
                style: GoogleFonts.poppins(),
              ),
            );
          }

          final activeTeacher = _currentTeacher ?? widget.teacher;
          final docs = snapshot.data?.docs ?? [];
          
          // Academy & Student Notices filter (Strict: only teacher's subject students & installments)
          final academyNotices = docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            data['id'] = doc.id;
            return NotificationService.isNotificationForTeacher(activeTeacher, data);
          }).toList();

          // My Announcements filter: all announcements published by this teacher
          final myAnnouncements = docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final senderId = (data['senderId'] ?? data['teacherId'] ?? '').toString().trim();
            final teacherName = (data['teacherName'] ?? '').toString().trim().toLowerCase();
            final registeredBy = (data['registeredBy'] ?? '').toString().trim().toLowerCase();
            final notifType = (data['type'] ?? data['notificationType'] ?? '').toString();

            if (activeTeacher != null) {
              final myId = activeTeacher.id.trim();
              final myCustomId = activeTeacher.teacherId.trim();
              final myName = activeTeacher.name.trim().toLowerCase();
              final myEmail = activeTeacher.email.trim().toLowerCase();

              if (senderId.isNotEmpty &&
                  (senderId == myId ||
                   senderId == myCustomId ||
                   (myEmail.isNotEmpty && senderId.toLowerCase() == myEmail))) {
                return true;
              }
              if (notifType == 'teacher_announcement' &&
                  teacherName.isNotEmpty &&
                  myName.isNotEmpty &&
                  (teacherName == myName || teacherName.contains(myName) || myName.contains(teacherName))) {
                return true;
              }
              if (notifType == 'teacher_announcement' &&
                  registeredBy.isNotEmpty &&
                  myName.isNotEmpty &&
                  registeredBy.contains(myName)) {
                return true;
              }
            }
            return false;
          }).toList();

          final subjectName = activeTeacher?.subject ?? 'your subject';
          return TabBarView(
            children: [
              _buildList(
                academyNotices,
                isDark,
                'No Notices For Your Subject',
                'Registrations and fee installments for students enrolled in $subjectName will appear here.',
                activeTeacher: activeTeacher,
              ),
              _buildList(
                myAnnouncements,
                isDark,
                'No Announcements Yet',
                'Tap the "New Announcement" button below to publish your first announcement to your students.',
                activeTeacher: activeTeacher,
                isMyAnnouncementsTab: true,
              ),
            ],
          );
        },
      ),
      ),
    );
  }

  Widget _buildList(
    List<QueryDocumentSnapshot> docs,
    bool isDark,
    String emptyTitle,
    String emptySubtitle, {
    TeacherModel? activeTeacher,
    bool isMyAnnouncementsTab = false,
  }) {
    if (docs.isEmpty) {
      return _buildEmpty(emptyTitle, emptySubtitle);
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      itemCount: docs.length,
      itemBuilder: (context, i) {
        final doc = docs[i];
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return _buildNotifCard(data, i, isDark, activeTeacher: activeTeacher, isMyAnnouncementsTab: isMyAnnouncementsTab);
      },
    );
  }

  Widget _buildNotifCard(
    Map<String, dynamic> data,
    int idx,
    bool isDark, {
    TeacherModel? activeTeacher,
    bool isMyAnnouncementsTab = false,
  }) {
    final title = data['title'] as String? ?? 'Notification';
    final body =
        data['body'] as String? ?? data['message'] as String? ?? '';
    final type = data['type'] as String? ?? 'info';
    final rawRegisteredBy = data['registeredBy'] as String? ?? 'Admin';
    final teacherSubject = (data['teacherSubject'] as String? ??
            data['targetSubject'] as String? ??
            data['subject'] as String? ??
            '')
        .trim();
    final targetClass = (data['className'] as String? ??
            data['targetClass'] as String? ??
            data['class'] as String? ??
            '')
        .trim();
    final targetHour = (data['targetHour'] ??
            data['targetTime'] ??
            data['scheduleSlot'] ??
            data['targetSchedule'] ??
            '')
        .toString()
        .trim();
    final authorDisplay = (teacherSubject.isNotEmpty &&
            !rawRegisteredBy.toLowerCase().contains('admin') &&
            !rawRegisteredBy.contains('('))
        ? '$rawRegisteredBy ($teacherSubject Teacher)'
        : rawRegisteredBy;
    final mediaUrl =
        data['mediaUrl'] as String? ?? data['attachmentUrl'] as String? ?? '';
    final mediaType = data['mediaType'] as String? ??
        data['attachmentType'] as String? ??
        'none';
    final raw = data['createdAt'] ?? data['timestamp'];

    DateTime? dt;
    if (raw is Timestamp) {
      dt = raw.toDate();
    } else if (raw is String) {
      dt = DateTime.tryParse(raw);
    }

    final id = data['id'] as String? ?? '';
    final isRead = NotificationService.isNoticeRead(id);

    final isMyNotice = isMyAnnouncementsTab ||
        (activeTeacher != null &&
            ((data['senderId'] == activeTeacher.id ||
                data['senderId'] == activeTeacher.teacherId ||
                data['teacherId'] == activeTeacher.id) ||
             ((type == 'teacher_announcement' || data['notificationType'] == 'teacher_announcement') &&
              ((data['teacherName'] ?? '').toString().trim().toLowerCase() ==
                  activeTeacher.name.trim().toLowerCase() ||
               (data['registeredBy'] ?? '')
                   .toString()
                   .toLowerCase()
                   .contains(activeTeacher.name.trim().toLowerCase())))));

    final color = _colorForType(type, mediaType);
    final icon = _iconForType(type, mediaType);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isRead ? 0.5 : 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          if (id.isNotEmpty && !isRead) {
            NotificationService.markNoticeAsRead(id);
          }
          _showNoticeDetail(data, isDark, isMyNotice: isMyNotice);
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: color, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: isRead ? FontWeight.w500 : FontWeight.bold,
                          ),
                        ),
                        if (isMyNotice) ...[
                          const SizedBox(height: 2),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryBlue.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'My Announcement',
                                  style: GoogleFonts.poppins(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.primaryBlue,
                                  ),
                                ),
                              ),
                              if (targetClass.isNotEmpty)
                                Text(
                                  '• Class: $targetClass',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.lightTextSecondary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              if (targetHour.isNotEmpty && targetHour != 'All' && targetHour != 'All Hours')
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: Colors.teal.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'Batch: $targetHour',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.teal,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ] else ...[
                          Text(
                            'By: $authorDisplay',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppTheme.lightTextSecondary,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (dt != null)
                    Text(
                      DateFormat('dd MMM, hh:mm a').format(dt),
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                      ),
                    ),
                ],
              ),
              if (body.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  body,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark
                        ? AppTheme.darkTextPrimary
                        : AppTheme.lightTextPrimary,
                    height: 1.45,
                  ),
                ),
              ],
              if (mediaUrl.isNotEmpty && mediaType != 'none') ...[
                const SizedBox(height: 12),
                _buildAttachmentPreview(mediaUrl, mediaType, isDark),
              ],
            ],
          ),
        ),
      ),
    ).animate().fadeIn().slideY(begin: 0.04);
  }

  void _showNoticeDetail(Map<String, dynamic> data, bool isDark, {bool isMyNotice = false}) {
    final title = data['title'] as String? ?? 'Notification';
    final body = data['body'] as String? ?? data['message'] as String? ?? '';
    final rawRegisteredBy = data['registeredBy'] as String? ?? 'Admin';
    final teacherSubject = (data['teacherSubject'] as String? ??
            data['targetSubject'] as String? ??
            data['subject'] as String? ??
            '')
        .trim();
    final targetClass = (data['className'] as String? ??
            data['targetClass'] as String? ??
            data['class'] as String? ??
            '')
        .trim();
    final targetHour = (data['targetHour'] ??
            data['targetTime'] ??
            data['scheduleSlot'] ??
            data['targetSchedule'] ??
            '')
        .toString()
        .trim();
    final mediaUrl = data['mediaUrl'] as String? ?? data['attachmentUrl'] as String? ?? '';
    final mediaType = data['mediaType'] as String? ?? data['attachmentType'] as String? ?? 'none';
    final type = data['type'] as String? ?? 'info';
    final id = data['id'] as String? ?? '';
    final color = _colorForType(type, mediaType);
    final icon = _iconForType(type, mediaType);
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, scrollController) => Container(
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkBackground : AppTheme.lightBackground,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(24),
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(icon, color: color, size: 28),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            title,
                            style: GoogleFonts.poppins(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        if (isMyNotice)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryBlue.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'My Announcement',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.primaryBlue,
                              ),
                            ),
                          ),
                        if (teacherSubject.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppTheme.secondaryGreen.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Subject: $teacherSubject',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.secondaryGreen,
                              ),
                            ),
                          ),
                        if (targetClass.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.purple.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Class: $targetClass',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.purple,
                              ),
                            ),
                          ),
                        if (targetHour.isNotEmpty && targetHour != 'All' && targetHour != 'All Hours')
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.teal.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Batch: $targetHour',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.teal,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Published by: $rawRegisteredBy',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.lightTextSecondary,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Divider(color: isDark ? Colors.white12 : Colors.grey.shade200),
                    const SizedBox(height: 16),
                    Text(
                      body,
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.6,
                        color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                      ),
                    ),
                    if (mediaUrl.isNotEmpty && mediaType != 'none') ...[
                      const SizedBox(height: 24),
                      _buildAttachmentPreview(mediaUrl, mediaType, isDark),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => _openUrl(mediaUrl),
                          icon: Icon(
                            mediaType == 'pdf' ? Icons.picture_as_pdf_rounded : Icons.open_in_new_rounded,
                            size: 18,
                          ),
                          label: Text('Open ${mediaType.toUpperCase()}'),
                        ),
                      ),
                    ],
                    if (isMyNotice && id.isNotEmpty) ...[
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.warningRed,
                            side: const BorderSide(color: AppTheme.warningRed),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () async {
                            Navigator.pop(ctx);
                            await _confirmDeleteAnnouncement(id);
                          },
                          icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.warningRed),
                          label: Text(
                            'Delete This Announcement',
                            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDeleteAnnouncement(String notifId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete Announcement?', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Text(
          'This will permanently delete this announcement for you and all enrolled students.',
          style: GoogleFonts.poppins(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.warningRed,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await NotificationService.deleteNotification(notifId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.secondaryGreen,
            content: Text(
              'Announcement deleted successfully.',
              style: GoogleFonts.poppins(),
            ),
          ),
        );
      }
    }
  }

  Widget _buildAttachmentPreview(
      String mediaUrl, String mediaType, bool isDark) {
    if (mediaType == 'image') {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxHeight: 200),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Image.network(
            mediaUrl,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.broken_image_rounded, color: Colors.grey),
                    SizedBox(width: 8),
                    Text('Failed to load image'),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    } else if (mediaType == 'pdf') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.picture_as_pdf_rounded, color: Colors.red, size: 24),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'PDF Document Attached',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.red.shade900,
                ),
              ),
            ),
            ElevatedButton.icon(
              onPressed: () => _openUrl(mediaUrl),
              icon: const Icon(Icons.open_in_new_rounded, size: 14),
              label: const Text('View PDF', style: TextStyle(fontSize: 12)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
          ],
        ),
      );
    } else if (mediaType == 'audio') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.accentIndigo.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.accentIndigo.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.graphic_eq_rounded, color: AppTheme.accentIndigo, size: 24),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Voice Note / Audio Attachment',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primaryDarkBlue,
                ),
              ),
            ),
            ElevatedButton.icon(
              onPressed: () => _openUrl(mediaUrl),
              icon: const Icon(Icons.play_arrow_rounded, size: 16),
              label: const Text('Play Audio', style: TextStyle(fontSize: 12)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentIndigo,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Future<void> _openUrl(String url) async {
    final messenger = ScaffoldMessenger.of(context);
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not open attachment URL')),
      );
    }
  }

  Color _colorForType(String type, String mediaType) {
    if (mediaType == 'pdf') return Colors.red;
    if (mediaType == 'audio') return AppTheme.accentIndigo;
    if (mediaType == 'image') return Colors.teal;
    switch (type) {
      case 'student_registered':
        return AppTheme.secondaryGreen;
      case 'fee':
      case 'fee_payment':
      case 'second_installment':
      case 'fee_installment':
      case 'fee_payment_verified':
        return AppTheme.accentOrange;
      case 'teacher_payout':
        return Colors.teal;
      case 'warning':
        return AppTheme.warningRed;
      case 'success':
        return AppTheme.secondaryGreen;
      default:
        return AppTheme.primaryBlue;
    }
  }

  IconData _iconForType(String type, String mediaType) {
    if (mediaType == 'pdf') return Icons.picture_as_pdf_rounded;
    if (mediaType == 'audio') return Icons.mic_rounded;
    if (mediaType == 'image') return Icons.image_rounded;
    switch (type) {
      case 'student_registered':
        return Icons.school_rounded;
      case 'fee':
      case 'fee_payment':
      case 'second_installment':
      case 'fee_installment':
      case 'fee_payment_verified':
        return Icons.payments_rounded;
      case 'teacher_payout':
        return Icons.account_balance_wallet_rounded;
      case 'warning':
        return Icons.warning_rounded;
      case 'success':
        return Icons.check_circle_rounded;
      default:
        return Icons.campaign_rounded;
    }
  }

  Widget _buildEmpty(String title, String subtitle) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notifications_off_rounded,
                size: 72, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              title,
              style: GoogleFonts.poppins(
                  fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
            ),
          ],
        ),
      ),
    ).animate().fadeIn();
  }

  // ── Create & Broadcast Announcement Modal ──
  void _openCreateAnnouncementModal() {
    final teacherToUse = _currentTeacher ?? widget.teacher;
    if (teacherToUse == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Teacher profile is loading. Please try again in a moment.'),
        ),
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: _CreateAnnouncementModal(teacher: teacherToUse),
      ),
    );
  }
}

const List<String> kTeacherScheduleSlots = [
  '7:00 AM', '8:00 AM', '9:00 AM', '10:00 AM', '11:00 AM',
  '12:00 PM', '1:00 PM', '2:00 PM', '3:00 PM', '4:00 PM',
  '5:00 PM', '6:00 PM', '7:00 PM', '8:00 PM', '9:00 PM', '10:00 PM',
];

class _CreateAnnouncementModal extends StatefulWidget {
  final TeacherModel teacher;
  const _CreateAnnouncementModal({required this.teacher});

  @override
  State<_CreateAnnouncementModal> createState() =>
      __CreateAnnouncementModalState();
}

class __CreateAnnouncementModalState extends State<_CreateAnnouncementModal> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();

  late String _selectedTargetClass;
  late String _selectedTargetHour;
  Uint8List? _fileBytes;
  String? _fileName;
  String _mediaType = 'none'; // 'none' | 'image' | 'pdf' | 'audio'
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _selectedTargetClass = 'All';
    _selectedTargetHour = 'All';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _pickPicture() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.image,
        withData: true,
      );

      if (!mounted) return;

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        final bytes = file.bytes;

        if (bytes != null) {
          setState(() {
            _fileBytes = bytes;
            _fileName = file.name;
            _mediaType = 'image';
          });
        }
      }
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to select photo: $e')),
      );
    }
  }

  String _uploadStatusText = 'Publishing Announcement...';

  Future<void> _submitAnnouncement() async {
    if (!_formKey.currentState!.validate()) return;

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    setState(() {
      _isUploading = true;
      _uploadStatusText = _mediaType == 'image'
          ? 'Compressing & uploading photo...'
          : 'Publishing Announcement...';
    });

    try {
      String uploadedUrl = '';

      // Upload file to Firebase Storage if selected
      if (_fileBytes != null && _fileName != null && _mediaType == 'image') {
        final url = await TeacherService.uploadAnnouncementAttachment(
          fileBytes: _fileBytes!,
          fileName: _fileName!,
          mediaType: 'image',
        );

        if (!mounted) return;

        if (url != null) {
          uploadedUrl = url;
        } else {
          debugPrint('[TeacherNotificationsScreen] Photo upload warning: could not retrieve URL, publishing text announcement.');
        }
      }

      setState(() {
        _uploadStatusText = 'Publishing Announcement...';
      });

      await TeacherService.createTeacherAnnouncement(
        teacher: widget.teacher,
        title: _titleController.text.trim(),
        message: _messageController.text.trim(),
        mediaUrl: uploadedUrl,
        mediaType: _mediaType,
        targetClass: _selectedTargetClass,
        targetHour: _selectedTargetHour,
      );

      if (!mounted) {
        setState(() => _isUploading = false);
        return;
      }

      messenger.showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.secondaryGreen,
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Announcement successfully published to ${widget.teacher.subject} students!',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
      );
      navigator.pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUploading = false);
      messenger.showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.warningRed,
          content: Text('Error publishing announcement: $e'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.all(24),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryBlue.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.campaign_rounded,
                        color: AppTheme.primaryBlue, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Post New Announcement',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Broadcast written announcement to ${widget.teacher.subject} (${widget.teacher.section})',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.lightTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Target Class Dropdown
              DropdownButtonFormField<String>(
                value: _selectedTargetClass,
                decoration: InputDecoration(
                  labelText: 'Target Class / Audience',
                  prefixIcon: const Icon(Icons.class_rounded),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                items: [
                  DropdownMenuItem(
                    value: 'All',
                    child: Text('All ${widget.teacher.section} Students (${widget.teacher.subject})'),
                  ),
                  ...widget.teacher.assignedClasses.map(
                    (cls) => DropdownMenuItem(
                      value: cls,
                      child: Text('$cls Class (${widget.teacher.subject})'),
                    ),
                  ),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _selectedTargetClass = val);
                  }
                },
              ),
              const SizedBox(height: 16),

              // Target Hour / Batch Dropdown
              DropdownButtonFormField<String>(
                value: _selectedTargetHour,
                decoration: InputDecoration(
                  labelText: 'Target Hour / Schedule Slot',
                  prefixIcon: const Icon(Icons.access_time_filled_rounded),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  helperText: _selectedTargetHour == 'All'
                      ? 'Delivered to all students in the selected class'
                      : 'Delivered ONLY to students registered at $_selectedTargetHour',
                ),
                items: [
                  const DropdownMenuItem(
                    value: 'All',
                    child: Text('All Time Slots / Hours (All Registered Batches)'),
                  ),
                  ...kTeacherScheduleSlots.map(
                    (slot) => DropdownMenuItem(
                      value: slot,
                      child: Text('Batch / Slot: $slot'),
                    ),
                  ),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _selectedTargetHour = val);
                  }
                },
              ),
              const SizedBox(height: 16),

              // Title Field
              TextFormField(
                controller: _titleController,
                validator: (val) => val == null || val.trim().isEmpty
                    ? 'Please enter an announcement title'
                    : null,
                decoration: InputDecoration(
                  labelText: 'Announcement Title',
                  hintText: 'e.g. Tomorrow Class Schedule / Test Result',
                  prefixIcon: const Icon(Icons.title_rounded),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Message Body Field
              TextFormField(
                controller: _messageController,
                maxLines: 4,
                validator: (val) => val == null || val.trim().isEmpty
                    ? 'Please write your message'
                    : null,
                decoration: InputDecoration(
                  labelText: 'Written Message',
                  hintText: 'Type your message or details for the students...',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Picture Attachment Button (PDF and Voice Note removed)
              Text(
                'Add Picture / Photo (Optional):',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _pickPicture,
                  icon: const Icon(Icons.add_photo_alternate_rounded, size: 20, color: AppTheme.primaryBlue),
                  label: Text(
                    _fileName == null ? 'Attach Picture / Photo' : 'Change Picture',
                    style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),

              // Selected Picture Preview Card
              if (_fileName != null && _mediaType == 'image') ...[
                const SizedBox(height: 14),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlue.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppTheme.primaryBlue.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.image_rounded,
                        color: AppTheme.primaryBlue,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _fileName!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              'Photo Attached',
                              style: TextStyle(
                                fontSize: 10,
                                color: AppTheme.lightTextSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded,
                            color: AppTheme.warningRed, size: 20),
                        onPressed: () {
                          setState(() {
                            _fileBytes = null;
                            _fileName = null;
                            _mediaType = 'none';
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // Submit Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isUploading ? null : _submitAnnouncement,
                  icon: _isUploading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send_rounded),
                  label: Text(
                    _isUploading
                        ? _uploadStatusText
                        : 'PUBLISH ANNOUNCEMENT',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
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
