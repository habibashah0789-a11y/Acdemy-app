import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Send WhatsApp Reminders', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Text(
          'This will open WhatsApp for each of the ${filtered.length} student(s) with pending fees.\n\n'
          'Students without a phone number will be skipped.\n\n'
          'You will need to click "Send" in WhatsApp for each message.\n\n'
          'Continue?',
        ),
        actions: [
          OutlinedButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF25D366),
                foregroundColor: Colors.white),
            child: const Text('Start Sending'),
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

        await Future.delayed(const Duration(milliseconds: 1500));
      } catch (e) {
        setState(() {
          _sendStatus[student.id] = 'error';
          _skippedCount++;
        });
      }
    }

    if (mounted) {
      setState(() => _isSending = false);
      _logReminderNotification();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Reminders finished! Sent: $_sentCount, Skipped: $_skippedCount',
          ),
          backgroundColor: AppTheme.secondaryGreen,
        ),
      );
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
      backgroundColor: isDark ? AppTheme.darkBackground : AppTheme.lightBackground,
      appBar: AppBar(
        title: Text('Fee Reminders', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
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
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _summaryItem(
                              icon: Icons.people_outline,
                              label: 'Pending Defaulters',
                              value: '${filtered.length}',
                            ),
                            Container(width: 1, height: 44, color: Colors.white24),
                            _summaryItem(
                              icon: Icons.money_off_rounded,
                              label: 'Total Outstanding Dues',
                              value: 'Rs. ${NumberFormat('#,##0').format(totalPending)}',
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
                            valueColor: const AlwaysStoppedAnimation(Colors.greenAccent),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Sending... $_sentCount sent, $_skippedCount skipped',
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

                // Send All WhatsApp Reminders Button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: (_isSending || filtered.isEmpty) ? null : _sendToAll,
                      icon: _isSending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.send_rounded, color: Colors.white),
                      label: Text(
                        _isSending
                            ? 'Sending Reminders...'
                            : 'Send WhatsApp Reminders (${filtered.length})',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF25D366),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
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
                                            onTap: () {
                                              final msg = _buildReminderMessage(student);
                                              WhatsAppHelper.openWhatsApp(context, student.phone, msg);
                                            },
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF25D366).withValues(alpha: 0.12),
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
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.white70),
        ),
      ],
    );
  }
}
