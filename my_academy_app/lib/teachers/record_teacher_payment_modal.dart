import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/teacher_model.dart';
import '../models/teacher_payout_model.dart';
import '../services/teacher_payout_service.dart';
import '../services/teacher_service.dart';

class RecordTeacherPaymentModal extends StatefulWidget {
  final TeacherModel? preselectedTeacher;

  const RecordTeacherPaymentModal({super.key, this.preselectedTeacher});

  @override
  State<RecordTeacherPaymentModal> createState() =>
      _RecordTeacherPaymentModalState();
}

class _RecordTeacherPaymentModalState extends State<RecordTeacherPaymentModal> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _reasonController = TextEditingController();

  TeacherModel? _selectedTeacher;
  List<TeacherModel> _allTeachers = [];
  bool _isLoadingTeachers = true;
  bool _isSubmitting = false;

  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();

  final List<String> _quickReasons = [
    'Monthly Salary',
    'Teaching Allowance',
    'Performance Bonus',
    'Advance Payment',
    'Special Incentive',
  ];

  @override
  void initState() {
    super.initState();
    _selectedTeacher = widget.preselectedTeacher;
    _reasonController.text = 'Monthly Salary';
    _loadTeachers();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _loadTeachers() async {
    try {
      final teachers = await TeacherService.getAllTeachersOnce();
      if (mounted) {
        setState(() {
          _allTeachers = teachers;
          _isLoadingTeachers = false;
          if (_selectedTeacher == null && teachers.isNotEmpty) {
            _selectedTeacher = teachers.first;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingTeachers = false);
      }
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.indigo.shade800,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.indigo.shade800,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  DateTime get _combinedDateTime {
    return DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );
  }

  void _reviewAndConfirm() {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedTeacher == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a teacher')),
      );
      return;
    }

    final amount = double.tryParse(_amountController.text.trim()) ?? 0.0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid payment amount')),
      );
      return;
    }

    final txnRef = TeacherPayoutService.generateTxnRef();
    final fullDateTime = _combinedDateTime;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.indigo.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.verified_user_rounded,
                    color: Colors.indigo.shade800),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Bank Verification',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Poppins',
                  ),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Please confirm the payment record details carefully. Once logged, this transaction cannot be altered.',
                  style: TextStyle(fontSize: 13, color: Colors.black54),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Column(
                    children: [
                      _buildVerifyRow(
                          'Transaction Ref', txnRef, isBold: true),
                      const Divider(height: 16),
                      _buildVerifyRow('Target Teacher', _selectedTeacher!.name),
                      _buildVerifyRow('Subject & Section',
                          '${_selectedTeacher!.subject} (${_selectedTeacher!.section})'),
                      _buildVerifyRow('Reason', _reasonController.text.trim()),
                      _buildVerifyRow(
                          'Date & Time',
                          DateFormat('dd MMM yyyy, hh:mm a')
                              .format(fullDateTime)),
                      const Divider(height: 16),
                      _buildVerifyRow(
                        'Total Payment',
                        'Rs ${NumberFormat('#,##0').format(amount)}',
                        isHighlighted: true,
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
              child:
                  Text('Edit Details', style: TextStyle(color: Colors.grey.shade700)),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                _processSubmission(amount, txnRef, fullDateTime);
              },
              icon: const Icon(Icons.check_circle_rounded, color: Colors.white),
              label: const Text('Confirm & Authorize',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: emeraldColor,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _processSubmission(
      double amount, String txnRef, DateTime fullDateTime) async {
    setState(() => _isSubmitting = true);

    try {
      final payout = await TeacherPayoutService.recordPayout(
        teacherId: _selectedTeacher!.id,
        teacherName: _selectedTeacher!.name,
        teacherSubject: _selectedTeacher!.subject,
        teacherSection: _selectedTeacher!.section,
        amount: amount,
        reason: _reasonController.text.trim(),
        paymentDate: fullDateTime,
        adminName: 'Administrator',
      );

      if (mounted) {
        setState(() => _isSubmitting = false);
        Navigator.pop(context, payout);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: emeraldColor,
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Payment of Rs ${amount.toStringAsFixed(0)} successfully logged for ${_selectedTeacher!.name}!',
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error recording payout: $e')),
        );
      }
    }
  }

  Widget _buildVerifyRow(String label, String value,
      {bool isBold = false, bool isHighlighted = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w500)),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: isHighlighted ? 15 : 12,
                fontWeight: isHighlighted || isBold
                    ? FontWeight.bold
                    : FontWeight.w600,
                color: isHighlighted
                    ? Colors.indigo.shade900
                    : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final formattedDate = DateFormat('dd MMM yyyy').format(_selectedDate);
    final formattedTime = _selectedTime.format(context);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
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
              // Header Drag Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Title
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.indigo.shade50,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(Icons.account_balance_wallet_rounded,
                        color: Colors.indigo.shade800, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Record Teacher Payment',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Poppins',
                        ),
                      ),
                      Text(
                        'Issue verified payout record & notification',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Teacher Picker
              const Text('Target Teacher',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87)),
              const SizedBox(height: 6),
              _isLoadingTeachers
                  ? const Center(child: CircularProgressIndicator())
                  : Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<TeacherModel>(
                          value: _selectedTeacher,
                          isExpanded: true,
                          hint: const Text('Select Teacher'),
                          items: _allTeachers.map((t) {
                            return DropdownMenuItem<TeacherModel>(
                              value: t,
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 12,
                                    backgroundColor: Colors.indigo.shade100,
                                    child: Text(
                                      t.name.isNotEmpty
                                          ? t.name[0].toUpperCase()
                                          : 'T',
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.indigo.shade900,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      '${t.name} (${t.subject} - ${t.section})',
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _selectedTeacher = val);
                            }
                          },
                        ),
                      ),
                    ),
              const SizedBox(height: 16),

              // Amount Input
              const Text('Payment Amount (PKR)',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87)),
              const SizedBox(height: 6),
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.payments_rounded,
                      color: emeraldColor),
                  hintText: 'e.g. 25000',
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please enter amount';
                  }
                  if (double.tryParse(val.trim()) == null) {
                    return 'Enter a valid number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Quick Reasons Chips
              const Text('Payment Reason',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: _quickReasons.map((reason) {
                  final isSelected = _reasonController.text.trim() == reason;
                  return ChoiceChip(
                    label: Text(reason, style: const TextStyle(fontSize: 11)),
                    selected: isSelected,
                    selectedColor: Colors.indigo.shade100,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _reasonController.text = reason);
                      }
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _reasonController,
                decoration: InputDecoration(
                  hintText: 'Or enter custom reason...',
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please specify payment reason';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Date & Time Picker Row
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: _pickDate,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today_rounded,
                                size: 18, color: Colors.indigo),
                            const SizedBox(width: 8),
                            Text(formattedDate,
                                style: const TextStyle(
                                    fontSize: 12, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      onTap: _pickTime,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.access_time_rounded,
                                size: 18, color: Colors.indigo),
                            const SizedBox(width: 8),
                            Text(formattedTime,
                                style: const TextStyle(
                                    fontSize: 12, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _isSubmitting ? null : _reviewAndConfirm,
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.verified_outlined, color: Colors.white),
                  label: Text(
                    _isSubmitting
                        ? 'Processing Payment...'
                        : 'Review & Verify Payment',
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo.shade800,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
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

const Color emeraldColor = Color(0xFF10B981);
