import 'package:flutter/material.dart';

import 'fee_settings_screen.dart';
//import 'subject_management_screen.dart';
//import 'teacher_management_screen.dart';
import 'backup_restore_screen.dart';
import 'security_screen.dart';
import 'appearance_screen.dart';
//import 'about_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Settings"),
      ),
      body: ListView(
        children: [
          /*_tile(
            context,
            Icons.business,
            "Academy Profile",
            const AcademyProfileScreen(),
          ),*/
          _tile(
            context,
            Icons.currency_rupee,
            "Fee Settings",
            const FeeSettingsScreen(),
          ),
          /*_tile(
            context,
            Icons.book,
            "Subject Management",
            const SubjectManagementScreen(),
          ),*/
         /* _tile(
            context,
            Icons.people,
            "Teacher Management",
            const TeacherManagementScreen(),
          ),*/
          _tile(
            context,
            Icons.backup,
            "Backup & Restore",
            const BackupRestoreScreen(),
          ),
          _tile(
            context,
            Icons.security,
            "Security",
            const SecurityScreen(),
          ),
          _tile(
            context,
            Icons.palette,
            "Appearance",
            const AppearanceScreen(),
          ),
         /* _tile(
            context,
            Icons.info,
            "About",
            const AboutScreen(),
          ),*/
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