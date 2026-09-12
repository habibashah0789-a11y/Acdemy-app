import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/payment_config_model.dart';
import '../models/payment_transaction_model.dart';
import '../models/teacher_payout_model.dart';
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
  final TextEditingController _payoutSearchController = TextEditingController();
  final TextEditingController _feeSearchController = TextEditingController();

  String _payoutSearchQuery = '';
  String _feeSearchQuery = '';
  String _feeFilter = 'ALL'; // ALL, PENDING, VERIFIED, REJECTED

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _payoutSearchController.dispose();
    _feeSearchController.dispose();
    super.dispose();
  }

  void _openPaymentConfigDialog() async {
    final cfg = await PaymentService.getPaymentConfigOnce();
    if (!mounted) return;

    final bankNameCtrl = TextEditingController(text: cfg.bankName);
    final accountTitleCtrl = TextEditingController(text: cfg.accountTitle);
    final accountNumCtrl = TextEditingController(text: cfg.accountNumber);
    final ibanCtrl = TextEditingController(text: cfg.iban);
    final epTitleCtrl = TextEditingController(text: cfg.easypaisaTitle);
    final epNumCtrl = TextEditingController(text: cfg.easypaisaNumber);
    final jcTitleCtrl = TextEditingController(text: cfg.jazzcashTitle);
    final jcNumCtrl = TextEditingController(text: cfg.jazzcashNumber);
    final instructionsCtrl = TextEditingController(text: cfg.paymentInstructions);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.settings_suggest_rounded, color: AppTheme.primaryBlue),
            const SizedBox(width: 10),
            const Text('Academy Payment Accounts', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Bank Account Settings', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 8),
                TextField(controller: bankNameCtrl, decoration: const InputDecoration(labelText: 'Bank Name', isDense: true)),
                const SizedBox(height: 8),
                TextField(controller: accountTitleCtrl, decoration: const InputDecoration(labelText: 'Account Title', isDense: true)),
                const SizedBox(height: 8),
                TextField(controller: accountNumCtrl, decoration: const InputDecoration(labelText: 'Account Number', isDense: true)),
                const SizedBox(height: 8),
                TextField(controller: ibanCtrl, decoration: const InputDecoration(labelText: 'IBAN', isDense: true)),
                const Divider(height: 24),
                const Text('Mobile Wallets Settings', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 8),
                TextField(controller: epTitleCtrl, decoration: const InputDecoration(labelText: 'EasyPaisa Title', isDense: true)),
                const SizedBox(height: 8),
                TextField(controller: epNumCtrl, decoration: const InputDecoration(labelText: 'EasyPaisa Number', isDense: true)),
                const SizedBox(height: 8),
                TextField(controller: jcTitleCtrl, decoration: const InputDecoration(labelText: 'JazzCash Title', isDense: true)),
                const SizedBox(height: 8),
                TextField(controller: jcNumCtrl, decoration: const InputDecoration(labelText: 'JazzCash Number', isDense: true)),
                const Divider(height: 24),
                TextField(controller: instructionsCtrl, maxLines: 2, decoration: const InputDecoration(labelText: 'Payment Instructions', isDense: true)),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryBlue),
            onPressed: () async {
              final updated = PaymentConfigModel(
                id: cfg.id,
                bankName: bankNameCtrl.text.trim(),
                accountTitle: accountTitleCtrl.text.trim(),
                accountNumber: accountNumCtrl.text.trim(),
                iban: ibanCtrl.text.trim(),
                easypaisaTitle: epTitleCtrl.text.trim(),
                easypaisaNumber: epNumCtrl.text.trim(),
                jazzcashTitle: jcTitleCtrl.text.trim(),
                jazzcashNumber: jcNumCtrl.text.trim(),
                paymentInstructions: instructionsCtrl.text.trim(),
                isBankTransferEnabled: cfg.isBankTransferEnabled,
                isEasypaisaEnabled: cfg.isEasypaisaEnabled,
                isJazzcashEnabled: cfg.isJazzcashEnabled,
                isGatewayEnabled: cfg.isGatewayEnabled,
              );
              await PaymentService.updatePaymentConfig(updated, adminName: 'Admin');
              if (ctx.mounted) {
                Navigator.pop(ctx);
              }
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Academy payment account settings updated.')),
                );
              }
            },
            child: const Text('Save Details', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _verifyPayment(PaymentTransactionModel txn) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Approve Fee Payment'),
        content: Text(
          'Are you sure you want to approve Rs ${txn.amount.toStringAsFixed(0)} for ${txn.studentName}?\n\n'
          'This will automatically credit the student fee balance, record the ledger entry, and notify the student.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.secondaryGreen),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await PaymentService.verifyPaymentByAdmin(
                  transactionId: txn.transactionId,
                  adminName: 'Admin',
                );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: AppTheme.secondaryGreen,
                      content: Text('Payment approved for ${txn.studentName}! Fee credited.'),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: Colors.red.shade700,
                      content: Text(e.toString().replaceFirst('Exception: ', '')),
                    ),
                  );
                }
              }
            },
            child: const Text('Approve & Credit', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _rejectPayment(PaymentTransactionModel txn) {
    final reasonCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Reject Fee Payment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Reject transaction "${txn.providerTransactionId}" of Rs ${txn.amount.toStringAsFixed(0)} for ${txn.studentName}.'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              decoration: const InputDecoration(
                labelText: 'Reason for Rejection',
                hintText: 'e.g. Deposit slip unverified / wrong amount',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.warningRed),
            onPressed: () async {
              final reason = reasonCtrl.text.trim();
              if (reason.isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Please specify a rejection reason.')),
                );
                return;
              }
              Navigator.pop(ctx);
              try {
                await PaymentService.rejectPaymentByAdmin(
                  transactionId: txn.transactionId,
                  adminName: 'Admin',
                  failureReason: reason,
                );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Payment rejected and student notified.')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(backgroundColor: Colors.red.shade700, content: Text('$e')),
                  );
                }
              }
            },
            child: const Text('Confirm Reject', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackground : AppTheme.lightBackground,
      appBar: AppBar(
        title: Text(
          'Academy Finance & Payments',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.indigo.shade900,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_suggest_rounded),
            tooltip: 'Payment Accounts Settings',
            onPressed: _openPaymentConfigDialog,
          ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.amberAccent,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(icon: Icon(Icons.verified_user_rounded, size: 20), text: 'Student Fee Verifications'),
            Tab(icon: Icon(Icons.payments_rounded, size: 20), text: 'Teacher Payouts'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildFeeVerificationsTab(),
          _buildTeacherPayoutsSection(),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // TAB 1: Student Fee Verifications
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildFeeVerificationsTab() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return StreamBuilder<List<PaymentTransactionModel>>(
      stream: PaymentService.getAllTransactionsStream(),
      builder: (context, snapshot) {
        final allTxns = snapshot.data ?? [];
        final pendingTxns = allTxns
            .where((t) =>
                t.status == PaymentTransactionStatus.verificationRequired ||
                t.status == PaymentTransactionStatus.pending)
            .toList();

        final filtered = allTxns.where((t) {
          if (_feeFilter == 'PENDING' &&
              t.status != PaymentTransactionStatus.verificationRequired &&
              t.status != PaymentTransactionStatus.pending) {
            return false;
          }
          if (_feeFilter == 'VERIFIED' && t.status != PaymentTransactionStatus.successful) {
            return false;
          }
          if (_feeFilter == 'REJECTED' && t.status != PaymentTransactionStatus.rejected) {
            return false;
          }
          if (_feeSearchQuery.isEmpty) return true;
          final q = _feeSearchQuery.toLowerCase();
          final sName = (t.studentName ?? t.payerName).toLowerCase();
          final sCode = (t.studentCode ?? '').toLowerCase();
          final pTxn = t.providerTransactionId.toLowerCase();
          final prov = t.provider.toLowerCase();
          return sName.contains(q) || sCode.contains(q) || pTxn.contains(q) || prov.contains(q);
        }).toList();

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 960),
            child: Column(
              children: [
                // Top Metrics Bar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.indigo.shade900,
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _metricCard(
                          'Pending Verification',
                          '${pendingTxns.length} Submissions',
                          pendingTxns.isNotEmpty ? Colors.amberAccent : Colors.white70,
                        ),
                      ),
                      Container(width: 1, height: 36, color: Colors.white24),
                      Expanded(
                        child: _metricCard(
                          'Pending Total',
                          'Rs ${NumberFormat('#,##0').format(pendingTxns.fold<double>(0.0, (sum, t) => sum + t.amount))}',
                          Colors.amberAccent,
                        ),
                      ),
                      Container(width: 1, height: 36, color: Colors.white24),
                      Expanded(
                        child: _metricCard(
                          'Total Online Submissions',
                          '${allTxns.length}',
                          AppTheme.secondaryGreen,
                        ),
                      ),
                    ],
                  ),
                ),

                // Filters & Search
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Column(
                    children: [
                      TextField(
                        controller: _feeSearchController,
                        decoration: InputDecoration(
                          hintText: 'Search by student name, ID, or Transaction Ref...',
                          prefixIcon: const Icon(Icons.search_rounded),
                          suffixIcon: _feeSearchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear_rounded),
                                  onPressed: () {
                                    _feeSearchController.clear();
                                    setState(() => _feeSearchQuery = '');
                                  },
                                )
                              : null,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onChanged: (v) => setState(() => _feeSearchQuery = v.trim()),
                      ),
                      const SizedBox(height: 10),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _filterChip('ALL', 'All Submissions (${allTxns.length})'),
                            const SizedBox(width: 8),
                            _filterChip('PENDING', 'Pending (${pendingTxns.length})', isHighlight: pendingTxns.isNotEmpty),
                            const SizedBox(width: 8),
                            _filterChip(
                              'VERIFIED',
                              'Verified (${allTxns.where((t) => t.status == PaymentTransactionStatus.successful).length})',
                            ),
                            const SizedBox(width: 8),
                            _filterChip(
                              'REJECTED',
                              'Rejected (${allTxns.where((t) => t.status == PaymentTransactionStatus.rejected).length})',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Transaction Cards List
                Expanded(
                  child: filtered.isEmpty
                      ? const Center(
                          child: Text('No student fee submissions match your filter.'),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: filtered.length,
                          itemBuilder: (context, i) {
                            final txn = filtered[i];
                            final isPending = txn.status == PaymentTransactionStatus.verificationRequired ||
                                txn.status == PaymentTransactionStatus.pending;
                            final dateStr = DateFormat('dd MMM yyyy, hh:mm a').format(txn.createdAt);

                            Color statusColor = Colors.orange;
                            String statusLabel = 'Verification Required';
                            if (txn.status == PaymentTransactionStatus.successful) {
                              statusColor = AppTheme.secondaryGreen;
                              statusLabel = 'Approved & Credited';
                            } else if (txn.status == PaymentTransactionStatus.rejected) {
                              statusColor = AppTheme.warningRed;
                              statusLabel = 'Rejected';
                            }

                            return CustomCard(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              txn.studentName ?? txn.payerName,
                                              style: GoogleFonts.poppins(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15,
                                              ),
                                            ),
                                            Text(
                                              'ID: ${txn.studentCode ?? "N/A"} • Method: ${txn.provider}',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            'Rs ${NumberFormat('#,##0').format(txn.amount)}',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                              color: AppTheme.secondaryGreen,
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: statusColor.withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              statusLabel,
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: statusColor,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: isDark ? Colors.white10 : Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.receipt_long_rounded, size: 16, color: AppTheme.primaryBlue),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'Ref ID: ${txn.providerTransactionId}',
                                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                                          ),
                                        ),
                                        Text(
                                          dateStr,
                                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (txn.description.isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      'Note: ${txn.description}',
                                      style: TextStyle(fontSize: 12, color: isDark ? Colors.grey.shade300 : Colors.grey.shade700),
                                    ),
                                  ],
                                  if (txn.status == PaymentTransactionStatus.rejected && txn.failureReason != null) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      'Rejection Reason: ${txn.failureReason}',
                                      style: const TextStyle(fontSize: 11, color: AppTheme.warningRed, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                  if (isPending) ...[
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: OutlinedButton.icon(
                                            onPressed: () => _rejectPayment(txn),
                                            icon: const Icon(Icons.close_rounded, color: AppTheme.warningRed, size: 16),
                                            label: const Text('Reject', style: TextStyle(color: AppTheme.warningRed, fontSize: 12)),
                                            style: OutlinedButton.styleFrom(
                                              side: const BorderSide(color: AppTheme.warningRed),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          flex: 2,
                                          child: ElevatedButton.icon(
                                            onPressed: () => _verifyPayment(txn),
                                            icon: const Icon(Icons.check_rounded, color: Colors.white, size: 16),
                                            label: const Text('Approve & Credit', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: AppTheme.secondaryGreen,
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _filterChip(String id, String label, {bool isHighlight = false}) {
    final isSelected = _feeFilter == id;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => setState(() => _feeFilter = id),
      selectedColor: isHighlight ? Colors.amber.shade700 : AppTheme.primaryBlue,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : null,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 12,
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // TAB 2: Teacher Payouts
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildTeacherPayoutsSection() {
    return StreamBuilder<List<TeacherPayoutModel>>(
      stream: TeacherPayoutService.getAllPayoutsStream(),
      builder: (context, snapshot) {
        final payouts = snapshot.data ?? [];
        final double totalPayouts = payouts.fold(0.0, (sum, p) => sum + p.amount);

        final now = DateTime.now();
        final double thisMonthPayouts = payouts
            .where((p) => p.paymentDate.year == now.year && p.paymentDate.month == now.month)
            .fold(0.0, (sum, p) => sum + p.amount);

        final int totalRecords = payouts.length;

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 960),
            child: Column(
              children: [
                // Metrics Bar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.indigo.shade900,
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
                  ),
                  child: Row(
                    children: [
                      Expanded(child: _metricCard('Total Paid Out', 'Rs ${NumberFormat('#,##0').format(totalPayouts)}', AppTheme.secondaryGreen)),
                      Container(width: 1, height: 36, color: Colors.white24),
                      Expanded(child: _metricCard('This Month', 'Rs ${NumberFormat('#,##0').format(thisMonthPayouts)}', Colors.lightBlueAccent)),
                      Container(width: 1, height: 36, color: Colors.white24),
                      Expanded(child: _metricCard('Total Records', '$totalRecords Payouts', Colors.amberAccent)),
                    ],
                  ),
                ),
                Expanded(child: _buildTeacherPayoutsTab(payouts)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _metricCard(String label, String value, Color valueColor) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: valueColor), overflow: TextOverflow.ellipsis),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.white70), overflow: TextOverflow.ellipsis),
      ],
    );
  }

  Widget _buildTeacherPayoutsTab(List<TeacherPayoutModel> payouts) {
    final filtered = payouts.where((p) {
      if (_payoutSearchQuery.isEmpty) return true;
      final query = _payoutSearchQuery.toLowerCase();
      return p.teacherName.toLowerCase().contains(query) ||
          p.teacherSubject.toLowerCase().contains(query) ||
          p.txnRef.toLowerCase().contains(query) ||
          p.reason.toLowerCase().contains(query);
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            children: [
              SizedBox(
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
              const SizedBox(height: 12),
              TextField(
                controller: _payoutSearchController,
                decoration: InputDecoration(
                  hintText: 'Search payouts by teacher, subject, reason...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _payoutSearchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded),
                          onPressed: () {
                            _payoutSearchController.clear();
                            setState(() => _payoutSearchQuery = '');
                          },
                        )
                      : null,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onChanged: (v) => setState(() => _payoutSearchQuery = v.trim()),
              ),
            ],
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? const Center(child: Text('No teacher payouts found.'))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filtered.length,
                  itemBuilder: (context, i) {
                    final p = filtered[i];
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
                            Text('Date: $dateStr', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                          ],
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.secondaryGreen.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_circle_rounded, color: AppTheme.secondaryGreen, size: 14),
                              SizedBox(width: 4),
                              Text(
                                'PAID',
                                style: TextStyle(
                                  color: AppTheme.secondaryGreen,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
