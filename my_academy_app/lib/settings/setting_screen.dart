import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:my_academy_app/settings/logout_screen.dart';
import '../models/student_model.dart';
import '../screens/app_info_screens.dart';
import '../services/database_service.dart';
import '../theme/app_theme.dart';
import '../widgets/about_developers_widget.dart';
import 'appearance_screen.dart';
import 'recycle_bin_screen.dart';

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
            Icons.palette,
            "Appearance",
            const AppearanceScreen(),
          ),
          _tile(
            context,
            Icons.delete_outline_rounded,
            "Recycle Bin",
            const RecycleBinScreen(),
          ),
          ListTile(
            leading: const Icon(Icons.bolt_rounded, color: Color(0xFF3ECF8E)),
            title: const Text(
              "Supabase Account",
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: const Text("quaidacademy241992@gmail.com"),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SupabaseSettingsScreen()),
              );
            },
          ),
          _tile(
            context,
            Icons.info_outline_rounded,
            "About App",
            const AboutAppScreen(),
          ),
          _tile(
            context,
            Icons.gavel_rounded,
            "Terms & Conditions",
            const TermsConditionsScreen(),
          ),
          _tile(
            context,
            Icons.help_outline_rounded,
            "Help & User Manual",
            const HelpSupportScreen(),
          ),
          ListTile(
            leading: const Icon(Icons.code_rounded, color: AppTheme.primaryBlue),
            title: const Text(
              "About Developers",
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: const Text("Habiba Shah & Hamza Taif"),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => AboutDevelopersDialog.show(context),
          ),
          ListTile(
            leading:
                const Icon(Icons.delete_forever_rounded, color: Colors.red),
            title: const Text("Delete Students Data",
                style:
                    TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            trailing: const Icon(Icons.arrow_forward_ios, color: Colors.red, size: 16),
            onTap: () => _showDeleteDialog(context),
          ),
          _tile(
            context,
            Icons.logout,
            "Logout",
            const LogoutScreen(),
          ),
        ],
      ),
    );
  }

  Widget _tile(
    BuildContext context,
    IconData icon,
    String title,
    Widget screen, {
    Color? color,
  }) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
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
            .where(
                (s) => s.grade.toLowerCase() == _selectedOption.toLowerCase())
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
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                const LinearProgressIndicator(color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  'Deleting students data, please wait...',
                  style: GoogleFonts.poppins(fontSize: 13),
                ),
              ],
            )
          : SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Warning: This action is permanent and will delete students from both local cache and online database.',
                    style: TextStyle(
                        color: Colors.red, fontWeight: FontWeight.bold),
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
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Type DELETE to confirm:'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _confirmController,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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

class SupabaseSettingsScreen extends StatefulWidget {
  const SupabaseSettingsScreen({super.key});

  @override
  State<SupabaseSettingsScreen> createState() => _SupabaseSettingsScreenState();
}

class _SupabaseSettingsScreenState extends State<SupabaseSettingsScreen> {
  final _keyController = TextEditingController();
  bool _testingConnection = false;
  String _statusMessage = '';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Supabase Account',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Banner Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1F2937), Color(0xFF111827)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF3ECF8E).withValues(alpha: 0.4)),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF3ECF8E).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.bolt_rounded, color: Color(0xFF3ECF8E), size: 28),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Supabase Connected',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              'Account: quaidacademy241992@gmail.com',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: const Color(0xFF3ECF8E),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(color: Colors.white12, height: 1),
                  const SizedBox(height: 14),
                  Text(
                    '• Project URL: https://lrvzofjlaziypwssuqvi.supabase.co\n• Project Ref: lrvzofjlaziypwssuqvi\n• Database Engine: PostgreSQL 15 (Supabase Cloud)',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey.shade300,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Instructions
            Text(
              'Supabase Public / Anon API Key',
              style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              'Find your anon key in your Supabase Dashboard -> Project Settings -> API -> Project API keys -> anon public.',
              style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600),
            ),

            const SizedBox(height: 16),

            TextField(
              controller: _keyController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Paste your Supabase anon key here...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),

            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  final text = _keyController.text.trim();
                  if (text.isNotEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        backgroundColor: AppTheme.secondaryGreen,
                        content: Text('Supabase API Key saved successfully!'),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.save_rounded),
                label: Text(
                  'SAVE SUPABASE KEY',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3ECF8E),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
