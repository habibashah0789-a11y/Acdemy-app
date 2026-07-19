import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hive/hive.dart';
import '../models/notification_model.dart';
import '../models/student_model.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // If you're going to use other Firebase services in the background, such as Firestore,
  // make sure you call `Firebase.initializeApp()` before using them.
  debugPrint("Handling a background message: ${message.messageId}");
}

class NotificationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'notifications';
  static const String _hiveBoxName = 'notifications';
  static late Box<Map> _notificationBox;
  static StreamSubscription<QuerySnapshot>? _firestoreSubscription;
  static final StreamController<List<NotificationModel>> _controller =
      StreamController<List<NotificationModel>>.broadcast();
  static bool _initialized = false;

  static final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    if (_initialized) return;
    _notificationBox = await Hive.openBox<Map>(_hiveBoxName);
    
    // Initialize Local Notifications
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings();
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );
    await _localNotificationsPlugin.initialize(initializationSettings);

    _initialized = true;
    _syncFromFirestoreToHive();
    _listenToFirestore();
  }

  static Future<void> initializePushNotifications() async {
    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      
      // Subscribe to topic
      await messaging.subscribeToTopic('academy_users');

      // Set background handler
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // Listen for foreground messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('Got a message whilst in the foreground!');
        debugPrint('Message data: ${message.data}');

        if (message.notification != null) {
          debugPrint('Message also contained a notification: ${message.notification}');
          _showLocalNotification(
            title: message.notification?.title ?? 'Notification',
            body: message.notification?.body ?? '',
          );
        }
      });
    } catch (_) {}
  }

  static Future<void> _showLocalNotification({
    required String title,
    required String body,
  }) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'academy_channel',
      'Academy Notifications',
      importance: Importance.max,
      priority: Priority.high,
    );
    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);
    await _localNotificationsPlugin.show(
      DateTime.now().millisecond,
      title,
      body,
      platformChannelSpecifics,
    );
  }

  static Stream<List<NotificationModel>> notificationsStream()  {
    if (!_initialized) {
         init();
    }
    return _controller.stream;
  }

  static Future<void> _syncFromFirestoreToHive() async {
    try {
      final snapshot = await _firestore.collection(_collection).orderBy('timestamp', descending: true).get();
      final notifications = snapshot.docs
          .map((doc) {
            final rawData = doc.data() as Map<String, dynamic>? ?? {};
            final map = {...rawData, 'id': doc.id};
            return NotificationModel.fromMap(map, doc.id);
          })
          .toList();
      await _notificationBox.clear();
      for (final notification in notifications) {
        await _notificationBox.put(notification.id, notification.toHiveMap());
      }
      _controller.add(_sortedNotifications(_fromHive()));
    } catch (_) {}
  }

  static void _listenToFirestore() {
    _firestoreSubscription?.cancel();

    _firestoreSubscription = _firestore
        .collection(_collection)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .listen(
      (snapshot) {
        final notifications = snapshot.docs
            .map((doc) {
              final rawData = doc.data() as Map<String, dynamic>? ?? {};
              final map = {...rawData, 'id': doc.id};
              return NotificationModel.fromMap(map, doc.id);
            })
            .toList();

        _persistHiveBatch(notifications);
        _controller.add(_sortedNotifications(notifications));
      },
      onError: (e) {
        debugPrint("Notification Firestore Error: $e");
      },
    );
  }

  static Future<void> _persistHiveBatch(List<NotificationModel> notifications) async {
    await _notificationBox.clear();
    for (final notification in notifications) {
      await _notificationBox.put(notification.id, notification.toHiveMap());
    }
  }

  static List<NotificationModel> _fromHive() {
    return _notificationBox.values
        .map((value) => NotificationModel.fromHiveMap(Map<String, dynamic>.from(value)))
        .toList();
  }

  static List<NotificationModel> _sortedNotifications(List<NotificationModel> notifications) {
    notifications.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return notifications;
  }

  static List<NotificationModel> getCachedNotifications() {
    if (!_initialized) {
      return [];
    }
    return _sortedNotifications(_fromHive());
  }

  static Future<int> unreadCount() async {
    if (!_initialized) {
      await init();
    }
    return _fromHive().where((n) => !n.isRead).length;
  }

  static Future<void> createStudentRegistrationNotification({
    required StudentModel student,
    String? registeredBy,
  }) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    final notification = buildStudentRegistrationNotification(
      student: student,
      registeredBy: registeredBy ?? currentUser?.email ?? 'Administrator',
    );

    final exists = await _firestore.collection(_collection).where('studentId', isEqualTo: student.id).where('notificationType', isEqualTo: 'student_registered').get();
    if (exists.docs.isNotEmpty) {
      return;
    }

    await _saveNotification(notification, emitLocal: true);
    _showLocalNotification(title: notification.title, body: notification.message);
  }

  static NotificationModel buildStudentRegistrationNotification({
    required StudentModel student,
    required String registeredBy,
  }) {
    final fullName = '${student.firstName} ${student.lastName}'.trim();
    return NotificationModel(
      id: 'reg_${student.id}_${DateTime.now().millisecondsSinceEpoch}',
      title: 'New Student Registered',
      message: '$fullName has been registered in ${student.classType} ${student.grade} (${student.subject}).',
      studentName: fullName,
      className: student.classType,
      subject: student.subject,
      registeredBy: registeredBy,
      timestamp: DateTime.now(),
      notificationType: 'student_registered',
      isRead: false,
      studentId: student.id,
    );
  }

  static Future<void> createFeePaymentNotification({
    required StudentModel student,
    required double amount,
    bool isSecondInstallment = false,
  }) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    final userName = currentUser?.email ?? 'Administrator';
    final fullName = student.name;

    final title = isSecondInstallment ? 'Second Installment Received' : 'Fee Payment Received';
    final message = isSecondInstallment 
        ? '$fullName has paid Rs ${amount.toStringAsFixed(0)} as their second installment.'
        : '$fullName has paid a fee of Rs ${amount.toStringAsFixed(0)}.';

    final notification = NotificationModel(
      id: 'pay_${student.id}_${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      message: message,
      studentName: fullName,
      className: student.classType,
      subject: student.subject,
      registeredBy: userName,
      timestamp: DateTime.now(),
      notificationType: isSecondInstallment ? 'second_installment' : 'fee_payment',
      isRead: false,
      studentId: student.id,
    );

    await _saveNotification(notification, emitLocal: true);
    _showLocalNotification(title: notification.title, body: notification.message);
  }

  static Future<void> _saveNotification(NotificationModel notification, {required bool emitLocal}) async {
    if (!_initialized) {
      await init();
    }
    final exists = _notificationBox.values.any((value) => value['id'] == notification.id);
    if (!exists) {
      try {
        await _firestore.collection(_collection).doc(notification.id).set(notification.toMap());
      } catch (_) {}
      await _notificationBox.put(notification.id, notification.toHiveMap());
      if (emitLocal) {
        _controller.add(_sortedNotifications([..._fromHive()]));
      }
    }
  }

  static Future<void> markAsRead(String notificationId) async {
    if (!_initialized) {
      await init();
    }
    final docRef = _firestore.collection(_collection).doc(notificationId);
    await docRef.update({'isRead': true});
    final existing = _notificationBox.get(notificationId);
    if (existing != null) {
      final updated = Map<String, dynamic>.from(existing)
        ..['isRead'] = true;
      await _notificationBox.put(notificationId, updated);
    }
    _controller.add(_sortedNotifications([..._fromHive()]));
  }

  static Future<void> markAllAsRead() async {
    if (!_initialized) {
      await init();
    }
    final batch = _firestore.batch();
    final notifications = _fromHive();
    for (final notification in notifications.where((n) => !n.isRead)) {
      batch.update(_firestore.collection(_collection).doc(notification.id), {'isRead': true});
    }
    await batch.commit();
    for (final notification in notifications.where((n) => !n.isRead)) {
      final existing = _notificationBox.get(notification.id);
      if (existing != null) {
        final updated = Map<String, dynamic>.from(existing)..['isRead'] = true;
        await _notificationBox.put(notification.id, updated);
      }
    }
    _controller.add(_sortedNotifications([..._fromHive()]));
  }

  static Future<void> deleteNotification(String notificationId) async {
    if (!_initialized) {
      await init();
    }
    await _firestore.collection(_collection).doc(notificationId).delete();
    await _notificationBox.delete(notificationId);
    _controller.add(_sortedNotifications([..._fromHive()]));
  }

  static Future<void> clearAllNotifications() async {
    if (!_initialized) {
      await init();
    }
    final snapshot = await _firestore.collection(_collection).get();
    final batch = _firestore.batch();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
    await _notificationBox.clear();
    _controller.add([]);
  }

  static Future<void> dispose() async {
    await _firestoreSubscription?.cancel();
    await _controller.close();
    _initialized = false;
  }
}

