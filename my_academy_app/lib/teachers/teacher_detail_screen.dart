import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/teacher_model.dart';
import '../services/database_service.dart';
import '../theme/app_theme.dart';
import 'edit_teacher_screen.dart';

class TeacherDetailScreen extends StatefulWidget {
  final TeacherModel teacher;
  const TeacherDetailScreen({super.key, required this.teacher});

  @override
  State<TeacherDetailScreen> createState() => _TeacherDetailScreenState();
}

class _TeacherDetailScreenState extends State<TeacherDetailScreen> {
  bool _isDeleting = false;

  void _showDeleteDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Terminate Contract'),
        content: Text('Are you sure you want to remove ${widget.teacher.name} from faculty?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () { Navigator.pop(ctx); _delete(); },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  Future<void> _delete() async {
    setState(() => _isDeleting = true);
    try {
      if (widget.teacher.profilePicUrl.isNotEmpty) await DatabaseService.deleteImage(widget.teacher.profilePicUrl);
      await DatabaseService.deleteTeacher(widget.teacher.id);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.teacher;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              _buildAppBar(t),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSalaryCard(t),
                      const SizedBox(height: 32),
                      _buildSectionTitle(context, 'Faculty Information'),
                      const SizedBox(height: 16),
                      _buildInfoCard(t, isDark),
                      const SizedBox(height: 40),
                      _buildActionButtons(context, t),
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (_isDeleting) Container(color: Colors.black.withOpacity(0.1), child: const Center(child: CircularProgressIndicator())),
        ],
      ),
    );
  }

  Widget _buildAppBar(TeacherModel t) {
    return SliverAppBar(
      expandedHeight: 250,
      pinned: true,
      backgroundColor: t.subjectColor,
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [t.subjectColor, t.subjectColor.withOpacity(0.8)],
                ),
              ),
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 40),
                Hero(
                  tag: 'teacher_${t.id}',
                  child: Container(
                    width: 100, height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10)],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(50),
                      child: t.profilePicUrl.isNotEmpty
                        ? CachedNetworkImage(imageUrl: t.profilePicUrl, fit: BoxFit.cover)
                        : Container(color: Colors.white.withOpacity(0.2), child: const Icon(Icons.person, size: 60, color: Colors.white)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(t.name, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                Text(t.subject.toUpperCase(), style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 2)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSalaryCard(TeacherModel t) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: t.subjectColor.withOpacity(0.1), borderRadius: BorderRadius.circular(16)),
              child: Icon(Icons.payments_rounded, color: t.subjectColor, size: 30),
            ),
            const SizedBox(width: 20),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Monthly Payroll', style: TextStyle(fontSize: 12, color: Colors.grey)),
                Text('Rs ${t.salary.toStringAsFixed(0)}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: 200.ms);
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold));
  }

  Widget _buildInfoCard(TeacherModel t, bool isDark) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _infoTile(Icons.phone_android_rounded, 'Contact Number', t.phone),
            const Divider(),
            _infoTile(Icons.email_outlined, 'Email Address', t.email.isEmpty ? 'N/A' : t.email),
            const Divider(),
            _infoTile(Icons.school_rounded, 'Primary Subject', t.subject),
          ],
        ),
      ),
    );
  }

  Widget _infoTile(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.primaryBlue, size: 20),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
              Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, TeacherModel t) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () async {
              final r = await Navigator.push(context, MaterialPageRoute(builder: (_) => EditTeacherScreen(teacher: t)));
              if (r == true && context.mounted) Navigator.pop(context, true);
            },
            icon: const Icon(Icons.edit_rounded),
            label: const Text('EDIT PROFILE'),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _showDeleteDialog,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.delete_sweep_rounded),
            label: const Text('REMOVE'),
          ),
        ),
      ],
    );
  }
}
