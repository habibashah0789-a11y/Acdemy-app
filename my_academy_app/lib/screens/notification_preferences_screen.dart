import 'package:flutter/material.dart';

class NotificationPreferencesScreen extends StatelessWidget {
  const NotificationPreferencesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notification Preferences')),
      body: ListView(
        children: const [
          SwitchListTile(
            value: true,
            onChanged: null,
            title: Text('Student registration alerts'),
            subtitle: Text('Receive in-app alerts for new student registrations'),
          ),
          SwitchListTile(
            value: true,
            onChanged: null,
            title: Text('Push notifications'),
            subtitle: Text('Send push notifications to authorized users'),
          ),
        ],
      ),
    );
  }
}
