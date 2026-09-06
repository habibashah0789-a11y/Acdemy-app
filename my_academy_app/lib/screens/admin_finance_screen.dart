import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/payment_config_model.dart';
import '../models/payment_transaction_model.dart';
import '../models/teacher_payout_model.dart';
import '../services/audit_log_service.dart';
import '../services/payment_service.dart';
import '../services/teacher_payout_service.dart';
import '../teachers/record_teacher_payment_modal.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_card.dart';

class AdminFinanceScreen extends StatefulWidget {
  const AdminFinanceScreen({super.key});

  @override
  State<AdminFinanceScreen> createState() => _AdminFinanceScreenState();
}

class _AdminFinanceScreenState extends State<AdminFinanceScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _statusFilter = 'ALL';
  String _methodFilter = 'ALL';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackground : AppTheme.lightBackground,
      appBar: AppBar(
        title: Text(
          'Financial Management & Payouts',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.indigo.shade900,
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: AppTheme.secondaryGreen,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: const [
            Tab(icon: Icon(Icons.verified_user_rounded), text: 'Pending Verification'),
            Tab(icon: Icon(Icons.receipt_long_rounded), text: 'All Transactions'),
            Tab(icon: Icon(Icons.people_alt_rounded), text: 'Teacher Payouts'),
            Tab(icon: Icon(Icons.account_balance_rounded), text: 'Payment Config'),
            Tab(icon: Icon(Icons.security_rounded), text: 'Audit Log'),
          ],
        ),
      ),
      body: StreamBuilder<List<PaymentTransactionModel>>(
        stream: PaymentService.getAllTransactionsStream(),
        builder: (context, snapshot) {
          final allTransactions = snapshot.data ?? [];
          final pendingCount = allTransactions
              .where((t) => t.status == PaymentTransactionStatus.verificationRequired || t.status == PaymentTransactionStatus.pending)
              .length;

          return Column(
            children: [
              // Dashboard Metrics Summary Header
              _buildMetricsHeader(allTransactions, pendingCount),

              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // Tab 1: Pending Verifications
                    _buildPendingVerificationsTab(allTransactions),

                    // Tab 2: All Transactions Search & Filter
                    _buildAllTransactionsTab(allTransactions),

                    // Tab 3: Teacher Payouts
                    _buildTeacherPayoutsTab(),

                    // Tab 4: Academy Payment Config
                    _buildPaymentConfigTab(),

                    // Tab 5: Audit Log
                    _buildAuditLogTab(),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMetricsHeader(List<PaymentTransactionModel> transactions, int pendingCount) {
    final double totalCollected = transactions
        .where((t) => t.status == PaymentTransactionStatus.successful)
        .fold(0.0, (sum, t) => sum + t.amount);

    final now = DateTime.now();
    final double todayCollected = transactions
        .where((t) => t.status == PaymentTransactionStatus.successful && t.createdAt.year == now.year && t.createdAt.month == now.month && t.createdAt.day == now.day)
        .fold(0.0, (sum, t) => sum + t.amount);

    final int failedCount = transactions
        .where((t) => t.status == PaymentTransactionStatus.rejected || t.status == PaymentTransactionStatus.failed)
        .length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.indigo.shade900,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
      ),
      child: Row(
        children: [
          Expanded(child: _metricCard('Total Verified Revenue', 'Rs ${NumberFormat('#,##0').format(totalCollected)}', AppTheme.secondaryGreen)),
          Container(width: 1, height: 36, color: Colors.white24),
          Expanded(child: _metricCard('Today\'s Revenue', 'Rs ${NumberFormat('#,##0').format(todayCollected)}', Colors.lightBlueAccent)),
          Container(width: 1, height: 36, color: Colors.white24),
          Expanded(child: _metricCard('Pending Verification', '$pendingCount Pending', pendingCount > 0 ? Colors.amberAccent : Colors.white)),
          Container(width: 1, height: 36, color: Colors.white24),
          Expanded(child: _metricCard('Rejected/Failed', '$failedCount Failed', Colors.redAccent)),
        ],
      ),
    );
  }

  Widget _metricCard(String label, String value, Color valueColor) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: valueColor), overflow: TextOverflow.ellipsis),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.white70), textAlign: TextAlign.center, overflow: TextOverflow.ellipsis),
      ],
    );
  }

  // ── Tab 1: Pending Verifications Queue ──
  Widget _buildPendingVerificationsTab(List<PaymentTransactionModel> allTransactions) {
    final pendingList = allTransactions
        .where((t) =>
            t.status == PaymentTransactionStatus.verificationRequired ||
            t.status == PaymentTransactionStatus.pending)
        .toList();

    if (pendingList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline_rounded, size: 64, color: AppTheme.secondaryGreen.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            const Text('No Pending Verifications', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            const Text('All student payments have been verified and processed.', style: TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: pendingList.length,
      itemBuilder: (context, index) {
        final txn = pendingList[index];
        final dateStr = DateFormat('dd MMM yyyy, hh:mm a').format(txn.createdAt);

        return Card(
          margin: const EdgeInsets.only(bottom: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.amber.shade300, width: 1.2)),
          color: Colors.amber.shade50.withValues(alpha: 0.3),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: Colors.amber.shade100, shape: BoxShape.circle),
                          child: Icon(Icons.hourglass_top_rounded, color: Colors.amber.shade900, size: 20),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(txn.studentName ?? 'Student', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            Text('Code: ${txn.studentCode ?? 'N/A'}', style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
                          ],
                        ),
                      ],
                    ),
                    Text('Rs ${NumberFormat('#,##0').format(txn.amount)}', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.indigo.shade900)),
                  ],
                ),
                const Divider(height: 20),

                Row(
                  children: [
                    Expanded(child: _detailText('Provider Method', txn.provider)),
                    Expanded(child: _detailText('Transaction Ref', txn.providerTransactionId, isMonospace: true)),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(child: _detailText('Submitted Date', dateStr)),
                    Expanded(child: _detailText('Note', txn.description)),
                  ],
                ),

                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _promptRejectDialog(context, txn),
                        icon: const Icon(Icons.close_rounded, color: AppTheme.warningRed, size: 18),
                        label: const Text('Reject Payment', style: TextStyle(color: AppTheme.warningRed, fontWeight: FontWeight.bold)),
                        style: OutlinedButton.styleFrom(side: const BorderSide(color: AppTheme.warningRed), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _verifyPayment(context, txn),
                        icon: const Icon(Icons.check_rounded, color: Colors.white, size: 18),
                        label: const Text('Approve & Verify', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.secondaryGreen, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _detailText(String label, String value, {bool isMonospace = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, fontFamily: isMonospace ? 'monospace' : null), overflow: TextOverflow.ellipsis),
      ],
    );
  }

  void _verifyPayment(BuildContext context, PaymentTransactionModel txn) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Verify & Approve Payment', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to verify Rs ${txn.amount.toStringAsFixed(0)} for ${txn.studentName}? This will automatically update the student\'s remaining fee record in Firestore.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.secondaryGreen),
            child: const Text('Approve Payment', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true || !context.mounted) return;

    try {
      await PaymentService.verifyPaymentByAdmin(
        transactionId: txn.transactionId,
        adminName: 'Academy Admin',
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: AppTheme.secondaryGreen, content: Text('Payment ref ${txn.providerTransactionId} verified successfully!')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: AppTheme.warningRed, content: Text('Error verifying payment: $e')),
        );
      }
    }
  }

  void _promptRejectDialog(BuildContext context, PaymentTransactionModel txn) {
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject Payment Submission', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Provide reason for rejecting transaction ref ${txn.providerTransactionId}:'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(hintText: 'e.g. Invalid reference number or unpaid bank transfer', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final reason = reasonController.text.trim();
              if (reason.isEmpty) return;
              Navigator.pop(ctx);
              try {
                await PaymentService.rejectPaymentByAdmin(
                  transactionId: txn.transactionId,
                  adminName: 'Academy Admin',
                  failureReason: reason,
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(backgroundColor: AppTheme.warningRed, content: Text('Payment rejected.')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.warningRed),
            child: const Text('Reject Payment', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ── Tab 2: All Transactions Search & Filter ──
  Widget _buildAllTransactionsTab(List<PaymentTransactionModel> allTransactions) {
    final filtered = allTransactions.where((t) {
      if (_statusFilter != 'ALL' && t.status != _statusFilter) return false;
      if (_methodFilter != 'ALL' && t.paymentMethod != _methodFilter) return false;
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchRef = t.providerTransactionId.toLowerCase().contains(q);
        final matchStudent = (t.studentName ?? '').toLowerCase().contains(q);
        final matchCode = (t.studentCode ?? '').toLowerCase().contains(q);
        final matchTeacher = (t.teacherName ?? '').toLowerCase().contains(q);
        if (!matchRef && !matchStudent && !matchCode && !matchTeacher) return false;
      }
      return true;
    }).toList();

    return Column(
      children: [
        // Search & Filter Bar
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              TextField(
                controller: _searchController,
                onChanged: (v) => setState(() => _searchQuery = v),
                decoration: InputDecoration(
                  hintText: 'Search by Ref ID, Student name, or Code...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _searchQuery.isNotEmpty ? IconButton(icon: const Icon(Icons.clear), onPressed: () => setState(() { _searchController.clear(); _searchQuery = ''; })) : null,
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _statusFilter,
                      decoration: const InputDecoration(labelText: 'Status Filter', contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 4)),
                      items: const [
                        DropdownMenuItem(value: 'ALL', child: Text('All Statuses')),
                        DropdownMenuItem(value: PaymentTransactionStatus.successful, child: Text('✅ Successful')),
                        DropdownMenuItem(value: PaymentTransactionStatus.verificationRequired, child: Text('⚠️ Pending Verification')),
                        DropdownMenuItem(value: PaymentTransactionStatus.rejected, child: Text('❌ Rejected')),
                        DropdownMenuItem(value: PaymentTransactionStatus.refunded, child: Text('↩️ Refunded')),
                      ],
                      onChanged: (v) => setState(() => _statusFilter = v ?? 'ALL'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _methodFilter,
                      decoration: const InputDecoration(labelText: 'Method Filter', contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 4)),
                      items: const [
                        DropdownMenuItem(value: 'ALL', child: Text('All Methods')),
                        DropdownMenuItem(value: 'BANK_TRANSFER', child: Text('Bank Transfer')),
                        DropdownMenuItem(value: 'EASYPAISA', child: Text('Easypaisa')),
                        DropdownMenuItem(value: 'JAZZCASH', child: Text('JazzCash')),
                      ],
                      onChanged: (v) => setState(() => _methodFilter = v ?? 'ALL'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        Expanded(
          child: filtered.isEmpty
              ? const Center(child: Text('No transactions match your search/filter.'))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: filtered.length,
                  itemBuilder: (context, i) {
                    final t = filtered[i];
                    final dateStr = DateFormat('dd MMM yyyy, hh:mm a').format(t.createdAt);

                    return CustomCard(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: _statusColor(t.status).withValues(alpha: 0.15),
                          child: Icon(_statusIcon(t.status), color: _statusColor(t.status), size: 20),
                        ),
                        title: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(t.studentName ?? t.payerName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            Text('Rs ${NumberFormat('#,##0').format(t.amount)}', style: TextStyle(fontWeight: FontWeight.bold, color: _statusColor(t.status))),
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Ref: ${t.providerTransactionId} • ${t.provider}', style: const TextStyle(fontSize: 11, fontFamily: 'monospace')),
                            Text('$dateStr • Status: ${t.status}', style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case PaymentTransactionStatus.successful: return AppTheme.secondaryGreen;
      case PaymentTransactionStatus.verificationRequired: return Colors.amber.shade800;
      case PaymentTransactionStatus.rejected:
      case PaymentTransactionStatus.failed: return AppTheme.warningRed;
      case PaymentTransactionStatus.refunded: return Colors.purple;
      default: return Colors.blue;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case PaymentTransactionStatus.successful: return Icons.check_circle_rounded;
      case PaymentTransactionStatus.verificationRequired: return Icons.hourglass_top_rounded;
      case PaymentTransactionStatus.rejected: return Icons.cancel_rounded;
      case PaymentTransactionStatus.refunded: return Icons.undo_rounded;
      default: return Icons.sync_rounded;
    }
  }

  // ── Tab 3: Teacher Payouts ──
  Widget _buildTeacherPayoutsTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton.icon(
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => const RecordTeacherPaymentModal(),
                );
              },
              icon: const Icon(Icons.payments_rounded, color: Colors.white),
              label: const Text('Record New Teacher Payout', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo.shade900, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            ),
          ),
        ),
        Expanded(
          child: StreamBuilder<List<TeacherPayoutModel>>(
            stream: TeacherPayoutService.getAllPayoutsStream(),
            builder: (context, snapshot) {
              final payouts = snapshot.data ?? [];
              if (payouts.isEmpty) {
                return const Center(child: Text('No teacher payouts logged yet.'));
              }
              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: payouts.length,
                itemBuilder: (context, i) {
                  final p = payouts[i];
                  final dateStr = DateFormat('dd MMM yyyy, hh:mm a').format(p.paymentDate);

                  return CustomCard(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      leading: const CircleAvatar(backgroundColor: Colors.indigo, child: Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 20)),
                      title: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              p.teacherName, 
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text('Rs ${NumberFormat('#,##0').format(p.amount)}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.secondaryGreen)),
                        ],
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${p.teacherSubject} (${p.teacherSection}) • Note: ${p.reason}', style: const TextStyle(fontSize: 11)),
                          Text('Ref: ${p.txnRef} • Date: $dateStr', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // ── Tab 4: Payment Config ──
  Widget _buildPaymentConfigTab() {
    return StreamBuilder<PaymentConfigModel>(
      stream: PaymentService.getPaymentConfigStream(),
      builder: (context, snapshot) {
        final config = snapshot.data ?? PaymentConfigModel.defaultConfig();
        return _PaymentConfigEditor(config: config);
      },
    );
  }

  // ── Tab 5: Audit Log ──
  Widget _buildAuditLogTab() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: AuditLogService.getAuditLogsStream(),
      builder: (context, snapshot) {
        final logs = snapshot.data ?? [];
        if (logs.isEmpty) {
          return const Center(child: Text('No audit logs recorded.'));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: logs.length,
          itemBuilder: (context, i) {
            final log = logs[i];
            final action = log['action']?.toString() ?? 'ACTION';
            final actorName = log['actorName']?.toString() ?? 'User';
            final details = log['details']?.toString() ?? '';
            final ts = log['timestamp'];
            DateTime? date;
            if (ts != null) {
              try {
                date = (ts as dynamic).toDate();
              } catch (_) {}
            }

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: const Icon(Icons.security_rounded, color: Colors.indigo),
                title: Text('$action by $actorName', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                subtitle: Text(details, style: const TextStyle(fontSize: 11)),
                trailing: date != null ? Text(DateFormat('dd/MM hh:mm a').format(date), style: const TextStyle(fontSize: 10, color: Colors.grey)) : null,
              ),
            );
          },
        );
      },
    );
  }
}

class _PaymentConfigEditor extends StatefulWidget {
  final PaymentConfigModel config;
  const _PaymentConfigEditor({required this.config});

  @override
  State<_PaymentConfigEditor> createState() => _PaymentConfigEditorState();
}

class _PaymentConfigEditorState extends State<_PaymentConfigEditor> {
  late TextEditingController _bankName;
  late TextEditingController _title;
  late TextEditingController _accountNo;
  late TextEditingController _iban;
  late TextEditingController _easypaisaTitle;
  late TextEditingController _easypaisaNo;
  late TextEditingController _jazzcashTitle;
  late TextEditingController _jazzcashNo;
  late bool _bankEnabled;
  late bool _easypaisaEnabled;
  late bool _jazzcashEnabled;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _bankName = TextEditingController(text: widget.config.bankName);
    _title = TextEditingController(text: widget.config.accountTitle);
    _accountNo = TextEditingController(text: widget.config.accountNumber);
    _iban = TextEditingController(text: widget.config.iban);
    _easypaisaTitle = TextEditingController(text: widget.config.easypaisaTitle);
    _easypaisaNo = TextEditingController(text: widget.config.easypaisaNumber);
    _jazzcashTitle = TextEditingController(text: widget.config.jazzcashTitle);
    _jazzcashNo = TextEditingController(text: widget.config.jazzcashNumber);
    _bankEnabled = widget.config.isBankTransferEnabled;
    _easypaisaEnabled = widget.config.isEasypaisaEnabled;
    _jazzcashEnabled = widget.config.isJazzcashEnabled;
  }

  @override
  void dispose() {
    _bankName.dispose();
    _title.dispose();
    _accountNo.dispose();
    _iban.dispose();
    _easypaisaTitle.dispose();
    _easypaisaNo.dispose();
    _jazzcashTitle.dispose();
    _jazzcashNo.dispose();
    super.dispose();
  }

  void _saveConfig() async {
    setState(() => _isSaving = true);
    final newConfig = PaymentConfigModel(
      bankName: _bankName.text.trim(),
      accountTitle: _title.text.trim(),
      accountNumber: _accountNo.text.trim(),
      iban: _iban.text.trim(),
      easypaisaTitle: _easypaisaTitle.text.trim(),
      easypaisaNumber: _easypaisaNo.text.trim(),
      jazzcashTitle: _jazzcashTitle.text.trim(),
      jazzcashNumber: _jazzcashNo.text.trim(),
      paymentInstructions: widget.config.paymentInstructions,
      isBankTransferEnabled: _bankEnabled,
      isEasypaisaEnabled: _easypaisaEnabled,
      isJazzcashEnabled: _jazzcashEnabled,
      isGatewayEnabled: widget.config.isGatewayEnabled,
    );

    try {
      await PaymentService.updatePaymentConfig(newConfig, adminName: 'Academy Admin');
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(backgroundColor: AppTheme.secondaryGreen, content: Text('Payment Configuration Saved!')));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving config: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Academy Payment Accounts Configuration', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 6),
          const Text('Manage default bank and mobile wallet details displayed to students for fee payments.', style: TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 16),

          // Bank Transfer Settings
          SwitchListTile(
            title: const Text('Enable Bank Transfer', style: TextStyle(fontWeight: FontWeight.bold)),
            value: _bankEnabled,
            onChanged: (v) => setState(() => _bankEnabled = v),
          ),
          TextField(controller: _bankName, decoration: const InputDecoration(labelText: 'Bank Name', border: OutlineInputBorder())),
          const SizedBox(height: 10),
          TextField(controller: _title, decoration: const InputDecoration(labelText: 'Account Title', border: OutlineInputBorder())),
          const SizedBox(height: 10),
          TextField(controller: _accountNo, decoration: const InputDecoration(labelText: 'Account Number', border: OutlineInputBorder())),
          const SizedBox(height: 10),
          TextField(controller: _iban, decoration: const InputDecoration(labelText: 'IBAN', border: OutlineInputBorder())),

          const Divider(height: 30),

          // Easypaisa Settings
          SwitchListTile(
            title: const Text('Enable Easypaisa Wallet', style: TextStyle(fontWeight: FontWeight.bold)),
            value: _easypaisaEnabled,
            onChanged: (v) => setState(() => _easypaisaEnabled = v),
          ),
          TextField(controller: _easypaisaTitle, decoration: const InputDecoration(labelText: 'Easypaisa Title', border: OutlineInputBorder())),
          const SizedBox(height: 10),
          TextField(controller: _easypaisaNo, decoration: const InputDecoration(labelText: 'Easypaisa Mobile #', border: OutlineInputBorder())),

          const Divider(height: 30),

          // JazzCash Settings
          SwitchListTile(
            title: const Text('Enable JazzCash Wallet', style: TextStyle(fontWeight: FontWeight.bold)),
            value: _jazzcashEnabled,
            onChanged: (v) => setState(() => _jazzcashEnabled = v),
          ),
          TextField(controller: _jazzcashTitle, decoration: const InputDecoration(labelText: 'JazzCash Title', border: OutlineInputBorder())),
          const SizedBox(height: 10),
          TextField(controller: _jazzcashNo, decoration: const InputDecoration(labelText: 'JazzCash Mobile #', border: OutlineInputBorder())),

          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _isSaving ? null : _saveConfig,
              icon: _isSaving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.save_rounded, color: Colors.white),
              label: Text(_isSaving ? 'Saving...' : 'Save Configuration Changes', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryBlue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}
