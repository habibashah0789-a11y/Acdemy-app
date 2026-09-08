import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/teacher_payout_model.dart';
import '../services/teacher_payout_service.dart';
import '../teachers/record_teacher_payment_modal.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_card.dart';

class AdminFinanceScreen extends StatefulWidget {
  const AdminFinanceScreen({super.key});

  @override
  State<AdminFinanceScreen> createState() => _AdminFinanceScreenState();
}

class _AdminFinanceScreenState extends State<AdminFinanceScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
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
                child: _buildTeacherPayoutsTab(payouts),
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

  // ── Teacher Payouts List ──
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
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                          tooltip: 'Delete Payout Record',
                          onPressed: () => _confirmDeletePayout(context, p),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Future<void> _confirmDeletePayout(BuildContext context, TeacherPayoutModel payout) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Payout Record?'),
        content: Text(
          'Are you sure you want to permanently delete this payout of Rs ${NumberFormat('#,##0').format(payout.amount)} for ${payout.teacherName}?\n\n'
          'Ref: ${payout.txnRef}\n'
          'This will remove the transaction record and its notice.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(ctx).pop(true),
            icon: const Icon(Icons.delete_forever_rounded, color: Colors.white, size: 16),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            label: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await TeacherPayoutService.deletePayout(payout.id);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Payout record ${payout.txnRef} deleted successfully.'),
              backgroundColor: Colors.red.shade700,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete payout: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}
