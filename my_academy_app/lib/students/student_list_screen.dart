import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
//import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'student_detail_screen.dart';
import 'add_student_screen.dart';
import '../models/student_model.dart';
import '../services/database_service.dart';
import '../theme/app_theme.dart';

class StudentListScreen extends StatefulWidget {
  const StudentListScreen({super.key});

  @override
  State<StudentListScreen> createState() => _StudentListScreenState();
}

class _StudentListScreenState extends State<StudentListScreen> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  List<StudentModel> get _filtered {
    final all = DatabaseService.getAllStudents();
    if (_searchQuery.isEmpty) return all;
    return all.where((s) =>
      s.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
      s.phone.toLowerCase().contains(_searchQuery.toLowerCase())
    ).toList();
  }

  @override
  Widget build(BuildContext context) {
    final students = _filtered;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Directory'),
        actions: [
          IconButton(
            onPressed: () => setState(() {}),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: InputDecoration(
                hintText: 'Search students...',
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
              ),
            ),
          ),
          Expanded(
            child: students.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: students.length,
                  itemBuilder: (context, index) {
                    final s = students[index];
                    return _buildStudentCard(s, index, isDark);
                  },
                ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context, 
          MaterialPageRoute(builder: (_) => const AddStudentScreen())
        ).then((_) => setState(() {})),
        child: const Icon(Icons.add_rounded),
      ).animate().scale(delay: 400.ms),
    );
  }

  Widget _buildStudentCard(StudentModel s, int index, bool isDark) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        onTap: () => Navigator.push(
          context, 
          MaterialPageRoute(builder: (_) => StudentDetailScreen(student: s))
        ).then((_) => setState(() {})),
        leading: Hero(
          tag: 'student_${s.id}',
          child: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: AppTheme.primaryBlue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: s.profilePicUrl.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: s.profilePicUrl,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => const Icon(Icons.person_rounded, color: AppTheme.primaryBlue),
                    errorWidget: (_, __, ___) => const Icon(Icons.person_rounded, color: AppTheme.primaryBlue),
                  )
                : Center(
                    child: Text(
                      s.name.isNotEmpty ? s.name[0].toUpperCase() : 'S',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                        color: AppTheme.primaryBlue,
                      ),
                    ),
                  ),
            ),
          ),
        ),
        title: Text(
          s.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          s.phone,
          style: TextStyle(
            fontSize: 12,
            color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
          ),
        ),
        trailing: _buildFeeBadge(s),
      ),
    ).animate().fadeIn(delay: (index * 50).ms).slideX(begin: 0.1);
  }

  Widget _buildFeeBadge(StudentModel s) {
    final bool isClear = s.feeRemaining <= 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isClear ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        isClear ? 'PAID' : 'DUE',
        style: TextStyle(
          fontSize: 10, 
          fontWeight: FontWeight.bold, 
          color: isClear ? Colors.green : Colors.red
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
            _searchQuery.isEmpty ? Icons.people_outline_rounded : Icons.search_off_rounded, 
            size: 64, 
            color: Colors.grey.withOpacity(0.5)
          ),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isEmpty ? 'No students yet' : 'No students found', 
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isEmpty ? 'Tap + to add your first student' : 'Try a different search term', 
            style: const TextStyle(color: Colors.grey),
          ),
        ],
      ),
    ).animate().fadeIn();
  }
}
