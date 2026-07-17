import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/student_model.dart';
import '../models/notification_model.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';
import '../services/fee_defaulters_print_service.dart';
import '../utils/whatsapp_helper.dart';
import '../theme/app_theme.dart';

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
  int _skippedCount = 0;
  String _filterGrade = 'All';

  final List<String> _gradeFilters = [
    'All',
    'Ninth',
    'Tenth',
    'First Year',
    'Second Year'
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

  List<StudentModel> get _filteredDefaulters {
    if (_filterGrade == 'All') return _defaulters;
    return _defaulters
        .where((s) => s.grade.toLowerCase() == _filterGrade.toLowerCase())
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

  Future<void> _sendToAll() async {
    final filtered = _filteredDefaulters;
    if (filtered.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Send WhatsApp Reminders'),
        content: Text(
          'This will open WhatsApp for each of the ${filtered.length} student(s) with pending fees.\n\n'
          'Students without a phone number will be skipped.\n\n'
          'You will need to click "Send" in WhatsApp for each message.\n\n'
          'Continue?',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF25D366)),
            child: const Text('Start Sending',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _isSending = true;
      _sentCount = 0;
      _skippedCount = 0;
      _sendStatus.clear();
    });

    for (final student in filtered) {
      if (!mounted) break;

      final phone = student.phone.trim();
      if (phone.isEmpty || phone.length < 7) {
        setState(() {
          _sendStatus[student.id] = 'skipped';
          _skippedCount++;
        });
        continue;
      }

      try {
        final message = _buildReminderMessage(student);
        if (mounted) {
          await WhatsAppHelper.openWhatsApp(context, phone, message);
        }
        setState(() {
          _sendStatus[student.id] = 'sent';
          _sentCount++;
        });
        // Give the user time to send message in WhatsApp before opening next
        await Future.delayed(const Duration(seconds: 3));
      } catch (e) {
        setState(() {
          _sendStatus[student.id] = 'failed';
          _skippedCount++;
        });
      }
    }

    // Log a notification about the reminders
    await _logReminderNotification();

    if (mounted) {
      setState(() => _isSending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('Done! Sent: $_sentCount, Skipped: $_skippedCount'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  Future<void> _sendToOne(StudentModel student) async {
    final phone = student.phone.trim();
    if (phone.isEmpty || phone.length < 7) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No valid phone number for this student.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }
    final message = _buildReminderMessage(student);
    if (mounted) {
      await WhatsAppHelper.openWhatsApp(context, phone, message);
      setState(() => _sendStatus[student.id] = 'sent');
    }
  }

  Future<void> _logReminderNotification() async {
    try {
      await NotificationService.init();
      final notification = NotificationModel(
        id: 'fee_reminder_${DateTime.now().millisecondsSinceEpoch}',
        title: 'Fee Reminders Sent',
        message:
            'Sent fee reminders to $_sentCount student(s). Skipped $_skippedCount.',
        studentName: '',
        className: '',
        subject: '',
        registeredBy: 'System',
        timestamp: DateTime.now(),
        notificationType: 'fee_reminder',
        isRead: false,
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

  Future<void> _printDefaulters() async {
    final filtered = _filteredDefaulters;
    if (filtered.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No defaulters to print.')),
      );
      return;
    }
    setState(() => _isPrinting = true);
    try {
      await FeeDefaultersPrintService.printDefaultersList(filtered);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Print failed: $e'),
              backgroundColor: Colors.red),
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
      appBar: AppBar(
        title: const Text('Fee Reminders'),
        actions: [
          if (_isPrinting)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5, color: Colors.white)),
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
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Summary Card
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isDark
                          ? [const Color(0xFF1A237E), const Color(0xFF0D47A1)]
                          : [AppTheme.primaryBlue, const Color(0xFF1565C0)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryBlue.withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _summaryItem(
                            icon: Icons.people_outline,
                            label: 'Defaulters',
                            value: '${filtered.length}',
                          ),
                          Container(
                              width: 1,
                              height: 40,
                              color: Colors.white24),
                          _summaryItem(
                            icon: Icons.money_off_rounded,
                            label: 'Total Pending',
                            value:
                                'Rs.${NumberFormat('#,##0').format(totalPending)}',
                          ),
                        ],
                      ),
                      if (_isSending) ...[
                        const SizedBox(height: 16),
                        LinearProgressIndicator(
                          value: filtered.isNotEmpty
                              ? (_sentCount + _skippedCount) / filtered.length
                              : 0,
                          backgroundColor: Colors.white24,
                          valueColor: const AlwaysStoppedAnimation(
                              Colors.greenAccent),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Sending... $_sentCount sent, $_skippedCount skipped',
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ],
                  ),
                ),

                // Grade Filter Chips
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SizedBox(
                    height: 36,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _gradeFilters.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final grade = _gradeFilters[index];
                        final isSelected = _filterGrade == grade;
                        return ChoiceChip(
                          label: Text(grade,
                              style: TextStyle(
                                  fontSize: 12,
                                  color:
                                      isSelected ? Colors.white : null)),
                          selected: isSelected,
                          selectedColor: AppTheme.primaryBlue,
                          onSelected: (_) =>
                              setState(() => _filterGrade = grade),
                          visualDensity: VisualDensity.compact,
                        );
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                // Send All Button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: (_isSending || filtered.isEmpty)
                          ? null
                          : _sendToAll,
                      icon: _isSending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.send_rounded,
                              color: Colors.white),
                      label: Text(
                        _isSending
                            ? 'Sending Reminders...'
                            : 'Send Reminders to All (${filtered.length})',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF25D366),
                        disabledBackgroundColor: Colors.grey.shade400,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Student List
                Expanded(
                  child: filtered.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.check_circle_outline,
                                  size: 64,
                                  color:
                                      Colors.green.withValues(alpha: 0.5)),
                              const SizedBox(height: 16),
                              Text(
                                _defaulters.isEmpty
                                    ? 'No fee defaulters! 🎉'
                                    : 'No defaulters in this class.',
                                style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final student = filtered[index];
                            return _buildStudentCard(
                                student, index, isDark);
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
        Icon(icon, color: Colors.white70, size: 22),
        const SizedBox(height: 6),
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(label,
            style:
                const TextStyle(color: Colors.white60, fontSize: 11)),
      ],
    );
  }

  Widget _buildStudentCard(
      StudentModel student, int index, bool isDark) {
    final status = _sendStatus[student.id];
    final hasPhone =
        student.phone.trim().isNotEmpty && student.phone.trim().length >= 7;

    Color statusColor;
    IconData statusIcon;
    String statusText;

    switch (status) {
      case 'sent':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        statusText = 'Sent';
        break;
      case 'skipped':
        statusColor = Colors.orange;
        statusIcon = Icons.skip_next_rounded;
        statusText = 'Skipped';
        break;
      case 'failed':
        statusColor = Colors.red;
        statusIcon = Icons.error_outline;
        statusText = 'Failed';
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.schedule;
        statusText = 'Pending';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Index number
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text('${index + 1}',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryBlue,
                        fontSize: 13)),
              ),
            ),
            const SizedBox(width: 12),

            // Student Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(student.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 2),
                  Text(
                    '${student.classType} ${student.grade} • ${student.phone.isEmpty ? "No phone" : student.phone}',
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Due: Rs.${student.feeRemaining.toStringAsFixed(0)}',
                          style: const TextStyle(
                              color: Colors.red,
                              fontSize: 11,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (status != null)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(statusIcon,
                                size: 14, color: statusColor),
                            const SizedBox(width: 3),
                            Text(statusText,
                                style: TextStyle(
                                    fontSize: 10,
                                    color: statusColor)),
                          ],
                        ),
                    ],
                  ),
                ],
              ),
            ),

            // WhatsApp Button
            IconButton(
              icon: Icon(
                Icons.chat_rounded,
                color: hasPhone
                    ? const Color(0xFF25D366)
                    : Colors.grey.shade400,
              ),
              tooltip:
                  hasPhone ? 'Send WhatsApp Reminder' : 'No phone number',
              onPressed:
                  hasPhone && !_isSending ? () => _sendToOne(student) : null,
            ),
          ],
        ),
      ),
    );
  }
}
