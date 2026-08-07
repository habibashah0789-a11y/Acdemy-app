import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../models/student_model.dart';
import '../../services/database_service.dart';
import '../../theme/app_theme.dart';
import 'daily_record_detail_screen.dart';

class DailyRecordData {
  final DateTime date;
  final int studentCount;
  final double totalCollected;
  final double totalRegistrationAmount;
  final List<StudentModel> students;

  DailyRecordData({
    required this.date,
    required this.studentCount,
    required this.totalCollected,
    required this.students,
    this.totalRegistrationAmount = 0,
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
    // Group by date
    final Map<DateTime, List<StudentModel>> grouped = {};
    for (var student in allStudents) {
      // Normalize to date only
      final dateOnly = DateTime(student.createdAt.year, student.createdAt.month, student.createdAt.day);
      grouped.putIfAbsent(dateOnly, () => []).add(student);
    }

    List<DailyRecordData> records = [];
    grouped.forEach((date, students) {
      double totalCollected = students.fold(0.0, (total, s) => total + s.feeSubmitted);
      double totalRegistrationAmount = students.fold(0.0, (total, s) => total + s.totalFee);
      records.add(DailyRecordData(
        date: date,
        studentCount: students.length,
        totalCollected: totalCollected,
        totalRegistrationAmount: totalRegistrationAmount,
        students: students,
      ));
    });

    // Sort newest first
    records.sort((a, b) => b.date.compareTo(a.date));

    // Filter by search date if any
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
                  return const Center(child: CircularProgressIndicator());
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
                              Icon(Icons.group_rounded, size: 14, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                              const SizedBox(width: 4),
                              Text('${record.studentCount} Students'),
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
