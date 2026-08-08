import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/notification_model.dart';
import '../services/notification_service.dart';

import '../screens/notification_settings_screen.dart';

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
          IconButton(
            icon: const Icon(Icons.settings_rounded),
            tooltip: 'Notification Settings',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NotificationSettingsScreen()),
              );
            },
          ),
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
      floatingActionButton: FloatingActionButton(
        heroTag: null,
        onPressed: _showCreateNotificationDialog,
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add_comment_rounded),
      ),
    );
  }

  Future<void> _showCreateNotificationDialog() async {
    final formKey = GlobalKey<FormState>();
    final titleController = TextEditingController();
    final messageController = TextEditingController();
    bool isPublishing = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Compose Announcement'),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: 'Title',
                        hintText: 'e.g. Academy Holiday',
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Please enter a title'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: messageController,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Message',
                        hintText: 'Enter announcement details...',
                        alignLabelWithHint: true,
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Please enter a message'
                          : null,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isPublishing ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isPublishing
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          setDialogState(() => isPublishing = true);

                          try {
                            final notification = NotificationModel(
                              id: 'broadcast_${DateTime.now().millisecondsSinceEpoch}',
                              title: titleController.text.trim(),
                              message: messageController.text.trim(),
                              studentName: 'All Students',
                              className: 'All',
                              subject: 'General',
                              registeredBy: FirebaseAuth.instance.currentUser?.email ?? 'Administrator',
                              timestamp: DateTime.now(),
                              notificationType: 'broadcast',
                              isRead: false,
                              studentId: '', // Empty means broadcast
                            );

                            await FirebaseFirestore.instance
                                .collection('notifications')
                                .doc(notification.id)
                                .set(notification.toMap());

                            await NotificationService.showLocalNotification(
                              channelId: 'academy_important_alerts',
                              title: '📢 ${titleController.text.trim()}',
                              body: messageController.text.trim(),
                              payload: '{"type": "announcement", "screen": "notifications"}',
                            );

                            if (context.mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Announcement published successfully!'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Failed to publish: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                            setDialogState(() => isPublishing = false);
                          }
                        },
                  child: isPublishing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Publish'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
