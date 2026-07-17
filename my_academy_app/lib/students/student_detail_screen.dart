import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:convert';
import 'dart:io' as io;
import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/student_model.dart';
import '../services/database_service.dart';
import '../services/print_service.dart';
import '../theme/app_theme.dart';
import 'edit_student_screen.dart';
import '../utils/whatsapp_helper.dart';

class StudentDetailScreen extends StatefulWidget {
  final StudentModel student;

  const StudentDetailScreen({super.key, required this.student});

  @override
  State<StudentDetailScreen> createState() => _StudentDetailScreenState();
}

class _StudentDetailScreenState extends State<StudentDetailScreen> {
  late StudentModel student;
  bool _isPrinting = false;

  @override
  void initState() {
    super.initState();
    student = widget.student;
  }

  Widget _buildAvatarImage(String url) {
    if (url.isEmpty) {
      return Container(
        color: Colors.white.withValues(alpha: 0.2),
        child: const Icon(Icons.person, size: 60, color: Colors.white),
      );
    }
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        placeholder: (_, __) => const Center(
          child: SizedBox(
            width: 30,
            height: 30,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
        errorWidget: (_, __, ___) => Container(
          color: Colors.white.withValues(alpha: 0.2),
          child: const Icon(Icons.person, size: 60, color: Colors.white),
        ),
      );
    }
    if (url.startsWith('data:image') || (!url.contains('/') && !url.contains('\\') && url.length > 100)) {
      try {
        final base64Str = url.contains(',') ? url.split(',').last : url;
        final bytes = base64Decode(base64Str.trim());
        return Image.memory(
          bytes,
          fit: BoxFit.cover,
        );
      } catch (e) {
        // fallback
      }
    }
    if (url.startsWith('blob:')) {
      return Image.network(url, fit: BoxFit.cover);
    }
    if (!kIsWeb) {
      try {
        return Image.file(
          io.File(url),
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              color: Colors.white.withValues(alpha: 0.2),
              child: const Icon(Icons.person, size: 60, color: Colors.white),
            );
          },
        );
      } catch (e) {
        // fallback
      }
    }
    return Container(
      color: Colors.white.withValues(alpha: 0.2),
      child: const Icon(Icons.person, size: 60, color: Colors.white),
    );
  }

  Widget _buildLargeAvatarImage(String url) {
    if (url.isEmpty) {
      return Container(
        color: Colors.black12,
        child: const Icon(Icons.person, size: 100, color: Colors.grey),
      );
    }
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.contain,
        placeholder: (_, __) => const Center(
          child: CircularProgressIndicator(),
        ),
        errorWidget: (_, __, ___) => Container(
          color: Colors.black12,
          child: const Icon(Icons.person, size: 100, color: Colors.grey),
        ),
      );
    }
    if (url.startsWith('data:image') || (!url.contains('/') && !url.contains('\\') && url.length > 100)) {
      try {
        final base64Str = url.contains(',') ? url.split(',').last : url;
        final bytes = base64Decode(base64Str.trim());
        return Image.memory(
          bytes,
          fit: BoxFit.contain,
        );
      } catch (e) {
        // fallback
      }
    }
    if (url.startsWith('blob:')) {
      return Image.network(url, fit: BoxFit.contain);
    }
    if (!kIsWeb) {
      try {
        return Image.file(
          io.File(url),
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              color: Colors.black12,
              child: const Icon(Icons.person, size: 100, color: Colors.grey),
            );
          },
        );
      } catch (e) {
        // fallback
      }
    }
    return Container(
      color: Colors.black12,
      child: const Icon(Icons.person, size: 100, color: Colors.grey),
    );
  }

  void _showLargeProfilePicture(BuildContext context) {
    if (student.profilePicUrl.isEmpty) return;
    
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(24),
          child: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: InteractiveViewer(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  constraints: const BoxConstraints(
                    maxWidth: 350,
                    maxHeight: 350,
                  ),
                  color: Colors.black,
                  child: _buildLargeAvatarImage(student.profilePicUrl),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _editStudent() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EditStudentScreen(student: student)),
    );
    if (result == true) {
      // Refresh student data from Firestore (cloud) first
      final updatedFromCloud = await DatabaseService.getStudentById(student.id);
      if (updatedFromCloud != null) {
        setState(() => student = updatedFromCloud);
      } else {
        // Fallback to local Hive
        final all = DatabaseService.getAllStudentsLocal();
        final updated = all.firstWhere((s) => s.id == student.id, orElse: () => student);
        setState(() => student = updated);
      }
    }
  }

  void _deleteStudent() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Move to Recycle Bin'),
        content: Text('Are you sure you want to move ${student.name} to the Recycle Bin?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Move'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await DatabaseService.recycleStudent(student);
      if (mounted) Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    double totalFee = student.biologyFee +
        student.physicsFee +
        student.chemistryFee +
        student.englishFee +
        student.mathFee;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          _buildAppBar(context, isDark),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStatsRow(totalFee),
                  const SizedBox(height: 32),
                  _buildSectionTitle(context, 'Class Information'),
                  const SizedBox(height: 16),
                  _buildClassInfoCard(isDark),
                  const SizedBox(height: 32),
                  _buildSectionTitle(context, 'Academic Courses'),
                  const SizedBox(height: 16),
                  _buildSubjectGrid(),
                  const SizedBox(height: 32),
                  _buildSectionTitle(context, 'Personal Information'),
                  const SizedBox(height: 16),
                  _buildPersonalInfoCard(isDark),
                  const SizedBox(height: 40),
                  _buildActionButtons(context),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, bool isDark) {
    return SliverAppBar(
      expandedHeight: 250,
      pinned: true,
      backgroundColor: AppTheme.primaryBlue,
      actions: [
        _isPrinting
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                ),
              )
            : IconButton(
                icon: const Icon(Icons.print_rounded, color: Colors.white),
                tooltip: 'Print Record',
                onPressed: () async {
                  setState(() => _isPrinting = true);
                  try {
                    await PrintService.printStudentReport(student);
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Print failed: $e'), backgroundColor: Colors.red),
                      );
                    }
                  } finally {
                    if (mounted) {
                      setState(() => _isPrinting = false);
                    }
                  }
                },
              ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppTheme.primaryBlue,
                    AppTheme.primaryBlue.withValues(alpha: 0.8),
                  ],
                ),
              ),
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 40),
                GestureDetector(
                  onTap: () => _showLargeProfilePicture(context),
                  child: Hero(
                    tag: 'student_${student.id}',
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(50),
                        child: _buildAvatarImage(student.profilePicUrl),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  student.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${student.classType} · ${student.grade} · ${student.subject}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildStatsRow(double totalFee) {
    return Row(
      children: [
        Expanded(child: _buildStatCard('Total Fee', 'Rs ${totalFee.toStringAsFixed(0)}', AppTheme.primaryBlue)),
        const SizedBox(width: 12),
        Expanded(child: _buildStatCard('Paid', 'Rs ${student.feeSubmitted.toStringAsFixed(0)}', Colors.green)),
        const SizedBox(width: 12),
        Expanded(child: _buildStatCard('Due', 'Rs ${student.feeRemaining.toStringAsFixed(0)}', Colors.red)),
      ],
    ).animate().fadeIn(delay: 200.ms);
  }

  Widget _buildStatCard(String label, String value, Color color) {
    return Card(
      elevation: 0,
      color: color.withValues(alpha: 0.05),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: color.withValues(alpha: 0.1)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: const TextStyle(fontSize: 10, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClassInfoCard(bool isDark) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildInfoRow(Icons.category_rounded, 'Class Type', student.classType),
            const Divider(),
            _buildInfoRow(Icons.school_rounded, 'Grade / Year', student.grade),
            const Divider(),
            _buildInfoRow(Icons.book_rounded, 'Subject', student.subject),
            const Divider(),
            _buildInfoRow(Icons.access_time_rounded, 'Schedule', student.schedule),
          ],
        ),
      ),
    ).animate().fadeIn(delay: 300.ms);
  }

  Widget _buildSubjectGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 2,
      children: [
        _buildSubjectItem('Biology', student.biologyFee, Icons.biotech_rounded, Colors.green),
        _buildSubjectItem('Physics', student.physicsFee, Icons.science_rounded, Colors.blue),
        _buildSubjectItem('Chemistry', student.chemistryFee, Icons.colorize_rounded, Colors.orange),
        _buildSubjectItem('English', student.englishFee, Icons.menu_book_rounded, Colors.purple),
        _buildSubjectItem('Math', student.mathFee, Icons.calculate_rounded, const Color(0xFF00897B)),
      ],
    );
  }

  Widget _buildSubjectItem(String subject, double fee, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(subject, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  Text('Rs ${fee.toStringAsFixed(0)}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildPersonalInfoCard(bool isDark) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildInfoRow(Icons.person_outline_rounded, 'Father Name', student.fatherName),
            const Divider(),
            InkWell(
              onTap: () => WhatsAppHelper.openWhatsApp(context, student.phone),
              borderRadius: BorderRadius.circular(8),
              child: Row(
                children: [
                  Expanded(
                    child: _buildInfoRow(Icons.phone_android_rounded, 'Phone (Tap to Chat)', student.phone),
                  ),
                  const Icon(Icons.send_rounded, color: Color(0xFF25D366), size: 22),
                  const SizedBox(width: 8),
                ],
              ),
            ),
            const Divider(),
            _buildInfoRow(Icons.email_outlined, 'Email', student.email.isEmpty ? 'N/A' : student.email),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppTheme.primaryBlue),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildActionButtons(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _editStudent,
            icon: const Icon(Icons.edit_rounded),
            label: const Text('EDIT PROFILE'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _deleteStudent,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              foregroundColor: Colors.red,
              side: const BorderSide(color: Colors.red),
            ),
            icon: const Icon(Icons.delete_outline_rounded),
            label: const Text('REMOVE'),
          ),
        ),
      ],
    );
  }
}