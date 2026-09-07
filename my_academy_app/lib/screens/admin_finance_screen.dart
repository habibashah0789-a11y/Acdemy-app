import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/teacher_payout_model.dart';
import '../services/audit_log_service.dart';
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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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
          'Teacher Payouts & Finance',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.indigo.shade900,
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.secondaryGreen,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: const [
            Tab(icon: Icon(Icons.people_alt_rounded), text: 'Teacher Payouts'),
            Tab(icon: Icon(Icons.security_rounded), text: 'Audit Log'),
          ],
        ),
      ),
      body: StreamBuilder<List<TeacherPayoutModel>>(
        stream: TeacherPayoutService.getAllPayoutsStream(),
        builder: (context, snapshot) {
          final payouts = snapshot.data ?? [];

          return Column(
            children: [
              // Dashboard Metrics Summary Header
              _buildMetricsHeader(payouts),

              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // Tab 1: Teacher Payouts
                    _buildTeacherPayoutsTab(payouts),

                    // Tab 2: Audit Log
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

  Widget _buildMetricsHeader(List<TeacherPayoutModel> payouts) {
    final double totalPayouts = payouts.fold(0.0, (sum, p) => sum + p.amount);

    final now = DateTime.now();
    final double thisMonthPayouts = payouts
        .where((p) => p.paymentDate.year == now.year && p.paymentDate.month == now.month)
        .fold(0.0, (sum, p) => sum + p.amount);

    final int totalRecords = payouts.length;

    return Container(
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

  // ── Tab 1: Teacher Payouts ──
  Widget _buildTeacherPayoutsTab(List<TeacherPayoutModel> payouts) {
    final filtered = payouts.where((p) {
      if (_searchQuery.isEmpty) return true;
      final query = _searchQuery.toLowerCase();
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
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search payouts by teacher, subject, ref...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onChanged: (v) => setState(() => _searchQuery = v.trim()),
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
                            Text('Ref: ${p.txnRef} • Date: $dateStr', style: const TextStyle(fontSize: 10, color: Colors.grey)),
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

  // ── Tab 2: Audit Log ──
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
            final timestamp = log['timestamp'];
            DateTime dt = DateTime.now();
            if (timestamp != null) {
              try {
                dt = timestamp.toDate();
              } catch (_) {}
            }

            return CustomCard(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.indigo.shade50, borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.history_toggle_off_rounded, color: Colors.indigo, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(action, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.indigo)),
                            Text(DateFormat('dd MMM, hh:mm a').format(dt), style: const TextStyle(fontSize: 10, color: Colors.grey)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(details, style: const TextStyle(fontSize: 12)),
                        const SizedBox(height: 2),
                        Text('By: $actorName', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
