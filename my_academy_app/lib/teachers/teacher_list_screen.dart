import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
//import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'teacher_detail_screen.dart';
import 'add_teacher_screen.dart';
import '../models/teacher_model.dart';
import '../services/database_service.dart';
//import '../theme/app_theme.dart';

class TeacherListScreen extends StatefulWidget {
  const TeacherListScreen({super.key});

  @override
  State<TeacherListScreen> createState() => _TeacherListScreenState();
}

class _TeacherListScreenState extends State<TeacherListScreen> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  List<TeacherModel> get _filtered {
    final all = DatabaseService.getAllTeachers();
    if (_searchQuery.isEmpty) return all;
    return all.where((t) =>
      t.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
      t.subject.toLowerCase().contains(_searchQuery.toLowerCase())
    ).toList();
  }

  @override
  Widget build(BuildContext context) {
    final teachers = _filtered;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Faculty Directory'),
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
                hintText: 'Search faculty...',
                prefixIcon: const Icon(Icons.search_rounded),
              ),
            ),
          ),
          Expanded(
            child: teachers.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: teachers.length,
                  itemBuilder: (context, index) {
                    final t = teachers[index];
                    return _buildTeacherCard(t, index, isDark);
                  },
                ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context, 
          MaterialPageRoute(builder: (_) => const AddTeacherScreen())
        ).then((_) => setState(() {})),
        child: const Icon(Icons.person_add_rounded),
      ).animate().scale(delay: 400.ms),
    );
  }

  Widget _buildTeacherCard(TeacherModel t, int index, bool isDark) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        onTap: () => Navigator.push(
          context, 
          MaterialPageRoute(builder: (_) => TeacherDetailScreen(teacher: t))
        ).then((_) => setState(() {})),
        leading: Hero(
          tag: 'teacher_${t.id}',
          child: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: t.subjectColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: t.profilePicUrl.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: t.profilePicUrl,
                    fit: BoxFit.cover,
                  )
                : Center(
                    child: Icon(Icons.person_rounded, color: t.subjectColor),
                  ),
            ),
          ),
        ),
        title: Text(
          t.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          t.subject,
          style: TextStyle(
            fontSize: 12,
            color: t.subjectColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              'Rs ${t.salary.toStringAsFixed(0)}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const Text(
              'Monthly',
              style: TextStyle(fontSize: 10, color: Colors.grey),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: (index * 50).ms).slideX(begin: 0.1);
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.school_outlined, 
            size: 64, 
            color: Colors.grey.withOpacity(0.5)
          ),
          const SizedBox(height: 16),
          const Text(
            'No faculty members', 
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Ready to hire your first teacher?', 
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    ).animate().fadeIn();
  }
}
