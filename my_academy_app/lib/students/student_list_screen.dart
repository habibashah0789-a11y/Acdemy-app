import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:convert';
import 'dart:io' as io;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:hive_flutter/hive_flutter.dart';

import 'student_detail_screen.dart';
import 'add_student_screen.dart';
import '../models/student_model.dart';
import '../services/database_service.dart';
import '../theme/app_theme.dart';
import '../utils/whatsapp_helper.dart';

class StudentListScreen extends StatefulWidget {
  const StudentListScreen({super.key});

  @override
  State<StudentListScreen> createState() => _StudentListScreenState();
}

class _StudentListScreenState extends State<StudentListScreen> {
  String _searchQuery = '';
  String _selectedGradeFilter = 'All';

  final TextEditingController _searchController = TextEditingController();

  final List<String> _gradeFilters = [
    'All',
    'Ninth',
    'Tenth',
    'First Year',
    'Second Year',
  ];

  List<StudentModel> _filterStudents(List<StudentModel> allStudents) {
    var filtered = allStudents;

    if (_selectedGradeFilter != 'All') {
      filtered = filtered
          .where((student) => student.grade == _selectedGradeFilter)
          .toList();
    }

    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();

      filtered = filtered
          .where(
            (student) =>
                student.name.toLowerCase().contains(query) ||
                student.phone.toLowerCase().contains(query),
          )
          .toList();
    }

    return filtered;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Directory'),
        elevation: 0,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
              decoration: InputDecoration(
                hintText: 'Search students...',
                prefixIcon: const Icon(Icons.search_rounded),
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
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: isDark ? Colors.grey[800] : Colors.grey[100],
              ),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            child: Row(
              children: _gradeFilters.map((grade) {
                final isSelected = _selectedGradeFilter == grade;

                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: FilterChip(
                    label: Text(grade),
                    selected: isSelected,
                    onSelected: (_) {
                      setState(() {
                        _selectedGradeFilter = grade;
                      });
                    },
                    backgroundColor:
                        isDark ? Colors.grey[800] : Colors.grey[100],
                    selectedColor: AppTheme.primaryBlue.withValues(alpha: 0.2),
                    checkmarkColor: AppTheme.primaryBlue,
                    labelStyle: TextStyle(
                      color: isSelected
                          ? AppTheme.primaryBlue
                          : (isDark ? Colors.white70 : Colors.black87),
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                      fontSize: 13,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          Expanded(
            child: ValueListenableBuilder<Box<StudentModel>>(
              valueListenable: DatabaseService.studentBox.listenable(),
              builder: (context, box, _) {
                final allStudents = box.values.toList();
                allStudents.sort((a, b) => b.createdAt.compareTo(a.createdAt));

                final filteredStudents = _filterStudents(allStudents);

                if (filteredStudents.isEmpty) {
                  return _buildEmptyState();
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  itemCount: filteredStudents.length,
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
      floatingActionButton: FloatingActionButton(
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
                content: Text('Student added successfully'),
                duration: Duration(seconds: 2),
              ),
            );
          }
        },
        child: const Icon(Icons.add_rounded),
      ).animate().scale(delay: 400.ms),
    );
  }

  Widget _buildAvatarImage(String url, String initials) {
    if (url.isEmpty) {
      return Center(
        child: Text(
          initials.isNotEmpty ? initials : 'S',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 24,
            color: AppTheme.primaryBlue,
          ),
        ),
      );
    }

    if (url.startsWith('http://') || url.startsWith('https://')) {
      return CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        placeholder: (_, __) => const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
            ),
          ),
        ),
        errorWidget: (_, __, ___) => const Center(
          child: Icon(
            Icons.person_rounded,
            color: AppTheme.primaryBlue,
            size: 30,
          ),
        ),
      );
    }

    if (url.startsWith('data:image') ||
        (!url.contains('/') && !url.contains('\\') && url.length > 100)) {
      try {
        final base64Str = url.contains(',') ? url.split(',').last : url;

        final bytes = base64Decode(base64Str.trim());

        return Image.memory(
          bytes,
          fit: BoxFit.cover,
        );
      } catch (_) {
        // Fall through to fallback icon.
      }
    }

    if (url.startsWith('blob:')) {
      return Image.network(
        url,
        fit: BoxFit.cover,
      );
    }

    if (!kIsWeb) {
      try {
        return Image.file(
          io.File(url),
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return const Center(
              child: Icon(
                Icons.person_rounded,
                color: AppTheme.primaryBlue,
                size: 30,
              ),
            );
          },
        );
      } catch (_) {
        // Fall through to fallback icon.
      }
    }

    return const Center(
      child: Icon(
        Icons.person_rounded,
        color: AppTheme.primaryBlue,
        size: 30,
      ),
    );
  }

  Widget _buildStudentCard(
    StudentModel student,
    int index,
    bool isDark,
  ) {
    return InkWell(
      onTap: () async {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (buildStudentCard) => StudentDetailScreen(
              student: student,
            ),
          ),
        );

        if (result == true && mounted) {
          setState(() {});
        }
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 8,
          ),
          leading: Hero(
            tag: 'student_${student.id}',
            child: Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: _buildAvatarImage(
                  student.profilePicUrl,
                  student.initials,
                ),
              ),
            ),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  student.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
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
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              InkWell(
                onTap: () {
                  WhatsAppHelper.openWhatsApp(
                    context,
                    student.phone,
                  );
                },
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 2.0,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.phone_android_rounded,
                        size: 12,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        student.phone,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? AppTheme.darkTextSecondary
                              : AppTheme.lightTextSecondary,
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
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Icon(
                    Icons.school_rounded,
                    size: 12,
                    color: AppTheme.primaryBlue.withValues(alpha: 0.7),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '${student.grade} • ${student.subject}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.primaryBlue,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _buildFeeBadge(student),
              const SizedBox(height: 4),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: Colors.grey,
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(delay: (index * 50).ms).slideX(begin: 0.1);
  }

  Widget _buildFeeBadge(StudentModel student) {
    final bool isClear = student.feeRemaining <= 0;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: isClear
            ? Colors.green.withValues(alpha: 0.1)
            : Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        isClear ? 'PAID' : 'DUE',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: isClear ? Colors.green : Colors.red,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _searchQuery.isEmpty
                ? Icons.people_outline_rounded
                : Icons.search_off_rounded,
            size: 64,
            color: Colors.grey.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isEmpty ? 'No students yet' : 'No students found',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isEmpty
                ? 'Tap + to add your first student'
                : 'Try a different search term',
            style: const TextStyle(
              color: Colors.grey,
            ),
          ),
          if (_searchQuery.isEmpty) ...[
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AddStudentScreen(),
                  ),
                );

                if (result == true && mounted) {
                  setState(() {});
                }
              },
              icon: const Icon(Icons.add),
              label: const Text('Add Student'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ],
      ),
    ).animate().fadeIn();
  }
}
