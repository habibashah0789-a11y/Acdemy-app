import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'student_detail_screen.dart';
import 'add_student_screen.dart';
import '../models/student_model.dart';
import '../services/database_service.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_card.dart';
import '../widgets/empty_state_widget.dart';
import '../widgets/student_avatar.dart';
import '../utils/whatsapp_helper.dart';

class StudentListScreen extends StatefulWidget {
  const StudentListScreen({super.key});

  @override
  State<StudentListScreen> createState() => _StudentListScreenState();
}

class _StudentListScreenState extends State<StudentListScreen> {
  String _searchQuery = '';
  String _selectedGradeFilter = 'All';
  Timer? _debounce;

  final TextEditingController _searchController = TextEditingController();

  final List<String> _gradeFilters = [
    'All',
    'Ninth',
    'Tenth',
    'First Year',
    'Second Year',
  ];

  List<StudentModel> _filterStudents(List<StudentModel> allStudents) {
    if (_selectedGradeFilter == 'All' && _searchQuery.isEmpty) {
      return allStudents;
    }

    final query = _searchQuery.toLowerCase();
    final hasGradeFilter = _selectedGradeFilter != 'All';
    final hasSearchQuery = query.isNotEmpty;

    return allStudents.where((student) {
      if (hasGradeFilter && student.grade != _selectedGradeFilter) {
        return false;
      }
      if (hasSearchQuery) {
        return student.name.toLowerCase().contains(query) ||
            student.phone.toLowerCase().contains(query) ||
            student.studentCode.toLowerCase().contains(query);
      }
      return true;
    }).toList();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackground : AppTheme.lightBackground,
      appBar: AppBar(
        title: Text('Student Directory', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Search & Filter Header Container
          Container(
            color: isDark ? AppTheme.darkSurface : Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  onChanged: (value) {
                    _debounce?.cancel();
                    _debounce = Timer(const Duration(milliseconds: 200), () {
                      if (mounted) {
                        setState(() {
                          _searchQuery = value;
                        });
                      }
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'Search by name, phone or code...',
                    prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.primaryBlue),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchQuery = '';
                              });
                            },
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _gradeFilters.map((grade) {
                      final isSelected = _selectedGradeFilter == grade;

                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: ChoiceChip(
                          label: Text(grade),
                          selected: isSelected,
                          onSelected: (_) {
                            setState(() {
                              _selectedGradeFilter = grade;
                            });
                          },
                          selectedColor: AppTheme.primaryBlue,
                          backgroundColor: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.shade100,
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            fontSize: 12,
                          ),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ValueListenableBuilder<Box<StudentModel>>(
              valueListenable: DatabaseService.studentBox.listenable(),
              builder: (context, box, _) {
                final allStudents = box.values.toList();
                allStudents.sort((a, b) => b.createdAt.compareTo(a.createdAt));

                final filteredStudents = _filterStudents(allStudents);

                if (filteredStudents.isEmpty) {
                  return EmptyStateWidget(
                    title: _searchQuery.isEmpty ? 'No Students Enrolled' : 'No Students Found',
                    description: _searchQuery.isEmpty
                        ? 'Tap the floating button below to register a student.'
                        : 'Try searching with a different term.',
                    icon: _searchQuery.isEmpty ? Icons.people_outline_rounded : Icons.search_off_rounded,
                    actionLabel: _searchQuery.isEmpty ? 'Add Student' : null,
                    onAction: _searchQuery.isEmpty
                        ? () async {
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const AddStudentScreen()),
                            );
                            if (result == true && mounted) setState(() {});
                          }
                        : null,
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredStudents.length,
                  cacheExtent: 600,
                  addAutomaticKeepAlives: true,
                  itemBuilder: (context, index) {
                    final student = filteredStudents[index];

                    return _buildStudentCard(
                      student,
                      index,
                      isDark,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const AddStudentScreen(),
            ),
          );

          if (!context.mounted) return;

          if (result == true) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Student registered successfully'),
                duration: Duration(seconds: 2),
              ),
            );
          }
        },
        icon: const Icon(Icons.person_add_rounded),
        label: Text('Add Student', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
      ).animate().scale(delay: 300.ms),
    );
  }

  Widget _buildStudentCard(
    StudentModel student,
    int index,
    bool isDark,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: CustomCard(
        padding: const EdgeInsets.all(14),
        onTap: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (buildStudentCard) => StudentDetailScreen(student: student),
            ),
          );

          if (result == true && mounted) {
            setState(() {});
          }
        },
        child: Row(
          children: [
            Hero(
              tag: 'student_${student.id}',
              child: StudentAvatar(
                student: student,
                size: 56,
                isCircle: false,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          student.name,
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          student.studentCode,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryBlue,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  InkWell(
                    onTap: () {
                      WhatsAppHelper.openWhatsApp(context, student.phone);
                    },
                    borderRadius: BorderRadius.circular(4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.phone_android_rounded,
                          size: 13,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          student.phone,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.send_rounded,
                          color: Color(0xFF25D366),
                          size: 11,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${student.grade} • ${student.classType}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.primaryBlue,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _buildFeeBadge(student),
                const SizedBox(height: 8),
                const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeeBadge(StudentModel student) {
    final bool isClear = student.feeRemaining <= 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isClear
            ? AppTheme.secondaryGreen.withValues(alpha: 0.12)
            : AppTheme.warningRed.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        isClear ? 'PAID' : 'DUE',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: isClear ? AppTheme.secondaryGreen : AppTheme.warningRed,
        ),
      ),
    );
  }
}
