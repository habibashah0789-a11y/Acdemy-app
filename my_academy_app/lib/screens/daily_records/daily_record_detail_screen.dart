import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'daily_records_screen.dart';
import '../../theme/app_theme.dart';
import '../../students/student_detail_screen.dart';
import '../../models/student_model.dart';
import '../../widgets/shimmer_loading_widget.dart';

class DailyRecordDetailScreen extends StatefulWidget {
  final DailyRecordData record;

  const DailyRecordDetailScreen({super.key, required this.record});

  @override
  State<DailyRecordDetailScreen> createState() =>
      _DailyRecordDetailScreenState();
}

class _DailyRecordDetailScreenState extends State<DailyRecordDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _fmt = NumberFormat.currency(symbol: 'Rs ', decimalDigits: 0);

  // ── derived lists ──────────────────────────────────────────────────────────

  List<StudentModel> get _registrations => widget.record.newRegistrations;
  List<StudentModel> get _defaulters => widget.record.defaulters;
  List<AdminStudentPaymentEvent> get _installments => widget.record.installmentPayments;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ── build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? AppTheme.darkBackground : const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text(
          DateFormat('MMM dd, yyyy').format(widget.record.date),
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelStyle:
              GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13),
          unselectedLabelStyle:
              GoogleFonts.poppins(fontWeight: FontWeight.w500, fontSize: 13),
          indicatorColor: AppTheme.primaryBlue,
          indicatorWeight: 3,
          labelColor: AppTheme.primaryBlue,
          unselectedLabelColor: isDark ? Colors.grey[400] : Colors.grey[600],
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.person_add_alt_1_rounded, size: 16),
                  const SizedBox(width: 6),
                  Text('Regs (${_registrations.length})'),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.receipt_long_rounded, size: 16),
                  const SizedBox(width: 6),
                  Text('Installs (${_installments.length})'),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.warning_amber_rounded,
                      size: 16, color: _defaulters.isNotEmpty ? Colors.orange : null),
                  const SizedBox(width: 6),
                  Text('Defaulters (${_defaulters.length})'),
                ],
              ),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildRegistrationsTab(isDark),
          _buildInstallmentsTab(isDark),
          _buildDefaultersTab(isDark),
        ],
      ),
    );
  }

  // ── Tab 1 — Registrations ──────────────────────────────────────────────────

  Widget _buildRegistrationsTab(bool isDark) {
    final totalRegistered = widget.record.totalRegistrationAmount;
    final totalCollected = _registrations.fold<double>(0.0, (total, s) => total + s.feeSubmitted);

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _summaryCard(
                        label: 'Total Fee Due',
                        amount: totalRegistered,
                        icon: Icons.receipt_long_rounded,
                        color: AppTheme.primaryBlue,
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _summaryCard(
                        label: 'Reg. Fee Collected',
                        amount: totalCollected,
                        icon: Icons.account_balance_wallet_rounded,
                        color: Colors.green,
                        isDark: isDark,
                      ),
                    ),
                  ],
                ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.05),
                const SizedBox(height: 8),
                _summaryCard(
                  label: 'Students Registered on this Day',
                  amount: null,
                  icon: Icons.person_add_alt_1_rounded,
                  color: Colors.purple,
                  isDark: isDark,
                  valueText: '${_registrations.length} students',
                ).animate().fadeIn(duration: 400.ms),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
        if (_registrations.isEmpty)
          const SliverFillRemaining(
            child: Center(
              child: Text('No new registrations on this date.'),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final student = _registrations[index];
                  return _registrationCard(student, isDark, index);
                },
                childCount: _registrations.length,
              ),
            ),
          ),
      ],
    );
  }

  Widget _registrationCard(StudentModel student, bool isDark, int index) {
    double firstInstallment = 0;
    if (student.paymentHistoryJson != null && student.paymentHistoryJson!.isNotEmpty) {
      try {
        final List<dynamic> history = jsonDecode(student.paymentHistoryJson!);
        if (history.isNotEmpty) {
          firstInstallment = (history[0]['amount'] as num?)?.toDouble() ?? 0;
        }
      } catch (_) {}
    } else {
      firstInstallment = student.feeSubmitted;
    }

    return _studentCard(
      context: context,
      student: student,
      isDark: isDark,
      index: index,
      subtitle: Row(
        children: [
          _miniChip(
            label: 'Initial Paid: ${_fmt.format(firstInstallment)}',
            color: Colors.green,
          ),
          const SizedBox(width: 6),
          _miniChip(
            label: 'Total Fee: ${_fmt.format(student.totalFee)}',
            color: AppTheme.primaryBlue,
          ),
        ],
      ),
      trailing: _feeBadge(student),
    );
  }

  // ── Tab 2 — Defaulters ─────────────────────────────────────────────────────

  Widget _buildDefaultersTab(bool isDark) {
    final totalPending =
        _defaulters.fold<double>(0, (s, st) => s + st.feeRemaining);

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _summaryCard(
                        label: 'Total Pending',
                        amount: totalPending,
                        icon: Icons.warning_amber_rounded,
                        color: Colors.orange,
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _summaryCard(
                        label: 'Defaulters',
                        amount: null,
                        icon: Icons.person_off_rounded,
                        color: Colors.red,
                        isDark: isDark,
                        valueText: '${_defaulters.length} students',
                      ),
                    ),
                  ],
                ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.05),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
        if (_defaulters.isEmpty)
          SliverFillRemaining(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle_rounded,
                      size: 72, color: Colors.green),
                  const SizedBox(height: 16),
                  Text(
                    'No Defaulters! 🎉',
                    style: GoogleFonts.poppins(
                        fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'All students on this date have\npaid their fees in full.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                        fontSize: 13, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final student = _defaulters[index];
                  return _defaulterCard(student, isDark, index);
                },
                childCount: _defaulters.length,
              ),
            ),
          ),
      ],
    );
  }

  Widget _defaulterCard(StudentModel student, bool isDark, int index) {
    // Next installment: treat feeRemaining as the amount due next
    final nextInstallment = student.feeRemaining;

    return _studentCard(
      context: context,
      student: student,
      isDark: isDark,
      index: index,
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          Row(
            children: [
              _miniChip(
                label: 'Paid: ${_fmt.format(student.feeSubmitted)}',
                color: Colors.green,
              ),
              const SizedBox(width: 6),
              _miniChip(
                label: 'Due: ${_fmt.format(student.feeRemaining)}',
                color: Colors.red,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: Colors.orange.withValues(alpha: 0.4), width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.schedule_rounded,
                    size: 13, color: Colors.orange),
                const SizedBox(width: 5),
                Text(
                  'Next Installment Due: ${_fmt.format(nextInstallment)}',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.orange[800],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          'PENDING',
          style: GoogleFonts.poppins(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Colors.red,
          ),
        ),
      ),
    );
  }

  // ── Tab 3 — Installments ───────────────────────────────────────────────────

  Widget _buildInstallmentsTab(bool isDark) {
    final paidList = _installments;
    final totalCollectedOnDate = paidList.fold<double>(0, (s, st) => s + st.amount);

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _summaryCard(
                        label: 'Amount Received',
                        amount: totalCollectedOnDate,
                        icon: Icons.payments_rounded,
                        color: Colors.green,
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _summaryCard(
                        label: 'Installments Paid',
                        amount: null,
                        icon: Icons.receipt_rounded,
                        color: Colors.teal,
                        isDark: isDark,
                        valueText: '${paidList.length} txns',
                      ),
                    ),
                  ],
                ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.05),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
        if (paidList.isEmpty)
          SliverFillRemaining(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.money_off_rounded,
                      size: 72, color: Colors.grey.withValues(alpha: 0.5)),
                  const SizedBox(height: 16),
                  Text(
                    'No Installments on this Date',
                    style: GoogleFonts.poppins(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'No additional installments\nwere paid on this day.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                        fontSize: 13, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final event = paidList[index];
                  return _installmentCard(event, isDark, index);
                },
                childCount: paidList.length,
              ),
            ),
          ),
      ],
    );
  }

  Widget _installmentCard(AdminStudentPaymentEvent event, bool isDark, int index) {
    return _studentCard(
      context: context,
      student: event.student,
      isDark: isDark,
      index: index,
      subtitle: Row(
        children: [
          _miniChip(
            label: 'Installment #${event.installmentNumber}',
            color: Colors.teal,
          ),
          const SizedBox(width: 6),
          _miniChip(
            label: 'Balance: ${_fmt.format(event.student.feeRemaining)}',
            color: event.student.feeRemaining > 0 ? Colors.red : Colors.green,
          ),
        ],
      ),
      trailing: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            _fmt.format(event.amount),
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.green[700],
            ),
          ),
          Text(
            'collected',
            style: GoogleFonts.poppins(
                fontSize: 10, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  // ── Shared widgets ─────────────────────────────────────────────────────────

  Widget _summaryCard({
    required String label,
    required double? amount,
    required IconData icon,
    required Color color,
    required bool isDark,
    String? valueText,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: color.withValues(alpha: 0.18),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 2,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  valueText ??
                      (amount != null ? _fmt.format(amount) : '—'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _studentCard({
    required BuildContext context,
    required StudentModel student,
    required bool isDark,
    required int index,
    required Widget subtitle,
    required Widget trailing,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.06),
          width: 1,
        ),
      ),
      color: isDark ? AppTheme.darkCard : Colors.white,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => StudentDetailScreen(student: student),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar
              Hero(
                tag: 'daily_detail_${student.id}_$index',
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: student.profilePicUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: student.profilePicUrl,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => const ShimmerLoadingWidget(
                              width: 48,
                              height: 48,
                              borderRadius: 14,
                            ),
                            errorWidget: (_, __, ___) => const Icon(
                                Icons.person_rounded,
                                color: AppTheme.primaryBlue),
                          )
                        : Center(
                            child: Text(
                              student.initials.isNotEmpty
                                  ? student.initials
                                  : 'S',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: AppTheme.primaryBlue,
                              ),
                            ),
                          ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Name + subtitle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      student.name,
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: isDark ? Colors.white : const Color(0xFF1D1D1F),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${student.classType} — ${student.grade}',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: isDark
                            ? Colors.grey[400]
                            : const Color(0xFF64748B),
                      ),
                    ),
                    subtitle,
                  ],
                ),
              ),
              const SizedBox(width: 8),
              trailing,
            ],
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 350.ms)
        .slideX(begin: 0.04);
  }

  Widget _miniChip({required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _feeBadge(StudentModel student) {
    final isClear = student.feeRemaining <= 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isClear
            ? Colors.green.withValues(alpha: 0.1)
            : Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        isClear ? 'PAID' : 'PENDING',
        style: GoogleFonts.poppins(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: isClear ? Colors.green : Colors.red,
        ),
      ),
    );
  }
}
