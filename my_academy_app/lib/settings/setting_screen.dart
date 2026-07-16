import 'package:flutter/material.dart';
import 'package:my_academy_app/settings/logout_screen.dart';
import 'backup_restore_screen.dart';
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
