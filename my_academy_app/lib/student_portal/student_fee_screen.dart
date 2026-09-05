import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/payment_config_model.dart';
import '../models/payment_transaction_model.dart';
import '../models/student_model.dart';
import '../services/payment_service.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_card.dart';
import '../widgets/empty_state_widget.dart';
import '../widgets/shimmer_loading_widget.dart';
import 'student_auth_service.dart';

class StudentFeeScreen extends StatefulWidget {
  const StudentFeeScreen({super.key});

  @override
  State<StudentFeeScreen> createState() => _StudentFeeScreenState();
}

class _StudentFeeScreenState extends State<StudentFeeScreen> {
  StudentModel? _student;
  bool _isLoading = true;
  String? _errorMessage;
  StreamSubscription<DocumentSnapshot>? _studentSubscription;

  @override
  void initState() {
    super.initState();
    _initRealTimeListener();
  }

  @override
  void dispose() {
    _studentSubscription?.cancel();
    super.dispose();
  }

  void _initRealTimeListener() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final session = await StudentAuthService.getLocalSession();
      if (session == null) {
        setState(() => _errorMessage = 'Session expired. Please re-login.');
        return;
      }
      final studentId = session['studentId'] as String? ?? '';
      final studentCode = session['studentCode'] as String?;

      final student = await StudentAuthService.fetchCurrentStudent(
        studentId: studentId,
        studentCode: studentCode,
      );

      if (student != null) {
        _studentSubscription?.cancel();
        _studentSubscription = FirebaseFirestore.instance
            .collection('students')
            .doc(student.id)
            .snapshots()
            .listen((doc) {
          if (doc.exists && mounted) {
            setState(() {
              _student = StudentModel.fromFirestore(doc);
              _isLoading = false;
            });
          }
        }, onError: (e) {
          if (mounted) {
            setState(() {
              _errorMessage = 'Failed to sync fee data.';
              _isLoading = false;
            });
          }
        });

        if (mounted) {
          setState(() {
            _student = student;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _errorMessage = 'Student fee record not found. Contact the academy.';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load fee data.';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _refreshData() async {
    _initRealTimeListener();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackground : AppTheme.lightBackground,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text('Fee Management', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? ListView(
              padding: const EdgeInsets.all(20),
              children: const [
                ShimmerLoadingWidget(width: double.infinity, height: 160, borderRadius: 20),
                SizedBox(height: 20),
                ShimmerLoadingWidget(width: double.infinity, height: 120, borderRadius: 16),
              ],
            )
          : (_errorMessage != null || _student == null)
              ? EmptyStateWidget(
                  title: 'Fee Status Error',
                  description: _errorMessage ?? 'Student fee record not found. Contact the academy.',
                  icon: Icons.account_balance_wallet_outlined,
                  actionLabel: 'Retry',
                  onAction: _initRealTimeListener,
                )
              : RefreshIndicator(
                  onRefresh: _refreshData,
                  color: AppTheme.primaryBlue,
                  child: _buildContent(),
                ),
    );
  }

  Widget _buildContent() {
    if (_student == null) return const SizedBox.shrink();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final student = _student!;
    final subjects = {
      'Biology': student.biologyFee,
      'Physics': student.physicsFee,
      'Chemistry': student.chemistryFee,
      'English': student.englishFee,
      'Math': student.mathFee,
    }..removeWhere((_, fee) => fee <= 0);

    final feePercent = student.totalFee > 0
        ? (student.feeSubmitted / student.totalFee).clamp(0.0, 1.0)
        : 0.0;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Overall Summary Banner Card
        CustomCard(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Academic Fee Status',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: student.feeRemaining <= 0
                          ? AppTheme.secondaryGreen.withValues(alpha: 0.15)
                          : AppTheme.warningRed.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      student.feeRemaining <= 0 ? 'Fully Cleared' : 'Balance Pending',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: student.feeRemaining <= 0 ? AppTheme.secondaryGreen : AppTheme.warningRed,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _statChip('Total Due', student.totalFee, AppTheme.primaryBlue),
                  ),
                  Container(width: 1, height: 44, color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
                  Expanded(
                    child: _statChip('Submitted', student.feeSubmitted, AppTheme.secondaryGreen),
                  ),
                  Container(width: 1, height: 44, color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
                  Expanded(
                    child: _statChip(
                      'Remaining',
                      student.feeRemaining,
                      student.feeRemaining > 0 ? AppTheme.warningRed : AppTheme.secondaryGreen,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Stack(
                children: [
                  Container(
                    height: 12,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  FractionallySizedBox(
                    widthFactor: feePercent,
                    child: Container(
                      height: 12,
                      decoration: BoxDecoration(
                        gradient: feePercent >= 1.0 ? AppTheme.successGradient : AppTheme.primaryGradient,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                student.feeRemaining <= 0
                    ? '✓ All course fees have been paid in full.'
                    : '${(feePercent * 100).toStringAsFixed(0)}% of total fee submitted.',
                style: TextStyle(
                  fontSize: 12,
                  color: student.feeRemaining <= 0 ? AppTheme.secondaryGreen : (isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary),
                  fontWeight: student.feeRemaining <= 0 ? FontWeight.bold : FontWeight.w500,
                ),
              ),

              const SizedBox(height: 16),
              // Pay Fee Action Button
              if (student.feeRemaining > 0)
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () => _showPayFeeModal(context, student),
                    icon: const Icon(Icons.payment_rounded, color: Colors.white, size: 20),
                    label: Text(
                      'PAY FEE ONLINE / BANK',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.secondaryGreen,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ).animate().fadeIn(),

        const SizedBox(height: 24),

        if (subjects.isNotEmpty) ...[
          Row(
            children: [
              const Icon(Icons.menu_book_rounded, size: 18, color: AppTheme.primaryBlue),
              const SizedBox(width: 8),
              Text(
                'Subject-wise Breakdown',
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...subjects.entries.map((entry) {
            final subName = entry.key;
            final totalSubFee = entry.value;
            final paidSub = student.getSubjectPaid(subName);
            final dueSub = student.getSubjectRemaining(subName);
            final subPercent =
                totalSubFee > 0 ? (paidSub / totalSubFee).clamp(0.0, 1.0) : 0.0;

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: CustomCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          subName,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: dueSub <= 0
                                ? AppTheme.secondaryGreen.withValues(alpha: 0.12)
                                : AppTheme.accentOrange.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            dueSub <= 0 ? 'PAID' : 'Rs ${dueSub.toStringAsFixed(0)} due',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: dueSub <= 0 ? AppTheme.secondaryGreen : AppTheme.accentOrange,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: subPercent,
                        minHeight: 8,
                        backgroundColor: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey.shade200,
                        valueColor: AlwaysStoppedAnimation(
                          subPercent >= 1.0 ? AppTheme.secondaryGreen : AppTheme.primaryBlue,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Total: Rs ${totalSubFee.toStringAsFixed(0)}',
                            style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        Text('Paid: Rs ${paidSub.toStringAsFixed(0)}',
                            style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.secondaryGreen,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              ),
            ).animate().fadeIn();
          }),
        ],

        // Online & Firestore Payment Transactions Section
        const SizedBox(height: 16),
        _buildOnlineTransactionsLog(student),

        // Legacy / Offline Payment History Section
        const SizedBox(height: 16),
        if (student.paymentHistoryJson != null &&
            student.paymentHistoryJson!.isNotEmpty)
          _buildPaymentHistory(student),

        const SizedBox(height: 60),
      ],
    );
  }

  Widget _buildOnlineTransactionsLog(StudentModel student) {
    return StreamBuilder<List<PaymentTransactionModel>>(
      stream: PaymentService.getStudentTransactionsStream(student.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()));
        }
        final transactions = snapshot.data ?? [];
        if (transactions.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.receipt_long_rounded, size: 18, color: AppTheme.primaryBlue),
                const SizedBox(width: 8),
                Text('Online & Verified Payment Records',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 15)),
              ],
            ),
            const SizedBox(height: 12),
            CustomCard(
              padding: EdgeInsets.zero,
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: transactions.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final txn = transactions[i];
                  final statusBadge = _buildStatusBadge(txn.status);
                  final dateStr = DateFormat('dd MMM yyyy, hh:mm a').format(txn.createdAt);

                  return ListTile(
                    onTap: () => _showReceiptDialog(context, txn),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: statusBadge.color.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(statusBadge.icon, color: statusBadge.color, size: 20),
                    ),
                    title: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'Ref: ${txn.providerTransactionId}',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          'Rs ${txn.amount.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: statusBadge.color,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(txn.provider, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                            const SizedBox(width: 8),
                            statusBadge.widget,
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(dateStr, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                      ],
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPaymentHistory(StudentModel student) {
    List<dynamic> history = [];
    try {
      history = (student.paymentHistoryJson != null
          ? jsonDecode(student.paymentHistoryJson!) as List
          : []);
    } catch (_) {}

    if (history.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.history_rounded, size: 18, color: AppTheme.primaryBlue),
            const SizedBox(width: 8),
            Text('Academy Ledger Records', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 15)),
          ],
        ),
        const SizedBox(height: 12),
        CustomCard(
          padding: EdgeInsets.zero,
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: history.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final rawEntry = history[i];
              if (rawEntry is! Map) return const SizedBox.shrink();
              final entry = Map<String, dynamic>.from(rawEntry);
              final rawAmt = entry['amount'];
              final double amount = rawAmt is num
                  ? rawAmt.toDouble()
                  : (double.tryParse(rawAmt?.toString() ?? '') ?? 0.0);
              final date = entry['date']?.toString() ?? '';
              final note = entry['note']?.toString() ?? '';
              DateTime? parsed;
              try {
                parsed = DateTime.parse(date);
              } catch (_) {}

              return ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: amount > 0 ? AppTheme.secondaryGreen.withValues(alpha: 0.12) : AppTheme.warningRed.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    amount > 0 ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                    color: amount > 0 ? AppTheme.secondaryGreen : AppTheme.warningRed,
                    size: 18,
                  ),
                ),
                title: Text(
                  note.isNotEmpty ? note : 'Fee Payment Received',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                subtitle: parsed != null
                    ? Text(
                        '${parsed.day}/${parsed.month}/${parsed.year}',
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      )
                    : null,
                trailing: Text(
                  'Rs ${amount.abs().toStringAsFixed(0)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: amount > 0 ? AppTheme.secondaryGreen : AppTheme.warningRed,
                    fontSize: 14,
                  ),
                ),
              );
            },
          ),
        ).animate().fadeIn(),
      ],
    );
  }

  void _showPayFeeModal(BuildContext context, StudentModel student) async {
    final config = await PaymentService.getPaymentConfigOnce();

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _PayFeeFormModal(student: student, config: config),
    );
  }

  void _showReceiptDialog(BuildContext context, PaymentTransactionModel txn) {
    final statusBadge = _buildStatusBadge(txn.status);
    final dateStr = DateFormat('dd MMMM yyyy, hh:mm a').format(txn.createdAt);

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Icon(Icons.receipt_rounded, color: AppTheme.primaryBlue),
              const SizedBox(width: 10),
              const Expanded(
                child: Text('Official Payment Receipt', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    children: [
                      _receiptRow('Academy', 'Quaid Academy'),
                      _receiptRow('Student', txn.studentName ?? 'N/A'),
                      _receiptRow('Student Code', txn.studentCode ?? 'N/A'),
                      const Divider(),
                      _receiptRow('Amount Paid', 'Rs ${txn.amount.toStringAsFixed(0)}', isBold: true),
                      _receiptRow('Payment Method', txn.provider),
                      _receiptRow('Transaction Ref', txn.providerTransactionId, isMonospace: true),
                      _receiptRow('Date & Time', dateStr),
                      const Divider(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Status', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          statusBadge.widget,
                        ],
                      ),
                      if (txn.verifiedBy != null) ...[
                        const SizedBox(height: 6),
                        _receiptRow('Verified By', txn.verifiedBy!),
                      ],
                      if (txn.failureReason != null && txn.failureReason!.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        _receiptRow('Rejection Reason', txn.failureReason!, isDanger: true),
                      ],
                      const SizedBox(height: 10),
                      const Divider(),
                      const Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Text(
                          "PAYMENT STATUS IS BASED ON THE ACADEMY'S VERIFIED RECORD.",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close Receipt'),
            ),
          ],
        );
      },
    );
  }

  Widget _receiptRow(String label, String value, {bool isBold = false, bool isMonospace = false, bool isDanger = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
                fontFamily: isMonospace ? 'monospace' : null,
                color: isDanger ? AppTheme.warningRed : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  _StatusBadge _buildStatusBadge(String status) {
    switch (status) {
      case PaymentTransactionStatus.successful:
        return _StatusBadge(
          icon: Icons.check_circle_rounded,
          color: AppTheme.secondaryGreen,
          widget: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: AppTheme.secondaryGreen.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
            child: const Text('✅ Successful', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.secondaryGreen)),
          ),
        );
      case PaymentTransactionStatus.verificationRequired:
        return _StatusBadge(
          icon: Icons.hourglass_top_rounded,
          color: Colors.amber.shade800,
          widget: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: Colors.amber.shade100, borderRadius: BorderRadius.circular(6)),
            child: Text('⚠️ Verification Pending', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.amber.shade900)),
          ),
        );
      case PaymentTransactionStatus.pending:
      case PaymentTransactionStatus.processing:
        return _StatusBadge(
          icon: Icons.sync_rounded,
          color: AppTheme.accentOrange,
          widget: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: AppTheme.accentOrange.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
            child: const Text('⏳ Processing', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.accentOrange)),
          ),
        );
      case PaymentTransactionStatus.rejected:
      case PaymentTransactionStatus.failed:
        return _StatusBadge(
          icon: Icons.cancel_rounded,
          color: AppTheme.warningRed,
          widget: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: AppTheme.warningRed.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
            child: const Text('❌ Rejected / Failed', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.warningRed)),
          ),
        );
      case PaymentTransactionStatus.refunded:
        return _StatusBadge(
          icon: Icons.undo_rounded,
          color: Colors.purple,
          widget: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: Colors.purple.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
            child: const Text('↩️ Refunded', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.purple)),
          ),
        );
      default:
        return _StatusBadge(
          icon: Icons.info_outline_rounded,
          color: Colors.grey,
          widget: Text(status, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        );
    }
  }

  Widget _statChip(String label, double amount, Color color) {
    return Column(
      children: [
        Text(
          'Rs ${amount.toStringAsFixed(0)}',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }
}

class _StatusBadge {
  final IconData icon;
  final Color color;
  final Widget widget;
  _StatusBadge({required this.icon, required this.color, required this.widget});
}

class _PayFeeFormModal extends StatefulWidget {
  final StudentModel student;
  final PaymentConfigModel config;

  const _PayFeeFormModal({required this.student, required this.config});

  @override
  State<_PayFeeFormModal> createState() => _PayFeeFormModalState();
}

class _PayFeeFormModalState extends State<_PayFeeFormModal> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _refController = TextEditingController();
  final _noteController = TextEditingController();

  late String _selectedMethod;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _amountController.text = widget.student.feeRemaining.toStringAsFixed(0);
    _selectedMethod = 'BANK_TRANSFER';
  }

  @override
  void dispose() {
    _amountController.dispose();
    _refController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _submitPayment() async {
    if (!_formKey.currentState!.validate()) return;
    final amount = double.tryParse(_amountController.text.trim()) ?? 0.0;
    final ref = _refController.text.trim();
    final note = _noteController.text.trim();

    final providerName = _selectedMethod == 'BANK_TRANSFER'
        ? widget.config.bankName
        : (_selectedMethod == 'EASYPAISA' ? 'Easypaisa' : (_selectedMethod == 'JAZZCASH' ? 'JazzCash' : 'Gateway'));

    // Show Confirmation Dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Confirm Payment Submission', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('You are submitting a payment of Rs ${amount.toStringAsFixed(0)} to Quaid Academy.'),
              const SizedBox(height: 12),
              Text('• Recipient: Quaid Academy', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
              Text('• Payment Method: $providerName', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
              Text('• Transaction Reference #: $ref', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
              const SizedBox(height: 12),
              const Text('Your transaction will be set to Pending Verification for academy verification.',
                  style: TextStyle(fontSize: 11, color: Colors.amber, fontWeight: FontWeight.bold)),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.secondaryGreen),
              child: const Text('Confirm & Submit', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    setState(() => _isSubmitting = true);

    try {
      final txn = await PaymentService.submitStudentFeePayment(
        student: widget.student,
        amount: amount,
        paymentMethod: _selectedMethod,
        providerName: providerName,
        providerTransactionId: ref,
        description: note.isNotEmpty ? note : 'Student Fee Payment',
      );

      if (mounted) {
        setState(() => _isSubmitting = false);
        Navigator.pop(context);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.secondaryGreen,
            content: Text('Payment ref ${txn.providerTransactionId} submitted successfully! Pending verification.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: AppTheme.warningRed, content: Text('Error: ${e.toString().replaceAll('Exception: ', '')}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        top: 20,
        left: 20,
        right: 20,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
              ),
              const SizedBox(height: 16),
              Text('Pay Academy Fee', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
              Text('Select method and submit transaction reference for verification', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              const SizedBox(height: 16),

              // Payment Method Choice
              const Text('Select Payment Method', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  if (widget.config.isBankTransferEnabled)
                    ChoiceChip(
                      label: const Text('Bank Transfer'),
                      selected: _selectedMethod == 'BANK_TRANSFER',
                      onSelected: (_) => setState(() => _selectedMethod = 'BANK_TRANSFER'),
                    ),
                  if (widget.config.isEasypaisaEnabled)
                    ChoiceChip(
                      label: const Text('Easypaisa'),
                      selected: _selectedMethod == 'EASYPAISA',
                      onSelected: (_) => setState(() => _selectedMethod = 'EASYPAISA'),
                    ),
                  if (widget.config.isJazzcashEnabled)
                    ChoiceChip(
                      label: const Text('JazzCash'),
                      selected: _selectedMethod == 'JAZZCASH',
                      onSelected: (_) => setState(() => _selectedMethod = 'JAZZCASH'),
                    ),
                ],
              ),
              const SizedBox(height: 14),

              // Bank / Account Details Card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: Colors.indigo.shade50, borderRadius: BorderRadius.circular(14)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Academy Account Details:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.indigo.shade900)),
                    const SizedBox(height: 6),
                    if (_selectedMethod == 'BANK_TRANSFER') ...[
                      Text('• Bank: ${widget.config.bankName}', style: const TextStyle(fontSize: 12)),
                      Text('• Title: ${widget.config.accountTitle}', style: const TextStyle(fontSize: 12)),
                      Text('• Account #: ${widget.config.accountNumber}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      Text('• IBAN: ${widget.config.iban}', style: const TextStyle(fontSize: 11, fontFamily: 'monospace')),
                    ] else if (_selectedMethod == 'EASYPAISA') ...[
                      Text('• Merchant: ${widget.config.easypaisaTitle}', style: const TextStyle(fontSize: 12)),
                      Text('• Easypaisa #: ${widget.config.easypaisaNumber}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    ] else ...[
                      Text('• Merchant: ${widget.config.jazzcashTitle}', style: const TextStyle(fontSize: 12)),
                      Text('• JazzCash #: ${widget.config.jazzcashNumber}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Amount Input
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Payment Amount (PKR)',
                  prefixIcon: const Icon(Icons.payments_rounded),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Enter amount';
                  final numVal = double.tryParse(val.trim());
                  if (numVal == null || numVal <= 0) return 'Enter valid amount';
                  return null;
                },
              ),
              const SizedBox(height: 14),

              // Reference # Input
              TextFormField(
                controller: _refController,
                decoration: InputDecoration(
                  labelText: 'Transaction Reference / TRX ID',
                  hintText: 'e.g. TRX-987654321 or Bank Ref #',
                  prefixIcon: const Icon(Icons.tag_rounded),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Please enter transaction reference / TRX ID';
                  return null;
                },
              ),
              const SizedBox(height: 14),

              // Note Input
              TextFormField(
                controller: _noteController,
                decoration: InputDecoration(
                  labelText: 'Note / Details (Optional)',
                  hintText: 'e.g. Paid via mobile app transfer',
                  prefixIcon: const Icon(Icons.note_alt_rounded),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
              const SizedBox(height: 20),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _isSubmitting ? null : _submitPayment,
                  icon: _isSubmitting ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.send_rounded, color: Colors.white),
                  label: Text(_isSubmitting ? 'Submitting...' : 'Submit Payment for Verification', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryBlue,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
