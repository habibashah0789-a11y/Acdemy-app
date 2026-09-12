import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/payment_config_model.dart';
import '../models/student_model.dart';
import '../services/payment_service.dart';
import '../theme/app_theme.dart';

class StudentOnlineFeeDialog extends StatefulWidget {
  final StudentModel student;

  const StudentOnlineFeeDialog({super.key, required this.student});

  @override
  State<StudentOnlineFeeDialog> createState() => _StudentOnlineFeeDialogState();
}

class _StudentOnlineFeeDialogState extends State<StudentOnlineFeeDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _refController = TextEditingController();
  final _noteController = TextEditingController();

  PaymentConfigModel? _config;
  bool _isSubmitting = false;
  String _selectedMethod = 'BANK_TRANSFER'; // BANK_TRANSFER, EASYPAISA, JAZZCASH

  @override
  void initState() {
    super.initState();
    if (widget.student.feeRemaining > 0) {
      _amountController.text = widget.student.feeRemaining.toStringAsFixed(0);
    }
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    final cfg = await PaymentService.getPaymentConfigOnce();
    if (mounted) {
      setState(() {
        _config = cfg;
      });
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _refController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submitPayment() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final amount = double.tryParse(_amountController.text.trim()) ?? 0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid payment amount.')),
      );
      return;
    }

    final ref = _refController.text.trim();
    if (ref.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the transaction reference / slip number.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      String providerName = 'Bank Transfer';
      if (_selectedMethod == 'EASYPAISA') {
        providerName = 'EasyPaisa';
      } else if (_selectedMethod == 'JAZZCASH') {
        providerName = 'JazzCash';
      }

      await PaymentService.submitStudentFeePayment(
        student: widget.student,
        amount: amount,
        paymentMethod: _selectedMethod,
        providerName: providerName,
        providerTransactionId: ref,
        description: _noteController.text.trim().isNotEmpty
            ? _noteController.text.trim()
            : 'Online fee payment submitted by ${widget.student.name}',
      );

      if (mounted) {
        Navigator.pop(context, true);
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: AppTheme.secondaryGreen, size: 28),
                const SizedBox(width: 10),
                const Text('Payment Submitted'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your payment of Rs ${amount.toStringAsFixed(0)} has been submitted for admin verification.',
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.receipt_long_rounded, color: AppTheme.primaryBlue, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Transaction Ref: $ref',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Once verified by administration, your fee balance will update automatically.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
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
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied to clipboard!'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cfg = _config ?? PaymentConfigModel.defaultConfig();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 580),
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryBlue.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.payment_rounded, color: AppTheme.primaryBlue, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Submit Online Fee',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          Text(
                            widget.student.name,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Payment Method Choice Tabs
              Text(
                'Select Payment Method',
                style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _buildMethodTab(
                      id: 'BANK_TRANSFER',
                      title: 'Bank Transfer',
                      icon: Icons.account_balance_rounded,
                      isSelected: _selectedMethod == 'BANK_TRANSFER',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildMethodTab(
                      id: 'EASYPAISA',
                      title: 'EasyPaisa',
                      icon: Icons.phone_android_rounded,
                      isSelected: _selectedMethod == 'EASYPAISA',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildMethodTab(
                      id: 'JAZZCASH',
                      title: 'JazzCash',
                      icon: Icons.wallet_rounded,
                      isSelected: _selectedMethod == 'JAZZCASH',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Academy Destination Details Box
              _buildAccountDetailsBox(cfg, isDark),
              const SizedBox(height: 20),

              // Form inputs
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: _amountController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Amount (Rs)',
                        prefixIcon: Icon(Icons.money_rounded),
                        hintText: 'e.g. 5000',
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Please enter amount';
                        }
                        final parsed = double.tryParse(val.trim());
                        if (parsed == null || parsed <= 0) {
                          return 'Enter a valid positive amount';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _refController,
                      decoration: InputDecoration(
                        labelText: 'Transaction Reference / Slip ID',
                        prefixIcon: const Icon(Icons.receipt_long_rounded),
                        hintText: _selectedMethod == 'BANK_TRANSFER'
                            ? 'e.g. Bank Ref or Deposit Slip Number'
                            : 'e.g. TRX-94829104',
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Transaction Reference is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _noteController,
                      decoration: const InputDecoration(
                        labelText: 'Note / Remarks (Optional)',
                        prefixIcon: Icon(Icons.notes_rounded),
                        hintText: 'e.g. Paid 1st Installment for Biology & Chemistry',
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _isSubmitting ? null : _submitPayment,
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Icon(Icons.send_rounded, color: Colors.white),
                  label: Text(
                    _isSubmitting ? 'Submitting Payment...' : 'Submit Payment for Verification',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.secondaryGreen,
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

  Widget _buildMethodTab({
    required String id,
    required String title,
    required IconData icon,
    required bool isSelected,
  }) {
    return InkWell(
      onTap: () => setState(() => _selectedMethod = id),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryBlue.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppTheme.primaryBlue : Colors.grey.withValues(alpha: 0.3),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 22,
              color: isSelected ? AppTheme.primaryBlue : Colors.grey,
            ),
            const SizedBox(height: 6),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? AppTheme.primaryBlue : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountDetailsBox(PaymentConfigModel cfg, bool isDark) {
    if (_selectedMethod == 'BANK_TRANSFER') {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.primaryBlue.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  cfg.bankName,
                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.primaryBlue),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlue.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('Official Bank', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _infoRow('Title', cfg.accountTitle, onCopy: () => _copyToClipboard(cfg.accountTitle, 'Account Title')),
            const SizedBox(height: 6),
            _infoRow('Account #', cfg.accountNumber, onCopy: () => _copyToClipboard(cfg.accountNumber, 'Account Number')),
            const SizedBox(height: 6),
            _infoRow('IBAN', cfg.iban, onCopy: () => _copyToClipboard(cfg.iban, 'IBAN')),
          ],
        ),
      );
    }

    if (_selectedMethod == 'EASYPAISA') {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFECFDF5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.secondaryGreen.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'EasyPaisa Account',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.secondaryGreen),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.secondaryGreen.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('Mobile Wallet', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.secondaryGreen)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _infoRow('Title', cfg.easypaisaTitle, onCopy: () => _copyToClipboard(cfg.easypaisaTitle, 'EasyPaisa Title')),
            const SizedBox(height: 6),
            _infoRow('Account / Mobile', cfg.easypaisaNumber, onCopy: () => _copyToClipboard(cfg.easypaisaNumber, 'EasyPaisa Number')),
          ],
        ),
      );
    }

    // JAZZCASH
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber.shade700.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'JazzCash Account',
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.amber.shade800),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.amber.shade700.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('Mobile Wallet', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.amber.shade800)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _infoRow('Title', cfg.jazzcashTitle, onCopy: () => _copyToClipboard(cfg.jazzcashTitle, 'JazzCash Title')),
          const SizedBox(height: 6),
          _infoRow('Account / Mobile', cfg.jazzcashNumber, onCopy: () => _copyToClipboard(cfg.jazzcashNumber, 'JazzCash Number')),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value, {VoidCallback? onCopy}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('$label: ', style: const TextStyle(fontSize: 12, color: Colors.grey)),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (onCopy != null) ...[
          const SizedBox(width: 6),
          InkWell(
            onTap: onCopy,
            borderRadius: BorderRadius.circular(4),
            child: const Padding(
              padding: EdgeInsets.all(2),
              child: Icon(Icons.copy_rounded, size: 14, color: Colors.grey),
            ),
          ),
        ],
      ],
    );
  }
}
