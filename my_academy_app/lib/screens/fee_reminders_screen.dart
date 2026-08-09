import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/student_model.dart';
import '../models/notification_model.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';
import '../services/fee_defaulters_print_service.dart';
import '../utils/whatsapp_helper.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_card.dart';
import '../widgets/empty_state_widget.dart';
import '../widgets/shimmer_loading_widget.dart';

class FeeRemindersScreen extends StatefulWidget {
  const FeeRemindersScreen({super.key});

  @override
  State<FeeRemindersScreen> createState() => _FeeRemindersScreenState();
}

class _FeeRemindersScreenState extends State<FeeRemindersScreen> {
  List<StudentModel> _defaulters = [];
  final Map<String, String> _sendStatus = {};
  bool _isLoading = true;
  bool _isSending = false;
  bool _isPrinting = false;
  int _sentCount = 0;
  String _filterGrade = 'All';

  final List<String> _gradeFilters = [
    'All',
    'Class 9',
    'Class 10',
    '1st Year',
    '2nd Year'
  ];

  @override
  void initState() {
    super.initState();
    _loadDefaulters();
  }

  Future<void> _loadDefaulters() async {
    setState(() => _isLoading = true);
    try {
      List<StudentModel> allStudents;
      try {
        allStudents = await DatabaseService.getAllStudentsFromFirestore();
      } catch (_) {
        allStudents = DatabaseService.getAllStudentsLocal();
      }
      final defaulters = allStudents
          .where((s) => s.feeRemaining > 0 && s.isActive)
          .toList();
      defaulters.sort((a, b) => b.feeRemaining.compareTo(a.feeRemaining));
      setState(() {
        _defaulters = defaulters;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error loading students: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  bool _matchesGrade(StudentModel s, String filter) {
    if (filter == 'All') return true;
    final grade = s.grade.toLowerCase().trim();
    final classType = s.classType.toLowerCase().trim();

    if (filter == 'Class 9') {
      return grade.contains('9') || grade.contains('ninth');
    }
    if (filter == 'Class 10') {
      return grade.contains('10') || grade.contains('tenth');
    }
    if (filter == '1st Year') {
      return grade.contains('11') || grade.contains('first') || grade.contains('1st');
    }
    if (filter == '2nd Year') {
      return grade.contains('12') || grade.contains('second') || grade.contains('2nd');
    }
    return grade == filter.toLowerCase() || classType == filter.toLowerCase();
  }

  List<StudentModel> get _filteredDefaulters {
    return _defaulters
        .where((s) => _matchesGrade(s, _filterGrade))
        .toList();
  }

  String _buildReminderMessage(StudentModel student) {
    final profile = DatabaseService.getAcademyProfile();
    final academyName = profile['name']?.toString().isNotEmpty == true
        ? profile['name'].toString()
        : 'Quaid Academy';

    return 'Assalam o Alaikum,\n\n'
        'Dear Parent/Guardian of *${student.name}*,\n\n'
        'This is a reminder from *$academyName* regarding the pending fee balance.\n\n'
        '📋 *Fee Details:*\n'
        '• Total Fee: Rs. ${student.totalFee.toStringAsFixed(0)}\n'
        '• Paid: Rs. ${student.feeSubmitted.toStringAsFixed(0)}\n'
        '• Remaining: Rs. ${student.feeRemaining.toStringAsFixed(0)}\n\n'
        'Kindly clear the pending dues at your earliest convenience.\n\n'
        'Thank you,\n$academyName';
  }

  Future<void> _sendPushToAll() async {
    final filtered = _filteredDefaulters;
    if (filtered.isEmpty) return;

    final targetLabel = _filterGrade == 'All' ? 'All Classes' : _filterGrade;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: AppTheme.primaryBlue.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: const Icon(Icons.notifications_active_rounded, color: AppTheme.primaryBlue, size: 22),
            ),
            const SizedBox(width: 10),
            Text('Send Fee Alerts', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'This will send a personalized fee reminder notification to each of the ${filtered.length} defaulter student(s) in $targetLabel directly on their Student Portal.\n\n'
          'Each student will see ONLY their own fee breakdown (Total, Paid, Remaining) and hear a notification sound.',
        ),
        actions: [
          OutlinedButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryBlue, foregroundColor: Colors.white),
            child: Text('Send to $targetLabel'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isSending = true);
    int sent = 0;
    for (final student in filtered) {
      await NotificationService.createFeeReminderNotificationForStudent(student: student);
      sent++;
      if (mounted) setState(() => _sentCount = sent);
    }
    if (mounted) {
      await _logReminderNotification(sent, _filterGrade);
      setState(() {
        _isSending = false;
        _sentCount = 0;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Sent fee alerts to $sent student(s) in $targetLabel on their portals!'),
          backgroundColor: AppTheme.primaryBlue,
        ),
      );
    }
  }

  Future<void> _logReminderNotification(int count, String targetClass) async {
    try {
      await NotificationService.init();
      final classLabel = targetClass == 'All' ? 'all classes' : targetClass;
      final notification = NotificationModel(
        id: 'fee_reminder_${DateTime.now().millisecondsSinceEpoch}',
        title: 'Fee Alerts Sent ($classLabel)',
        message: 'Successfully dispatched fee push alerts to $count defaulter student(s) in $classLabel.',
        studentName: 'Admin Summary',
        className: targetClass,
        subject: '',
        registeredBy: FirebaseAuth.instance.currentUser?.email ?? 'Administrator',
        timestamp: DateTime.now(),
        notificationType: 'fee_reminder_summary',
        isRead: false,
        studentId: 'admin_only', // ONLY visible to admin portal
      );
      try {
        await FirebaseFirestore.instance
            .collection('notifications')
            .doc(notification.id)
            .set(notification.toMap());
      } catch (e) {
        debugPrint('Failed to save reminder notification: $e');
      }
    } catch (e) {
      debugPrint('Failed to log reminder notification: $e');
    }
  }

  Future<void> _logIndividualWhatsAppReminderNotification(StudentModel student) async {
    try {
      await NotificationService.init();
      final notification = NotificationModel(
        id: 'wa_reminder_${student.id}_${DateTime.now().millisecondsSinceEpoch}',
        title: 'WhatsApp Reminder Sent',
        message: 'Student "${student.name}" has received a fee reminder from the admin.',
        studentName: student.name,
        className: student.classType,
        subject: student.subject,
        registeredBy: FirebaseAuth.instance.currentUser?.email ?? 'Administrator',
        timestamp: DateTime.now(),
        notificationType: 'fee_reminder',
        isRead: false,
        studentId: student.id,
      );
      try {
        await FirebaseFirestore.instance
            .collection('notifications')
            .doc(notification.id)
            .set(notification.toMap());
      } catch (e) {
        debugPrint('Failed to save individual reminder notification: $e');
      }
    } catch (e) {
      debugPrint('Failed to log individual reminder notification: $e');
    }
  }

  Future<void> _printDefaulters() async {
    final filtered = _filteredDefaulters;
    if (filtered.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No defaulters to print.')),
        );
      }
      return;
    }
    setState(() => _isPrinting = true);
    try {
      // 30-second overall guard — PDF generation + file I/O + URL launch
      // should never take longer than this. If it does, release the button.
      await FeeDefaultersPrintService.printDefaultersList(filtered)
          .timeout(const Duration(seconds: 30));
    } catch (e) {
      if (mounted) {
        final msg = e.toString().contains('TimeoutException')
            ? 'Print timed out. Please try again.'
            : 'Print failed: $e';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isPrinting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final filtered = _filteredDefaulters;
    final totalPending =
        filtered.fold<double>(0, (total, s) => total + s.feeRemaining);

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackground : AppTheme.lightBackground,
      appBar: AppBar(
        title: Text('Fee Reminders', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
        actions: [
          if (_isPrinting)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.0,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Preparing PDF...',
                    style: GoogleFonts.poppins(color: Colors.white, fontSize: 12),
                  ),
                ],
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.print_rounded),
              tooltip: 'Print Defaulters List',
              onPressed: filtered.isEmpty ? null : _printDefaulters,
            ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: _isLoading ? null : _loadDefaulters,
          ),
        ],
      ),
      body: _isLoading
          ? ListView(
              padding: const EdgeInsets.all(20),
              children: const [
                ShimmerLoadingWidget(width: double.infinity, height: 140, borderRadius: 20),
                SizedBox(height: 16),
                ShimmerLoadingWidget(width: double.infinity, height: 80, borderRadius: 14),
              ],
            )
          : Column(
              children: [
                // Summary Card
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: CustomCard(
                    gradient: AppTheme.primaryGradient,
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        LayoutBuilder(
                          builder: (context, constraints) {
                            if (constraints.maxWidth >= 360) {
                              return Row(
                                children: [
                                  Expanded(
                                    child: _summaryItem(
                                      icon: Icons.people_outline,
                                      label: 'Pending Defaulters',
                                      value: '${filtered.length}',
                                    ),
                                  ),
                                  Container(width: 1, height: 44, color: Colors.white24),
                                  Expanded(
                                    child: _summaryItem(
                                      icon: Icons.money_off_rounded,
                                      label: 'Total Outstanding Dues',
                                      value: 'Rs. ${NumberFormat('#,##0').format(totalPending)}',
                                    ),
                                  ),
                                ],
                              );
                            }

                            return Column(
                              children: [
                                _summaryItem(
                                  icon: Icons.people_outline,
                                  label: 'Pending Defaulters',
                                  value: '${filtered.length}',
                                ),
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 8),
                                  child: Divider(color: Colors.white24),
                                ),
                                _summaryItem(
                                  icon: Icons.money_off_rounded,
                                  label: 'Total Outstanding Dues',
                                  value: 'Rs. ${NumberFormat('#,##0').format(totalPending)}',
                                ),
                              ],
                            );
                          },
                        ),
                        if (_isSending) ...[
                          const SizedBox(height: 16),
                          LinearProgressIndicator(
                            value: filtered.isNotEmpty
                                ? _sentCount / filtered.length
                                : 0,
                            backgroundColor: Colors.white24,
                            valueColor: const AlwaysStoppedAnimation(Colors.greenAccent),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Sending alerts... $_sentCount of ${filtered.length} sent',
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                // Grade Filter Choice Chips
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _gradeFilters.map((grade) {
                        final isSelected = _filterGrade == grade;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(grade),
                            selected: isSelected,
                            selectedColor: AppTheme.primaryBlue,
                            backgroundColor: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.shade100,
                            onSelected: (_) => setState(() => _filterGrade = grade),
                            labelStyle: TextStyle(
                              fontSize: 12,
                              color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            ),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Send Push Reminders Button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: InlineLoadingButton(
                      isLoading: _isSending,
                      label: 'Send Push Fee Alerts (${filtered.length})',
                      loadingLabel: 'Sending Alerts...',
                      icon: Icons.notifications_active_rounded,
                      onPressed: filtered.isEmpty ? null : _sendPushToAll,
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Defaulter Students List
                Expanded(
                  child: filtered.isEmpty
                      ? EmptyStateWidget(
                          title: _defaulters.isEmpty ? 'All Dues Cleared 🎉' : 'No Defaulters in Class',
                          description: 'No students have outstanding fee balances for this selection.',
                          icon: Icons.check_circle_outline_rounded,
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final student = filtered[index];
                            final status = _sendStatus[student.id];

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: CustomCard(
                                padding: const EdgeInsets.all(14),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: AppTheme.warningRed.withValues(alpha: 0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.person, color: AppTheme.warningRed, size: 22),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            student.name,
                                            style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '${student.grade} • ID: ${student.studentCode}',
                                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          'Rs. ${student.feeRemaining.toStringAsFixed(0)}',
                                          style: GoogleFonts.poppins(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                            color: AppTheme.warningRed,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        if (status == 'sent')
                                          const Text('Sent ✓', style: TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold))
                                        else if (status == 'skipped')
                                          const Text('No Phone', style: TextStyle(color: Colors.orange, fontSize: 11))
                                        else
                                          InkWell(
                                            onTap: () async {
                                              final msg = _buildReminderMessage(student);
                                              await WhatsAppHelper.openWhatsApp(context, student.phone, msg);
                                              await _logIndividualWhatsAppReminderNotification(student);
                                              setState(() {
                                                _sendStatus[student.id] = 'sent';
                                              });
                                            },
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: Color(0xFF25D366).withValues(alpha: 0.12),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: const Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(Icons.send_rounded, size: 10, color: Color(0xFF25D366)),
                                                  SizedBox(width: 4),
                                                  Text('Remind', style: TextStyle(color: Color(0xFF25D366), fontSize: 10, fontWeight: FontWeight.bold)),
                                                ],
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _summaryItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12, color: Colors.white70),
        ),
      ],
    );
  }
}
