import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/student_model.dart';
import '../models/teacher_model.dart';
import '../services/database_service.dart';
import '../theme/app_theme.dart';
import '../widgets/shimmer_loading_widget.dart';
import '../widgets/student_avatar.dart';

class TeacherDailyRecordData {
  final DateTime date;
  final List<StudentModel> newRegistrations;
  final List<StudentPaymentEvent> installmentPayments;
  final List<StudentModel> defaulters;
  final double totalCollected;
  final double totalRegistrationFee;

  TeacherDailyRecordData({
    required this.date,
    required this.newRegistrations,
    required this.installmentPayments,
    required this.defaulters,
    required this.totalCollected,
    required this.totalRegistrationFee,
  });
}

class StudentPaymentEvent {
  final StudentModel student;
  final double amount;
  final DateTime date;
  final String note;
  final int installmentNumber;

  StudentPaymentEvent({
    required this.student,
    required this.amount,
    required this.date,
    required this.note,
    required this.installmentNumber,
  });
}

class TeacherDailyRecordsScreen extends StatefulWidget {
  final TeacherModel? teacher;
  final String? filterSubject;
  final String? filterSection;

  const TeacherDailyRecordsScreen({
    super.key,
    this.teacher,
    this.filterSubject,
    this.filterSection,
  });

  @override
  State<TeacherDailyRecordsScreen> createState() =>
      _TeacherDailyRecordsScreenState();
}

class _TeacherDailyRecordsScreenState
    extends State<TeacherDailyRecordsScreen> {
  DateTime? _selectedSearchDate;
  final _currencyFmt = NumberFormat.currency(symbol: 'Rs ', decimalDigits: 0);

  bool _studentBelongsToTeacher(StudentModel s, TeacherModel? teacher) {
    if (teacher == null) {
      if (widget.filterSubject != null && widget.filterSubject!.isNotEmpty) {
        final studentSubjects =
            s.subject.split(',').map((x) => x.trim().toLowerCase()).toList();
        if (!studentSubjects.contains(widget.filterSubject!.trim().toLowerCase())) {
          return false;
        }
      }
      if (widget.filterSection != null && widget.filterSection!.isNotEmpty) {
        if (s.classType.trim().toLowerCase() !=
            widget.filterSection!.trim().toLowerCase()) {
          return false;
        }
      }
      return true;
    }

    final studentSubjects =
        s.subject.split(',').map((x) => x.trim().toLowerCase()).toList();
    final teacherSubject = teacher.subject.trim().toLowerCase();
    if (!studentSubjects.contains(teacherSubject)) return false;

    if (teacher.assignedClasses.isNotEmpty) {
      final studentGrade = s.grade.trim().toLowerCase();
      final assignedLower =
          teacher.assignedClasses.map((c) => c.trim().toLowerCase()).toList();
      return assignedLower.contains(studentGrade);
    }

    if (teacher.section.isNotEmpty) {
      if (s.classType.trim().toLowerCase() !=
          teacher.section.trim().toLowerCase()) {
        return false;
      }
    }

    return true;
  }

  List<TeacherDailyRecordData> _processRecords(List<StudentModel> allStudents) {
    final teacher = widget.teacher;
    final subject = teacher?.subject ?? widget.filterSubject ?? '';

    final filteredStudents =
        allStudents.where((s) => _studentBelongsToTeacher(s, teacher)).toList();

    // Collect all payment events and registrations by date
    final Map<DateTime, List<StudentModel>> registrationsByDate = {};
    final Map<DateTime, List<StudentPaymentEvent>> installmentsByDate = {};
    final Set<DateTime> allDates = {};

    for (final s in filteredStudents) {
      // 1. Registration Date
      final regDate = DateTime(s.createdAt.year, s.createdAt.month, s.createdAt.day);
      registrationsByDate.putIfAbsent(regDate, () => []).add(s);
      allDates.add(regDate);

      // 2. Installment payments history
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

              final event = StudentPaymentEvent(
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

    List<TeacherDailyRecordData> records = [];

    for (final date in allDates) {
      final regList = registrationsByDate[date] ?? [];
      final instList = installmentsByDate[date] ?? [];

      // Calculate totals for this date
      double totalCollected = 0;

      // Add collection from new registrations
      for (final s in regList) {
        if (subject.isNotEmpty) {
          totalCollected += s.getSubjectPaid(subject);
        } else {
          totalCollected += s.feeSubmitted;
        }
      }

      // Add collection from installment events on this day (excluding first registration payment to avoid double counting)
      for (final event in instList) {
        if (event.installmentNumber > 1) {
          totalCollected += event.amount;
        }
      }

      double totalRegistrationFee = regList.fold<double>(0.0, (total, s) {
        return total + (subject.isNotEmpty ? s.getSubjectTotalFee(subject) : s.totalFee);
      });

      // Defaulters registered on or before this date
      final defaulters = filteredStudents.where((s) {
        final sRegDate = DateTime(s.createdAt.year, s.createdAt.month, s.createdAt.day);
        if (sRegDate.isAfter(date)) return false;
        final rem = subject.isNotEmpty ? s.getSubjectRemaining(subject) : s.feeRemaining;
        return rem > 0;
      }).toList();

      records.add(TeacherDailyRecordData(
        date: date,
        newRegistrations: regList,
        installmentPayments: instList.where((e) => e.installmentNumber > 1).toList(),
        defaulters: defaulters,
        totalCollected: totalCollected,
        totalRegistrationFee: totalRegistrationFee,
      ));
    }

    // Sort newest first
    records.sort((a, b) => b.date.compareTo(a.date));

    // Filter by selected search date if active
    if (_selectedSearchDate != null) {
      final searchDateOnly = DateTime(_selectedSearchDate!.year,
          _selectedSearchDate!.month, _selectedSearchDate!.day);
      records = records.where((r) => r.date == searchDateOnly).toList();
    }

    return records;
  }

  Future<void> _selectDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedSearchDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: AppTheme.primaryBlue),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _selectedSearchDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final subjectTitle = widget.teacher?.subject ?? widget.filterSubject ?? 'Teacher';

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Daily Records & Payments',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            Text(
              widget.teacher != null
                  ? '${widget.teacher!.name} (${widget.teacher!.subject})'
                  : subjectTitle,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
          ],
        ),
        actions: [
          if (_selectedSearchDate != null)
            IconButton(
              icon: const Icon(Icons.clear_rounded),
              tooltip: 'Clear Date Filter',
              onPressed: () => setState(() => _selectedSearchDate = null),
            ),
          IconButton(
            icon: const Icon(Icons.calendar_month_rounded),
            tooltip: 'Filter by Date',
            onPressed: () => _selectDate(context),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: DatabaseService.getStudentsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: 5,
              itemBuilder: (_, __) =>
                  ShimmerLoadingWidget.listTilePlaceholder(context),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error loading records: ${snapshot.error}',
                style: const TextStyle(color: Colors.red),
              ),
            );
          }

          final allStudents = snapshot.data?.docs
                  .map((doc) => StudentModel.fromFirestore(doc))
                  .toList() ??
              [];

          final records = _processRecords(allStudents);

          // Calculate grand totals across all records
          double grandTotalCollected = records.fold<double>(0.0, (total, r) => total + r.totalCollected);
          int grandTotalNewRegs = records.fold<int>(0, (total, r) => total + r.newRegistrations.length);
          int grandTotalInstallments = records.fold<int>(0, (total, r) => total + r.installmentPayments.length);

          return Column(
            children: [
              // Summary Header Banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.primaryDarkBlue,
                      AppTheme.primaryBlue,
                    ],
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _bannerStat('Total Revenue', _currencyFmt.format(grandTotalCollected), Icons.payments_rounded),
                        _bannerStat('New Admissions', '$grandTotalNewRegs', Icons.person_add_rounded),
                        _bannerStat('Installments', '$grandTotalInstallments', Icons.receipt_long_rounded),
                      ],
                    ),
                    if (_selectedSearchDate != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'Filter Active: ${DateFormat('EEE, MMM dd, yyyy').format(_selectedSearchDate!)}',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ).animate().fadeIn(),

              // Records List
              Expanded(
                child: records.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.search_off_rounded,
                              size: 64,
                              color: Colors.grey.withValues(alpha: 0.4),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No daily records found',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'No student registrations or installment payments on this date.',
                              style: TextStyle(color: Colors.grey[600], fontSize: 13),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: records.length,
                        itemBuilder: (context, index) {
                          final record = records[index];
                          return _buildDailyRecordCard(context, record, isDark, index);
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _bannerStat(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 11,
            color: Colors.white.withValues(alpha: 0.8),
          ),
        ),
      ],
    );
  }

  Widget _buildDailyRecordCard(
      BuildContext context, TeacherDailyRecordData record, bool isDark, int index) {
    final regCount = record.newRegistrations.length;
    final instCount = record.installmentPayments.length;

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: isDark ? AppTheme.darkCard : Colors.white,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TeacherDailyRecordDetailScreen(
                record: record,
                teacher: widget.teacher,
                filterSubject: widget.filterSubject,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.today_rounded,
                          color: AppTheme.primaryBlue,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            DateFormat('EEEE, MMM dd, yyyy').format(record.date),
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          Text(
                            '${regCount + instCount} Total Financial Activity Events',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: isDark ? Colors.grey[400] : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 16,
                    color: Colors.grey[400],
                  ),
                ],
              ),
              const Divider(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      if (regCount > 0)
                        _chip('$regCount New Admissions', AppTheme.primaryBlue),
                      if (instCount > 0)
                        _chip('$instCount Installment Payments', Colors.teal),
                      if (record.defaulters.isNotEmpty)
                        _chip('${record.defaulters.length} Pending Defaulters', Colors.orange),
                    ],
                  ),
                  Text(
                    _currencyFmt.format(record.totalCollected),
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.secondaryGreen,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ).animate(delay: (index * 40).ms).fadeIn().slideY(begin: 0.05);
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Detailed Daily View for Teacher
// ─────────────────────────────────────────────────────────────────────────────
class TeacherDailyRecordDetailScreen extends StatefulWidget {
  final TeacherDailyRecordData record;
  final TeacherModel? teacher;
  final String? filterSubject;

  const TeacherDailyRecordDetailScreen({
    super.key,
    required this.record,
    this.teacher,
    this.filterSubject,
  });

  @override
  State<TeacherDailyRecordDetailScreen> createState() =>
      _TeacherDailyRecordDetailScreenState();
}

class _TeacherDailyRecordDetailScreenState
    extends State<TeacherDailyRecordDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _currencyFmt = NumberFormat.currency(symbol: 'Rs ', decimalDigits: 0);

  String get _subject =>
      widget.teacher?.subject ?? widget.filterSubject ?? '';

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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final record = widget.record;

    return Scaffold(
      backgroundColor:
          isDark ? AppTheme.darkBackground : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          DateFormat('MMM dd, yyyy').format(record.date),
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelStyle:
              GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 12),
          unselectedLabelStyle:
              GoogleFonts.poppins(fontWeight: FontWeight.w500, fontSize: 12),
          indicatorColor: AppTheme.primaryBlue,
          labelColor: AppTheme.primaryBlue,
          tabs: [
            Tab(text: 'New Regs (${record.newRegistrations.length})'),
            Tab(text: 'Installments (${record.installmentPayments.length})'),
            Tab(text: 'Defaulters (${record.defaulters.length})'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildNewRegistrationsTab(isDark),
          _buildInstallmentsTab(isDark),
          _buildDefaultersTab(isDark),
        ],
      ),
    );
  }

  // ── Tab 1: New Admissions on this date ──
  Widget _buildNewRegistrationsTab(bool isDark) {
    final regList = widget.record.newRegistrations;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: _statTile(
                    'Admissions',
                    '${regList.length} Students',
                    Icons.person_add_rounded,
                    AppTheme.primaryBlue,
                    isDark,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _statTile(
                    'Reg. Fee Collected',
                    _currencyFmt.format(regList.fold<double>(0.0, (total, s) {
                      return total +
                          (_subject.isNotEmpty
                              ? s.getSubjectPaid(_subject)
                              : s.feeSubmitted);
                    })),
                    Icons.account_balance_wallet_rounded,
                    Colors.green,
                    isDark,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (regList.isEmpty)
          const SliverFillRemaining(
            child: Center(
              child: Text('No new student registrations on this date.'),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final student = regList[index];
                  final subjectPaid = _subject.isNotEmpty
                      ? student.getSubjectPaid(_subject)
                      : student.feeSubmitted;
                  final subjectTotal = _subject.isNotEmpty
                      ? student.getSubjectTotalFee(_subject)
                      : student.totalFee;

                  return _studentCard(
                    context: context,
                    student: student,
                    isDark: isDark,
                    badgeText: 'NEW REGISTRATION',
                    badgeColor: AppTheme.primaryBlue,
                    paymentDateTime: student.createdAt,
                    subtitleContent: Row(
                      children: [
                        _miniChip(
                            'Initial Paid: ${_currencyFmt.format(subjectPaid)}',
                            Colors.green),
                        const SizedBox(width: 6),
                        _miniChip(
                            'Total Fee: ${_currencyFmt.format(subjectTotal)}',
                            AppTheme.primaryBlue),
                      ],
                    ),
                  );
                },
                childCount: regList.length,
              ),
            ),
          ),
      ],
    );
  }

  // ── Tab 2: Installments Collected on this date ──
  Widget _buildInstallmentsTab(bool isDark) {
    final instList = widget.record.installmentPayments;
    final totalInstallmentAmt =
        instList.fold<double>(0.0, (total, e) => total + e.amount);

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: _statTile(
                    'Installments Paid',
                    '${instList.length} Transactions',
                    Icons.receipt_long_rounded,
                    Colors.teal,
                    isDark,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _statTile(
                    'Amount Received',
                    _currencyFmt.format(totalInstallmentAmt),
                    Icons.payments_rounded,
                    Colors.green,
                    isDark,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (instList.isEmpty)
          const SliverFillRemaining(
            child: Center(
              child: Text(
                  'No 2nd/3rd installment payments were recorded on this date.'),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final event = instList[index];
                  final s = event.student;
                  final subjectRem = _subject.isNotEmpty
                      ? s.getSubjectRemaining(_subject)
                      : s.feeRemaining;

                  return _studentCard(
                    context: context,
                    student: s,
                    isDark: isDark,
                    badgeText: 'INSTALLMENT #${event.installmentNumber}',
                    badgeColor: Colors.teal,
                    paymentDateTime: event.date,
                    subtitleContent: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            _miniChip(
                              'Paid on Date: ${_currencyFmt.format(event.amount)}',
                              Colors.green,
                            ),
                            const SizedBox(width: 6),
                            _miniChip(
                              'Remaining: ${_currencyFmt.format(subjectRem)}',
                              subjectRem > 0 ? Colors.red : Colors.green,
                            ),
                          ],
                        ),
                        if (event.note.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Note: ${event.note}',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: Colors.grey[600],
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
                childCount: instList.length,
              ),
            ),
          ),
      ],
    );
  }

  // ── Tab 3: Defaulters on this date ──
  Widget _buildDefaultersTab(bool isDark) {
    final defs = widget.record.defaulters;
    final totalPending = defs.fold<double>(0.0, (total, s) {
      return total +
          (_subject.isNotEmpty ? s.getSubjectRemaining(_subject) : s.feeRemaining);
    });

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: _statTile(
                    'Defaulter Count',
                    '${defs.length} Students',
                    Icons.warning_amber_rounded,
                    Colors.orange,
                    isDark,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _statTile(
                    'Total Fee Pending',
                    _currencyFmt.format(totalPending),
                    Icons.pending_rounded,
                    Colors.red,
                    isDark,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (defs.isEmpty)
          const SliverFillRemaining(
            child: Center(
              child: Text('🎉 No pending defaulters for this subject on this date!'),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final student = defs[index];
                  final subjectRem = _subject.isNotEmpty
                      ? student.getSubjectRemaining(_subject)
                      : student.feeRemaining;
                  final subjectPaid = _subject.isNotEmpty
                      ? student.getSubjectPaid(_subject)
                      : student.feeSubmitted;

                  return _studentCard(
                    context: context,
                    student: student,
                    isDark: isDark,
                    badgeText: 'PENDING',
                    badgeColor: Colors.red,
                    paymentDateTime: student.createdAt,
                    subtitleContent: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            _miniChip(
                                'Paid: ${_currencyFmt.format(subjectPaid)}',
                                Colors.green),
                            const SizedBox(width: 6),
                            _miniChip(
                                'Due: ${_currencyFmt.format(subjectRem)}',
                                Colors.red),
                          ],
                        ),
                      ],
                    ),
                  );
                },
                childCount: defs.length,
              ),
            ),
          ),
      ],
    );
  }

  Widget _statTile(
      String label, String val, IconData icon, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
                Text(
                  val,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                  overflow: TextOverflow.ellipsis,
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
    required String badgeText,
    required Color badgeColor,
    required Widget subtitleContent,
    DateTime? paymentDateTime,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      color: isDark ? AppTheme.darkCard : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            StudentAvatar(
              student: student,
              size: 46,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    student.name,
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    'Roll: ${student.studentCode} • ${student.grade} (${student.classType})',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                  if (paymentDateTime != null) ...[
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(
                          Icons.event_available_rounded,
                          size: 12,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          DateFormat('MMM dd, yyyy • hh:mm a').format(paymentDateTime),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 4),
                  subtitleContent,
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: badgeColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                badgeText,
                style: GoogleFonts.poppins(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: badgeColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniChip(String label, Color color) {
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
}
