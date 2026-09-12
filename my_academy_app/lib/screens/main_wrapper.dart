import 'package:flutter/material.dart';
import '../dashboard/dashboard_screen.dart';
import '../screens/admin_finance_screen.dart';
import '../students/student_list_screen.dart';
import '../teachers/teacher_folder_screen.dart';
import '../theme/app_theme.dart';
import '../settings/setting_screen.dart';
import '../services/notification_service.dart';
import '../services/auth_service.dart';
import '../widgets/web_adaptive_layout.dart';

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
    const AdminFinanceScreen(),
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
  void dispose() {
    super.dispose();
  }

  static const List<WebNavItem> _navItems = [
    WebNavItem(
      icon: Icons.dashboard_outlined,
      activeIcon: Icons.dashboard_rounded,
      label: 'Dashboard',
    ),
    WebNavItem(
      icon: Icons.school_outlined,
      activeIcon: Icons.school_rounded,
      label: 'Students',
    ),
    WebNavItem(
      icon: Icons.supervisor_account_outlined,
      activeIcon: Icons.supervisor_account_rounded,
      label: 'Teachers',
    ),
    WebNavItem(
      icon: Icons.account_balance_wallet_outlined,
      activeIcon: Icons.account_balance_wallet_rounded,
      label: 'Finance',
    ),
    WebNavItem(
      icon: Icons.settings_outlined,
      activeIcon: Icons.settings_rounded,
      label: 'Settings',
    ),
  ];

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Logout'),
        content: const Text('Are you sure you want to log out of the Administration Portal?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await AuthService.signOut();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Logout', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WebAdaptiveLayout(
      currentIndex: _currentIndex,
      onIndexChanged: (index) {
        if (_currentIndex != index) {
          setState(() {
            _currentIndex = index;
          });
        }
      },
      items: _navItems,
      roleTitle: 'Administration',
      userName: 'Administrator',
      onLogout: () => _confirmLogout(context),
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
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
