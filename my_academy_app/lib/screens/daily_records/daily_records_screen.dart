import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../models/student_model.dart';
import '../../services/database_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/shimmer_loading_widget.dart';
import 'daily_record_detail_screen.dart';

import 'dart:convert';

class AdminStudentPaymentEvent {
  final StudentModel student;
  final double amount;
  final DateTime date;
  final String note;
  final int installmentNumber;

  AdminStudentPaymentEvent({
    required this.student,
    required this.amount,
    required this.date,
    required this.note,
    required this.installmentNumber,
  });
}

class DailyRecordData {
  final DateTime date;
  final List<StudentModel> newRegistrations;
  final List<AdminStudentPaymentEvent> installmentPayments;
  final List<StudentModel> defaulters;
  final double totalCollected;
  final double totalRegistrationAmount;

  DailyRecordData({
    required this.date,
    required this.newRegistrations,
    required this.installmentPayments,
    required this.defaulters,
    required this.totalCollected,
    required this.totalRegistrationAmount,
  });
}

class DailyRecordsScreen extends StatefulWidget {
  const DailyRecordsScreen({super.key});

  @override
  State<DailyRecordsScreen> createState() => _DailyRecordsScreenState();
}

class _DailyRecordsScreenState extends State<DailyRecordsScreen> {
  DateTime? _selectedSearchDate;

  List<DailyRecordData> _groupAndFilterStudents(List<StudentModel> allStudents) {
    final Map<DateTime, List<StudentModel>> registrationsByDate = {};
    final Map<DateTime, List<AdminStudentPaymentEvent>> installmentsByDate = {};
    final Set<DateTime> allDates = {};

    for (final s in allStudents) {
      final regDate = DateTime(s.createdAt.year, s.createdAt.month, s.createdAt.day);
      registrationsByDate.putIfAbsent(regDate, () => []).add(s);
      allDates.add(regDate);

      if (s.paymentHistoryJson != null && s.paymentHistoryJson!.isNotEmpty) {
        try {
          final List<dynamic> history = jsonDecode(s.paymentHistoryJson!);
          for (int i = 0; i < history.length; i++) {
            final entry = history[i] as Map<String, dynamic>;
            final rawDate = DateTime.tryParse(entry['date'] ?? '');
            if (rawDate != null) {
              final pDate = DateTime(rawDate.year, rawDate.month, rawDate.day);
              final amt = (entry['amount'] as num?)?.toDouble() ?? 0;
              final note = entry['note']?.toString() ?? 'Payment';

              final event = AdminStudentPaymentEvent(
                student: s,
                amount: amt,
                date: rawDate,
                note: note,
                installmentNumber: i + 1,
              );

              installmentsByDate.putIfAbsent(pDate, () => []).add(event);
              allDates.add(pDate);
            }
          }
        } catch (_) {}
      }
    }

    List<DailyRecordData> records = [];
    for (final date in allDates) {
      final regList = registrationsByDate[date] ?? [];
      final instList = installmentsByDate[date] ?? [];

      double totalCollected = 0;
      
      for (final event in instList) {
        totalCollected += event.amount;
      }

      for (final s in regList) {
        if (s.paymentHistoryJson == null || s.paymentHistoryJson!.isEmpty) {
          totalCollected += s.feeSubmitted;
        }
      }

      double totalRegistrationAmount = regList.fold(0.0, (total, s) => total + s.totalFee);

      final defaulters = allStudents.where((s) {
        final sRegDate = DateTime(s.createdAt.year, s.createdAt.month, s.createdAt.day);
        if (sRegDate.isAfter(date)) return false;
        return s.feeRemaining > 0;
      }).toList();

      records.add(DailyRecordData(
        date: date,
        newRegistrations: regList,
        installmentPayments: instList.where((e) => e.installmentNumber > 1).toList(),
        defaulters: defaulters,
        totalCollected: totalCollected,
        totalRegistrationAmount: totalRegistrationAmount,
      ));
    }

    records.sort((a, b) => b.date.compareTo(a.date));

    if (_selectedSearchDate != null) {
      final searchDateOnly = DateTime(_selectedSearchDate!.year, _selectedSearchDate!.month, _selectedSearchDate!.day);
      records = records.where((r) => r.date == searchDateOnly).toList();
    }

    return records;
  }

  Future<void> _selectSearchDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedSearchDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppTheme.primaryBlue,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedSearchDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Records'),
        elevation: 0,
        actions: [
          if (_selectedSearchDate != null)
            IconButton(
              icon: const Icon(Icons.clear_rounded),
              onPressed: () {
                setState(() {
                  _selectedSearchDate = null;
                });
              },
            ),
          IconButton(
            icon: const Icon(Icons.calendar_month_rounded),
            onPressed: () => _selectSearchDate(context),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_selectedSearchDate != null)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              color: AppTheme.primaryBlue.withValues(alpha: 0.1),
              width: double.infinity,
              child: Text(
                'Showing records for: ${DateFormat('MMM dd, yyyy').format(_selectedSearchDate!)}',
                style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryBlue),
              ),
            ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: DatabaseService.getStudentsStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: 5,
                    itemBuilder: (context, _) => ShimmerLoadingWidget.listTilePlaceholder(context),
                  );
                }
                
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)),
                  );
                }
                
                final allStudents = snapshot.data?.docs.map((doc) {
                  return StudentModel.fromFirestore(doc);
                }).toList() ?? [];
                
                final records = _groupAndFilterStudents(allStudents);
                
                if (records.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.receipt_long_rounded, size: 64, color: Colors.grey.withValues(alpha: 0.5)),
                        const SizedBox(height: 16),
                        const Text('No records found', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  );
                }
                
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: records.length,
                  itemBuilder: (context, index) {
                    final record = records[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => DailyRecordDetailScreen(record: record),
                            ),
                          );
                        },
                        leading: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.today_rounded, color: AppTheme.primaryBlue),
                        ),
                        title: Text(
                          DateFormat('MMM dd, yyyy').format(record.date),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Row(
                            children: [
                              Icon(Icons.person_add_alt_1_rounded, size: 14, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                              const SizedBox(width: 4),
                              Text('${record.newRegistrations.length} Regs'),
                              const SizedBox(width: 12),
                              Icon(Icons.receipt_long_rounded, size: 14, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                              const SizedBox(width: 4),
                              Text('${record.installmentPayments.length} Installs'),
                            ],
                          ),
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text('Collected', style: TextStyle(fontSize: 10, color: Colors.grey)),
                            Text(
                              'Rs. ${record.totalCollected.toStringAsFixed(0)}',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 14),
                            ),
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
      ),
    );
  }
}
