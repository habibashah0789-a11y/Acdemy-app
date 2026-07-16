import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/notification_model.dart';
import '../services/notification_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late final Stream<List<NotificationModel>> _stream;

  @override
  void initState() {
    super.initState();
    _stream = NotificationService.notificationsStream();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'mark_all') {
                await NotificationService.markAllAsRead();
              } else if (value == 'clear_all') {
                await NotificationService.clearAllNotifications();
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'mark_all', child: Text('Mark all as read')),
              PopupMenuItem(value: 'clear_all', child: Text('Clear all')),
            ],
          ),
        ],
      ),
      body: StreamBuilder<List<NotificationModel>>(
        stream: _stream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snapshot.data ?? NotificationService.getCachedNotifications();
          if (items.isEmpty) {
            return const Center(child: Text('No notifications yet'));
          }
          return ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final item = items[index];
              return Dismissible(
                key: ValueKey(item.id),
                background: Container(color: Colors.red.withValues(alpha: 0.2)),
                onDismissed: (_) async => NotificationService.deleteNotification(item.id),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: item.isRead ? Colors.grey.shade200 : Colors.blue.shade50,
                    child: Icon(
                      item.notificationType == 'student_registered' ? Icons.person_add_alt_1 : Icons.notifications_active_outlined,
                      color: item.isRead ? Colors.grey : Colors.blue,
                    ),
                  ),
                  title: Row(
                    children: [
                      Expanded(child: Text(item.title, style: const TextStyle(fontWeight: FontWeight.bold))),
                      if (!item.isRead)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                        ),
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(item.message),
                      const SizedBox(height: 6),
                      Text(DateFormat('MMM dd, yyyy • hh:mm a').format(item.timestamp), style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) async {
                      if (value == 'read') {
                        await NotificationService.markAsRead(item.id);
                      } else if (value == 'delete') {
                        await NotificationService.deleteNotification(item.id);
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'read', child: Text('Mark as read')),
                      PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ],
                  ),
                  onTap: () async {
                    if (!item.isRead) {
                      await NotificationService.markAsRead(item.id);
                    }
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
