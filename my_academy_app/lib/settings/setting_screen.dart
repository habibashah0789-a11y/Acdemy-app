import 'package:flutter/material.dart';
import 'package:my_academy_app/settings/logout_screen.dart';
import '../models/student_model.dart';
import '../services/database_service.dart';
import 'backup_restore_screen.dart';
import 'appearance_screen.dart';
import 'recycle_bin_screen.dart';
import '../screens/fee_reminders_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  void _showDeleteDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const DeleteStudentsDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Settings"),
      ),
      body: ListView(
        children: [
          _tile(
            context,
            Icons.delete_outline_rounded,
            "Recycle Bin",
            const RecycleBinScreen(),
          ),
          _tile(
            context,
            Icons.logout,
            "Logout",
            const LogoutScreen(),
          ),
          _tile(
            context,
            Icons.backup,
            "Backup & Restore",
            const BackupRestoreScreen(),
          ),
          _tile(
            context,
            Icons.palette,
            "Appearance",
            const AppearanceScreen(),
          ),
          ListTile(
            leading: const Icon(Icons.message_rounded, color: Color(0xFF25D366)),
            title: const Text("Fee Reminders", style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: const Text("Send WhatsApp reminders & print defaulters", style: TextStyle(fontSize: 12)),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const FeeRemindersScreen()),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.delete_forever_rounded, color: Colors.red),
            title: const Text("Delete Students Data", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            trailing: const Icon(Icons.arrow_forward_ios, color: Colors.red),
            onTap: () => _showDeleteDialog(context),
          ),
        ],
      ),
    );
  }

  Widget _tile(
    BuildContext context,
    IconData icon,
    String title,
    Widget screen,
  ) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      trailing: const Icon(Icons.arrow_forward_ios),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => screen),
        );
      },
    );
  }
}

class DeleteStudentsDialog extends StatefulWidget {
  const DeleteStudentsDialog({super.key});

  @override
  State<DeleteStudentsDialog> createState() => _DeleteStudentsDialogState();
}

class _DeleteStudentsDialogState extends State<DeleteStudentsDialog> {
  String _selectedOption = 'Ninth';
  final _confirmController = TextEditingController();
  bool _isDeleting = false;

  final List<Map<String, String>> _options = [
    {'value': 'Ninth', 'label': 'Ninth Class (9th)'},
    {'value': 'Tenth', 'label': 'Tenth Class (10th)'},
    {'value': 'First Year', 'label': 'First Year (11th/1st Year)'},
    {'value': 'Second Year', 'label': 'Second Year (12th/2nd Year)'},
    {'value': 'all', 'label': 'All Students'},
  ];

  @override
  void dispose() {
    _confirmController.dispose();
    super.dispose();
  }

  void _delete() async {
    final text = _confirmController.text.trim();
    if (text.toUpperCase() != 'DELETE') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please type DELETE to confirm.'),
          backgroundColor: Colors.red,



          
        ),
      );
      return;
    }

    setState(() => _isDeleting = true);

    try {
      List<StudentModel> allStudents = [];
      try {
        allStudents = await DatabaseService.getAllStudentsFromFirestore();
        await DatabaseService.syncFromFirestore();
      } catch (e) {
        allStudents = DatabaseService.getAllStudentsLocal();
      }
      List<StudentModel> targets = [];
      if (_selectedOption == 'all') {
        targets = allStudents;
      } else {
        targets = allStudents
            .where((s) => s.grade.toLowerCase() == _selectedOption.toLowerCase())
            .toList();
      }

      if (!mounted) return;
      if (targets.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No students found in the selected category.'),
          ),
        );
        Navigator.pop(context);
        return;
      }

      int deletedCount = 0;
      for (var s in targets) {
        await DatabaseService.deleteStudent(s.id);
        deletedCount++;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully deleted $deletedCount students.'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error during deletion: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Delete Students Data'),
      content: _isDeleting
          ? const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Deleting students, please wait...'),
              ],
            )
          : SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Warning: This action is permanent and will delete students from both local cache and online database.',
                    style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  const Text('Select which class/grade to delete:'),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: _selectedOption,
                    items: _options.map((opt) {
                      return DropdownMenuItem<String>(
                        value: opt['value'],
                        child: Text(
                          opt['label']!,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _selectedOption = val);
                      }
                    },
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Type DELETE to confirm:'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _confirmController,
                    decoration: const InputDecoration(
                      
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                ],
              ),
            ),
      actions: _isDeleting
          ? null
          : [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: _delete,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text('DELETE'),
              ),
            ],
    );
  }
}
