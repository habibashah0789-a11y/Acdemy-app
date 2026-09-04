import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/notification_model.dart';
import '../services/notification_service.dart';
import '../services/teacher_service.dart';
import '../theme/app_theme.dart';
import '../screens/notification_settings_screen.dart';
import '../widgets/shimmer_loading_widget.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late final Stream<List<NotificationModel>> _stream;

  @override
  void initState() {
    super.initState();
    _stream = NotificationService.notificationsStream();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_rounded),
            tooltip: 'Notification Settings',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NotificationSettingsScreen()),
              );
            },
          ),
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'mark_all') {
                await NotificationService.markAllAsRead();
              } else if (value == 'clear_all') {
                await NotificationService.clearAllNotifications();
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'mark_all', child: Text('Mark all as read')),
              PopupMenuItem(value: 'clear_all', child: Text('Clear all')),
            ],
          ),
        ],
      ),
      body: StreamBuilder<List<NotificationModel>>(
        stream: _stream,
        initialData: NotificationService.getCachedNotifications(),
        builder: (context, snapshot) {
          final items = snapshot.data ?? [];
          if (items.isEmpty && snapshot.connectionState == ConnectionState.waiting) {
            return ListView.builder(
              itemCount: 6,
              itemBuilder: (context, _) => ShimmerLoadingWidget.listTilePlaceholder(context),
            );
          }
          if (items.isEmpty) {
            return const Center(child: Text('No notifications yet'));
          }
          return ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final item = items[index];
              // Colors & Icons based on type
              IconData leadingIcon = Icons.notifications_active_outlined;
              Color activeColor = Colors.blue;
              Color bgActiveColor = Colors.blue.shade50;

              if (item.notificationType == 'student_registered') {
                leadingIcon = Icons.person_add_alt_1;
                activeColor = Colors.blue;
                bgActiveColor = Colors.blue.shade50;
              } else if (item.notificationType == 'fee_payment') {
                leadingIcon = Icons.payments_rounded;
                activeColor = Colors.green;
                bgActiveColor = Colors.green.shade50;
              } else if (item.notificationType == 'second_installment') {
                leadingIcon = Icons.account_balance_wallet_rounded;
                activeColor = Colors.purple;
                bgActiveColor = Colors.purple.shade50;
              }

              return Dismissible(
                key: ValueKey(item.id),
                background: Container(color: Colors.red.withValues(alpha: 0.2)),
                onDismissed: (_) async => NotificationService.deleteNotification(item.id),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: item.isRead ? Colors.grey.shade200 : bgActiveColor,
                    child: Icon(
                      leadingIcon,
                      color: item.isRead ? Colors.grey : activeColor,
                    ),
                  ),
                  title: Row(
                    children: [
                      Expanded(child: Text(item.title, style: const TextStyle(fontWeight: FontWeight.bold))),
                      if (!item.isRead)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                        ),
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(item.message),
                      const SizedBox(height: 6),
                      Text(DateFormat('MMM dd, yyyy • hh:mm a').format(item.timestamp), style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) async {
                      if (value == 'read') {
                        await NotificationService.markAsRead(item.id);
                      } else if (value == 'delete') {
                        await NotificationService.deleteNotification(item.id);
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'read', child: Text('Mark as read')),
                      PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ],
                  ),
                  onTap: () async {
                    if (!item.isRead) {
                      await NotificationService.markAsRead(item.id);
                    }
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: null,
        onPressed: _showCreateNotificationDialog,
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add_comment_rounded),
      ),
    );
  }

  void _showCreateNotificationDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: const _AdminCreateAnnouncementModal(),
      ),
    );
  }
}

class _AdminCreateAnnouncementModal extends StatefulWidget {
  const _AdminCreateAnnouncementModal();

  @override
  State<_AdminCreateAnnouncementModal> createState() =>
      __AdminCreateAnnouncementModalState();
}

class __AdminCreateAnnouncementModalState
    extends State<_AdminCreateAnnouncementModal> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();

  String _targetClass = 'All'; // 'All' | '9th' | '10th' | '1st Year' | '2nd Year'
  Uint8List? _fileBytes;
  String? _fileName;
  String _mediaType = 'none'; // 'none' | 'image' | 'pdf' | 'audio'
  bool _isUploading = false;
  String _uploadStatusText = 'Publishing Announcement...';

  final List<Map<String, String>> _classOptions = [
    {'value': 'All', 'label': '📢 All Academy Students'},
    {'value': '9th', 'label': '🎓 9th Class'},
    {'value': '10th', 'label': '🎓 10th Class'},
    {'value': '1st Year', 'label': '🏫 1st Year (11th)'},
    {'value': '2nd Year', 'label': '🏫 2nd Year (12th)'},
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _pickAttachment(String type) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      FileType fileType = FileType.any;
      List<String>? allowedExtensions;

      if (type == 'image') {
        fileType = FileType.image;
      } else if (type == 'pdf') {
        fileType = FileType.custom;
        allowedExtensions = ['pdf'];
      } else if (type == 'audio') {
        fileType = FileType.audio;
      }

      final result = await FilePicker.pickFiles(
        type: fileType,
        allowedExtensions: fileType == FileType.custom ? allowedExtensions : null,
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
            _mediaType = type;
          });
        }
      }
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to select file: $e')),
      );
    }
  }

  Future<void> _submitAnnouncement() async {
    if (!_formKey.currentState!.validate()) return;

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    setState(() {
      _isUploading = true;
      _uploadStatusText = _mediaType == 'image'
          ? 'Compressing & uploading photo...'
          : _mediaType != 'none'
              ? 'Uploading attachment...'
              : 'Publishing Announcement...';
    });

    try {
      String uploadedUrl = '';

      if (_fileBytes != null && _fileName != null && _mediaType != 'none') {
        final url = await TeacherService.uploadAnnouncementAttachment(
          fileBytes: _fileBytes!,
          fileName: _fileName!,
          mediaType: _mediaType,
        );

        if (!mounted) return;

        if (url != null) {
          uploadedUrl = url;
        } else {
          throw Exception('Failed to upload attachment to storage.');
        }
      }

      setState(() => _uploadStatusText = 'Publishing Announcement...');

      final docRef = FirebaseFirestore.instance.collection('notifications').doc();
      final titleText = _titleController.text.trim();
      final messageText = _messageController.text.trim();

      final data = {
        'id': docRef.id,
        'title': titleText,
        'body': messageText,
        'message': messageText,
        'registeredBy': FirebaseAuth.instance.currentUser?.email ?? 'Administration',
        'senderId': FirebaseAuth.instance.currentUser?.uid ?? 'admin',
        'subject': 'General',
        'targetSubject': 'General',
        'class': _targetClass,
        'targetSection': 'All',
        'timestamp': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'type': 'announcement',
        'notificationType': 'admin_announcement',
        'isRead': false,
        'mediaUrl': uploadedUrl,
        'attachmentUrl': uploadedUrl,
        'mediaType': _mediaType,
        'attachmentType': _mediaType,
        'studentId': '', // Empty means broadcast to target class
      };

      await docRef.set(data);

      // Trigger FCM push notification
      final topic = _targetClass == 'All' ? 'academy_all' : 'class_${_targetClass.replaceAll(' ', '_').toLowerCase()}';
      await NotificationService.triggerPushNotification(
        targetTopic: topic,
        title: '📢 $titleText',
        body: messageText,
        channelId: NotificationService.defaultChannelId,
        payload: {
          'type': 'announcement',
          'screen': 'notifications',
        },
      );

      if (!mounted) return;

      messenger.showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.secondaryGreen,
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Announcement published to ${_targetClass == "All" ? "All Academy Students" : "$_targetClass Students"}!',
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
                          'Admin Announcement',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Broadcast official notice with optional media',
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

              // Target Class Dropdown Selector
              Text(
                'Target Audience:',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _targetClass,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.groups_rounded, color: AppTheme.primaryBlue),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
                items: _classOptions
                    .map(
                      (opt) => DropdownMenuItem<String>(
                        value: opt['value'],
                        child: Text(
                          opt['label']!,
                          style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _targetClass = val);
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
                  hintText: 'e.g. Academy Holiday / Exam Schedule',
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
                  hintText: 'Type official details for students...',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Attachment Selection Buttons
              Text(
                'Add Media Attachment (Optional):',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickAttachment('image'),
                      icon: const Icon(Icons.image_rounded, size: 18),
                      label: const Text('Picture', style: TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickAttachment('pdf'),
                      icon: const Icon(Icons.picture_as_pdf_rounded,
                          size: 18, color: Colors.red),
                      label: const Text('PDF', style: TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickAttachment('audio'),
                      icon: const Icon(Icons.mic_rounded,
                          size: 18, color: AppTheme.accentIndigo),
                      label: const Text('Voice Note',
                          style: TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              // Selected Attachment Preview Card
              if (_fileName != null && _mediaType != 'none') ...[
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
                      Icon(
                        _mediaType == 'image'
                            ? Icons.image_rounded
                            : _mediaType == 'pdf'
                                ? Icons.picture_as_pdf_rounded
                                : Icons.mic_rounded,
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
                              'Type: ${_mediaType.toUpperCase()}',
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
                    _isUploading ? _uploadStatusText : 'PUBLISH ANNOUNCEMENT',
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
