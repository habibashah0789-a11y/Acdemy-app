import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/student_model.dart';
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
    await Future.delayed(const Duration(milliseconds: 500));
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
            ],
          ),
        ).animate().fadeIn(delay: 100.ms),

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
            ).animate().fadeIn(delay: 150.ms);
          }),
        ],

        // Payment History Section
        const SizedBox(height: 12),
        if (student.paymentHistoryJson != null &&
            student.paymentHistoryJson!.isNotEmpty)
          _buildPaymentHistory(student),

        const SizedBox(height: 60),
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
        Row(
          children: [
            const Icon(Icons.history_rounded, size: 18, color: AppTheme.primaryBlue),
            const SizedBox(width: 8),
            Text('Transaction Log', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 15)),
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
