import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/notification_model.dart';
import '../theme/app_theme.dart';
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

      // Fetch notifications sorted by timestamp and filter in-memory to prevent complex composite index configuration
      final snapshot = await FirebaseFirestore.instance
          .collection('notifications')
          .orderBy('timestamp', descending: true)
          .limit(100)
          .get()
          .timeout(const Duration(seconds: 10));

      final allNotices = snapshot.docs
          .map((doc) => NotificationModel.fromMap(doc.data(), doc.id))
          .toList();

      // Filter in-memory: broadcast (studentId is empty) OR direct student notifications
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
      backgroundColor: isDark ? AppTheme.darkBackground : const Color(0xFFF5F7FA),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(
          'Notice Board',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
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
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline_rounded, size: 48, color: Colors.red),
                      const SizedBox(height: 12),
                      Text(_errorMessage!),
                      const SizedBox(height: 12),
                      ElevatedButton(onPressed: _loadNotices, child: const Text('Retry')),
                    ],
                  ),
                )
              : _notices.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.mark_chat_read_rounded, size: 64, color: Colors.grey.shade400),
                          const SizedBox(height: 16),
                          const Text(
                            'No notices published yet.',
                            style: TextStyle(fontSize: 15, color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadNotices,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _notices.length,
                        itemBuilder: (context, index) {
                          final item = _notices[index];
                          
                          // Styling variables based on notificationType
                          IconData leadingIcon = Icons.campaign_rounded;
                          Color themeColor = AppTheme.primaryBlue;
                          Color bgActiveColor = AppTheme.primaryBlue.withValues(alpha: 0.08);

                          if (item.notificationType == 'student_registered') {
                            leadingIcon = Icons.school_rounded;
                            themeColor = Colors.blue;
                            bgActiveColor = Colors.blue.shade50.withValues(alpha: 0.5);
                          } else if (item.notificationType == 'fee_payment' || item.notificationType == 'second_installment') {
                            leadingIcon = Icons.payments_rounded;
                            themeColor = Colors.green;
                            bgActiveColor = Colors.green.shade50.withValues(alpha: 0.5);
                          } else if (item.notificationType == 'broadcast') {
                            leadingIcon = Icons.campaign_rounded;
                            themeColor = Colors.deepOrange;
                            bgActiveColor = Colors.deepOrange.shade50.withValues(alpha: 0.5);
                          }

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              leading: CircleAvatar(
                                backgroundColor: bgActiveColor,
                                child: Icon(leadingIcon, color: themeColor),
                              ),
                              title: Text(
                                item.title,
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 6),
                                  Text(
                                    item.message,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: isDark ? Colors.grey.shade300 : Colors.grey.shade800,
                                      height: 1.3,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'By: ${item.registeredBy}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                      Text(
                                        DateFormat('MMM dd, yyyy • hh:mm a').format(item.timestamp),
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ).animate().fadeIn(delay: (index * 50).ms).slideX(begin: 0.05);
                        },
                      ),
                    ),
    );
  }
}
