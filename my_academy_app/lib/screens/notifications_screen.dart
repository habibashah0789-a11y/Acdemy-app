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
        initialData: NotificationService.getCachedNotifications(),
        builder: (context, snapshot) {
          final items = snapshot.data ?? [];
          if (items.isEmpty && snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (items.isEmpty) {
            return const Center(child: Text('No notifications yet'));
          }
          return ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final item = items[index];
              // Colors & Icons based on type
              IconData leadingIcon = Icons.notifications_active_outlined;
              Color activeColor = Colors.blue;
              Color bgActiveColor = Colors.blue.shade50;

              if (item.notificationType == 'student_registered') {
                leadingIcon = Icons.person_add_alt_1;
                activeColor = Colors.blue;
                bgActiveColor = Colors.blue.shade50;
              } else if (item.notificationType == 'fee_payment') {
                leadingIcon = Icons.payments_rounded;
                activeColor = Colors.green;
                bgActiveColor = Colors.green.shade50;
              } else if (item.notificationType == 'second_installment') {
                leadingIcon = Icons.account_balance_wallet_rounded;
                activeColor = Colors.purple;
                bgActiveColor = Colors.purple.shade50;
              }

              return Dismissible(
                key: ValueKey(item.id),
                background: Container(color: Colors.red.withValues(alpha: 0.2)),
                onDismissed: (_) async => NotificationService.deleteNotification(item.id),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: item.isRead ? Colors.grey.shade200 : bgActiveColor,
                    child: Icon(
                      leadingIcon,
                      color: item.isRead ? Colors.grey : activeColor,
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
