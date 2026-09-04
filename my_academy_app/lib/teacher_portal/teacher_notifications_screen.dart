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
import '../theme/app_theme.dart';

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

  @override
  void initState() {
    super.initState();
    _currentTeacher = widget.teacher;
    if (_currentTeacher == null) {
      _loadTeacherProfile();
    }
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

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Announcements & Notices',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
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
            .orderBy('createdAt', descending: true)
            .limit(60)
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

          final docs = snapshot.data?.docs ?? [];
          final filtered = docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final targetSubject =
                (data['targetSubject'] as String? ?? '').toLowerCase();
            final targetSection =
                (data['targetSection'] as String? ?? '').toLowerCase();
            if (_currentTeacher == null ||
                targetSubject.isEmpty ||
                targetSubject == 'all' ||
                targetSection == 'all') {
              return true;
            }
            final mySubject = _currentTeacher!.subject.toLowerCase();
            final mySection = _currentTeacher!.section.toLowerCase();
            return targetSubject == mySubject &&
                (targetSection.isEmpty || targetSection == mySection);
          }).toList();

          if (filtered.isEmpty) {
            return _buildEmpty();
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
            itemCount: filtered.length,
            itemBuilder: (context, i) {
              final data = filtered[i].data() as Map<String, dynamic>;
              return _buildNotifCard(data, i, isDark);
            },
          );
        },
      ),
    );
  }

  Widget _buildNotifCard(Map<String, dynamic> data, int idx, bool isDark) {
    final title = data['title'] as String? ?? 'Notification';
    final body =
        data['body'] as String? ?? data['message'] as String? ?? '';
    final type = data['type'] as String? ?? 'info';
    final registeredBy = data['registeredBy'] as String? ?? 'Admin';
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

    final color = _colorForType(type, mediaType);
    final icon = _iconForType(type, mediaType);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'By: $registeredBy',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.lightTextSecondary,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
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
    ).animate().fadeIn(delay: (idx * 50).ms).slideY(begin: 0.04);
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
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open attachment URL')),
      );
    }
  }

  Color _colorForType(String type, String mediaType) {
    if (mediaType == 'pdf') return Colors.red;
    if (mediaType == 'audio') return AppTheme.accentIndigo;
    if (mediaType == 'image') return Colors.teal;
    switch (type) {
      case 'warning':
        return AppTheme.warningRed;
      case 'success':
        return AppTheme.secondaryGreen;
      case 'fee':
        return AppTheme.accentOrange;
      default:
        return AppTheme.primaryBlue;
    }
  }

  IconData _iconForType(String type, String mediaType) {
    if (mediaType == 'pdf') return Icons.picture_as_pdf_rounded;
    if (mediaType == 'audio') return Icons.mic_rounded;
    if (mediaType == 'image') return Icons.image_rounded;
    switch (type) {
      case 'warning':
        return Icons.warning_rounded;
      case 'success':
        return Icons.check_circle_rounded;
      case 'fee':
        return Icons.payments_rounded;
      default:
        return Icons.campaign_rounded;
    }
  }

  Widget _buildEmpty() {
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
              'No Announcements Yet',
              style: GoogleFonts.poppins(
                  fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap the button below to publish your first announcement to your students.',
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

  Uint8List? _fileBytes;
  String? _fileName;
  String _mediaType = 'none'; // 'none' | 'image' | 'pdf' | 'audio'
  bool _isUploading = false;

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _pickAttachment(String type) async {
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

      final result = await FilePicker.platform.pickFiles(
        type: fileType,
        allowedExtensions: allowedExtensions,
        withData: true,
      );

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
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to select file: $e')),
      );
    }
  }

  Future<void> _submitAnnouncement() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isUploading = true);

    try {
      String uploadedUrl = '';

      // Upload file to Firebase Storage if selected
      if (_fileBytes != null && _fileName != null && _mediaType != 'none') {
        final url = await TeacherService.uploadAnnouncementAttachment(
          fileBytes: _fileBytes!,
          fileName: _fileName!,
          mediaType: _mediaType,
        );

        if (url != null) {
          uploadedUrl = url;
        } else {
          throw Exception('Failed to upload attachment to storage.');
        }
      }

      // Publish announcement doc to Firestore
      await TeacherService.createTeacherAnnouncement(
        teacher: widget.teacher,
        title: _titleController.text.trim(),
        message: _messageController.text.trim(),
        mediaUrl: uploadedUrl,
        mediaType: _mediaType,
      );

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
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
      Navigator.of(context).pop();
    } catch (e) {
      if (!context.mounted) return;
      setState(() => _isUploading = false);
      ScaffoldMessenger.of(context).showSnackBar(
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
                          'Broadcast to ${widget.teacher.subject} (${widget.teacher.section})',
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
                    _isUploading
                        ? 'Publishing Announcement...'
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
