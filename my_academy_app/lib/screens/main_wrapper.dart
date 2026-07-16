import 'package:flutter/material.dart';
import '../dashboard/dashboard_screen.dart';
import '../students/student_list_screen.dart';
import '../teachers/teacher_folder_screen.dart';
import '../theme/app_theme.dart';
import '../settings/setting_screen.dart';
import '../services/notification_service.dart';

class MainWrapper extends StatefulWidget {
  const MainWrapper({super.key});

  @override
  State<MainWrapper> createState() => _MainWrapperState();
}

class _MainWrapperState extends State<MainWrapper> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const DashboardScreen(),
    const StudentListScreen(),
    const TeacherFolderScreen(),
    //const PlaceholderScreen(title: 'Fees Management', icon: Icons.payments_rounded),
    const SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    // Initialize NotificationService to sync and listen to Firestore notifications
    NotificationService.notificationsStream();
    // Request permissions and subscribe to the push notifications topic
    NotificationService.initializePushNotifications();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_rounded),
            activeIcon: Icon(Icons.dashboard_rounded),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.school_outlined),
            activeIcon: Icon(Icons.school_rounded),
            label: 'Students',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.supervisor_account_outlined),
            activeIcon: Icon(Icons.supervisor_account_rounded),
            label: 'Teachers',
          ),
          /*BottomNavigationBarItem(
            icon: Icon(Icons.payments_outlined),
            activeIcon: Icon(Icons.payments_rounded),
            label: 'Fees',
          ),*/
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            activeIcon: Icon(Icons.settings_rounded),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

class PlaceholderScreen extends StatelessWidget {
  final String title;
  final IconData icon;

  const PlaceholderScreen({super.key, required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 64, color: AppTheme.primaryBlue),
            ),
            const SizedBox(height: 24),
            Text(
              '$title Module',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Currently under development',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
