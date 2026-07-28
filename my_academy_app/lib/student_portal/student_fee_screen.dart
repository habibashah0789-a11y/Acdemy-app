import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/student_model.dart';
import '../theme/app_theme.dart';
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

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
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
      final doc = await FirebaseFirestore.instance
          .collection('students')
          .doc(session['studentId'] as String)
          .get()
          .timeout(const Duration(seconds: 10));
      if (doc.exists) {
        setState(() => _student = StudentModel.fromFirestore(doc));
      }
    } catch (e) {
      setState(() => _errorMessage = 'Failed to load fee data.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text('My Fees', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _loadData),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
                    const SizedBox(height: 12),
                    Text(_errorMessage!),
                    const SizedBox(height: 12),
                    ElevatedButton(onPressed: _loadData, child: const Text('Retry')),
                  ],
                ))
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: _buildContent(),
                ),
    );
  }

  Widget _buildContent() {
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
      padding: const EdgeInsets.all(16),
      children: [
        // Overall summary card
        Card(
          elevation: 3,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Overall Fee Summary',
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _statChip('Total', student.totalFee, AppTheme.primaryBlue),
                    _statChip('Paid', student.feeSubmitted, Colors.green),
                    _statChip('Due', student.feeRemaining,
                        student.feeRemaining > 0 ? Colors.red : Colors.green),
                  ],
                ),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: feePercent,
                    minHeight: 12,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation(
                      feePercent >= 1.0 ? Colors.green : AppTheme.primaryBlue,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  student.feeRemaining <= 0
                      ? '✓ All fees paid'
                      : '${(feePercent * 100).toStringAsFixed(0)}% of fees paid',
                  style: TextStyle(
                    fontSize: 12,
                    color: student.feeRemaining <= 0 ? Colors.green : Colors.grey,
                    fontWeight: student.feeRemaining <= 0
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ).animate().fadeIn(delay: 100.ms),

        const SizedBox(height: 20),

        if (subjects.isNotEmpty) ...[
          Text('Subject-wise Fees',
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 10),
          ...subjects.entries.map((entry) {
            final subName = entry.key;
            final totalSubFee = entry.value;
            final paidSub = student.getSubjectPaid(subName);
            final dueSub = student.getSubjectRemaining(subName);
            final subPercent =
                totalSubFee > 0 ? (paidSub / totalSubFee).clamp(0.0, 1.0) : 0.0;

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(subName,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 14)),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: dueSub <= 0
                                ? Colors.green.shade50
                                : Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            dueSub <= 0 ? 'PAID' : 'Rs ${dueSub.toStringAsFixed(0)} due',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: dueSub <= 0 ? Colors.green : Colors.orange,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: subPercent,
                        minHeight: 8,
                        backgroundColor: Colors.grey.shade200,
                        valueColor: AlwaysStoppedAnimation(
                          subPercent >= 1.0 ? Colors.green : AppTheme.primaryBlue,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Total: Rs ${totalSubFee.toStringAsFixed(0)}',
                            style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        Text('Paid: Rs ${paidSub.toStringAsFixed(0)}',
                            style: const TextStyle(
                                fontSize: 12,
                                color: Colors.green,
                                fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ],
                ),
              ),
            ).animate().fadeIn(delay: 150.ms);
          }),
        ],

        // Payment History
        const SizedBox(height: 8),
        if (student.paymentHistoryJson != null &&
            student.paymentHistoryJson!.isNotEmpty)
          _buildPaymentHistory(student),

        const SizedBox(height: 80),
      ],
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
        Text('Payment History',
            style:
                GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 10),
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: history.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final entry = Map<String, dynamic>.from(history[i]);
              final amount = (entry['amount'] ?? 0).toDouble();
              final date = entry['date']?.toString() ?? '';
              final note = entry['note']?.toString() ?? '';
              DateTime? parsed;
              try {
                parsed = DateTime.parse(date);
              } catch (_) {}

              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: amount > 0
                      ? Colors.green.shade50
                      : Colors.red.shade50,
                  child: Icon(
                    amount > 0
                        ? Icons.add_rounded
                        : Icons.remove_rounded,
                    color: amount > 0 ? Colors.green : Colors.red,
                    size: 18,
                  ),
                ),
                title: Text(
                  note.isNotEmpty ? note : 'Payment',
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w500),
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
                    color: amount > 0 ? Colors.green : Colors.red,
                    fontSize: 13,
                  ),
                ),
              );
            },
          ),
        ).animate().fadeIn(delay: 200.ms),
      ],
    );
  }

  Widget _statChip(String label, double amount, Color color) {
    return Column(
      children: [
        Text(
          'Rs ${amount.toStringAsFixed(0)}',
          style: TextStyle(
              fontSize: 15, fontWeight: FontWeight.bold, color: color),
        ),
        const SizedBox(height: 4),
        Text(label,
            style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }
}
