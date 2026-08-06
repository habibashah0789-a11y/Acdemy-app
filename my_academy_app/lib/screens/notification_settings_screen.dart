import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive/hive.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_card.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  bool _importantAlerts = true;
  bool _feeReminders = true;
  bool _attendanceUpdates = true;
  bool _generalNotifications = true;
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;

  static const String _boxName = 'notification_preferences';

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    try {
      final box = await Hive.openBox(_boxName);
      setState(() {
        _importantAlerts = box.get('importantAlerts', defaultValue: true);
        _feeReminders = box.get('feeReminders', defaultValue: true);
        _attendanceUpdates = box.get('attendanceUpdates', defaultValue: true);
        _generalNotifications = box.get('generalNotifications', defaultValue: true);
        _soundEnabled = box.get('soundEnabled', defaultValue: true);
        _vibrationEnabled = box.get('vibrationEnabled', defaultValue: true);
      });
    } catch (_) {}
  }

  Future<void> _savePreference(String key, bool value) async {
    try {
      final box = await Hive.openBox(_boxName);
      await box.put(key, value);
    } catch (_) {}
  }

  Future<void> _openPhoneSettings() async {
    try {
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        final uri = Uri.parse('package:my_academy_app');
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
        } else {
          await launchUrl(Uri.parse('android.settings.SETTINGS'));
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please open your device settings to adjust system notifications.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to open settings: $e')),
        );
      }
    }
  }

  Future<void> _sendTestNotification() async {
    await NotificationService.showLocalNotification(
      channelId: 'academy_important_alerts',
      title: 'Quaid Academy Test Notification 🔔',
      body: 'Push notifications, sound, and vibration are fully active!',
      payload: '{"type": "announcement", "screen": "notifications"}',
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Test notification sent! Check your notification panel.'),
          backgroundColor: AppTheme.secondaryGreen,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Notification Settings',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Banner Card
            CustomCard(
              padding: const EdgeInsets.all(20),
              backgroundColor: AppTheme.primaryBlue.withValues(alpha: 0.1),
              borderRadius: 20.0,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryBlue,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.notifications_active_rounded, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Academy Alerts System',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Customize real-time push notification preferences for your device.',
                          style: TextStyle(
                            color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            _buildSectionHeader('Notification Categories'),
            const SizedBox(height: 12),

            _buildSwitchTile(
              title: 'Important Academy Alerts',
              subtitle: 'Emergency notices, arrivals, and urgent announcements',
              icon: Icons.error_outline_rounded,
              iconColor: Colors.redAccent,
              value: _importantAlerts,
              onChanged: (val) {
                setState(() => _importantAlerts = val);
                _savePreference('importantAlerts', val);
              },
            ),

            _buildSwitchTile(
              title: 'Fee Payment Reminders',
              subtitle: 'Pending fee balance reminders & payment receipts',
              icon: Icons.payments_outlined,
              iconColor: Colors.green,
              value: _feeReminders,
              onChanged: (val) {
                setState(() => _feeReminders = val);
                _savePreference('feeReminders', val);
              },
            ),

            _buildSwitchTile(
              title: 'Attendance & Check-in Updates',
              subtitle: 'Student check-in, check-out, and absence alerts',
              icon: Icons.how_to_reg_rounded,
              iconColor: Colors.orange,
              value: _attendanceUpdates,
              onChanged: (val) {
                setState(() => _attendanceUpdates = val);
                _savePreference('attendanceUpdates', val);
              },
            ),

            _buildSwitchTile(
              title: 'General News & Timetables',
              subtitle: 'Exam dates, class schedules, and results',
              icon: Icons.campaign_rounded,
              iconColor: AppTheme.primaryBlue,
              value: _generalNotifications,
              onChanged: (val) {
                setState(() => _generalNotifications = val);
                _savePreference('generalNotifications', val);
              },
            ),

            const SizedBox(height: 24),

            _buildSectionHeader('Sound & Vibration'),
            const SizedBox(height: 12),

            _buildSwitchTile(
              title: 'Notification Sound',
              subtitle: 'Play sound when receiving push notifications',
              icon: Icons.volume_up_rounded,
              iconColor: Colors.purple,
              value: _soundEnabled,
              onChanged: (val) {
                setState(() => _soundEnabled = val);
                _savePreference('soundEnabled', val);
              },
            ),

            _buildSwitchTile(
              title: 'Haptic Vibration',
              subtitle: 'Vibrate device on incoming alerts',
              icon: Icons.vibration_rounded,
              iconColor: Colors.teal,
              value: _vibrationEnabled,
              onChanged: (val) {
                setState(() => _vibrationEnabled = val);
                _savePreference('vibrationEnabled', val);
              },
            ),

            const SizedBox(height: 32),

            // Action Buttons
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _sendTestNotification,
                icon: const Icon(Icons.send_rounded),
                label: const Text('Send Test Push Notification'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),

            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _openPhoneSettings,
                icon: const Icon(Icons.settings_suggest_rounded),
                label: const Text('Open Phone Notification Settings'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: GoogleFonts.poppins(
        fontWeight: FontWeight.bold,
        fontSize: 14,
        color: AppTheme.primaryBlue,
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
      ),
      child: SwitchListTile(
        secondary: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: iconColor, size: 22),
        ),
        title: Text(
          title,
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(fontSize: 11, color: Colors.grey),
        ),
        value: value,
        onChanged: onChanged,
        activeTrackColor: AppTheme.primaryBlue,
      ),
    );
  }
}
