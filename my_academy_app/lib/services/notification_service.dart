import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive/hive.dart';

import '../models/notification_model.dart';
import '../models/student_model.dart';
import '../screens/fee_reminders_screen.dart';
import '../screens/notifications_screen.dart';
import '../settings/class_schedules_screen.dart';
import '../student_portal/student_dashboard_screen.dart';
import '../theme/app_theme.dart';

/// Top-level background message handler for FCM.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint("Handling a background message: ${message.messageId}");
}

class NotificationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static const String _collection = 'notifications';
  static const String _hiveBoxName = 'notifications';
  static const String _prefBoxName = 'notification_preferences';

  static late Box<Map> _notificationBox;
  static StreamSubscription<QuerySnapshot>? _firestoreSubscription;
  static StreamSubscription<User?>? _authSubscription;
  static final StreamController<List<NotificationModel>> _controller =
      StreamController<List<NotificationModel>>.broadcast();

  static bool _initialized = false;
  static GlobalKey<NavigatorState>? navigatorKey;

  // ── 1. Android Notification Channels ──────────────────────────────────

  static const AndroidNotificationChannel _importantAlertsChannel =
      AndroidNotificationChannel(
    'academy_important_alerts',
    'Academy Important Alerts',
    description: 'Emergency notices, arrivals, and urgent academy alerts',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
  );

  static const AndroidNotificationChannel _feeRemindersChannel =
      AndroidNotificationChannel(
    'fee_reminders',
    'Fee Reminders',
    description: 'Pending fee reminders and payment confirmations',
    importance: Importance.high,
    playSound: true,
    enableVibration: true,
  );

  static const AndroidNotificationChannel _attendanceUpdatesChannel =
      AndroidNotificationChannel(
    'attendance_updates',
    'Attendance Updates',
    description: 'Student check-in, check-out, absent, and late alerts',
    importance: Importance.high,
    playSound: true,
    enableVibration: true,
  );

  static const AndroidNotificationChannel _generalNotificationsChannel =
      AndroidNotificationChannel(
    'general_notifications',
    'General Notifications',
    description: 'News, results, timetable updates, and holiday notices',
    importance: Importance.defaultImportance,
    playSound: true,
  );

  // ── 2. Initialization ────────────────────────────────────────────────

  static Future<void> init({GlobalKey<NavigatorState>? key}) async {
    if (key != null) navigatorKey = key;
    if (_initialized) return;

    _notificationBox = await Hive.openBox<Map>(_hiveBoxName);

    // Local notifications initialization settings
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/launcher_icon');
    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );

    await _localNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        if (response.payload != null && response.payload!.isNotEmpty) {
          handleNotificationPayload(response.payload);
        }
      },
    );

    // Create Android Channels
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      final androidPlugin = _localNotificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        await androidPlugin.createNotificationChannel(_importantAlertsChannel);
        await androidPlugin.createNotificationChannel(_feeRemindersChannel);
        await androidPlugin.createNotificationChannel(_attendanceUpdatesChannel);
        await androidPlugin.createNotificationChannel(_generalNotificationsChannel);
      }
    }

    _initialized = true;
    _controller.add(_sortedNotifications(_fromHive()));

    // Listen for Auth changes
    _authSubscription?.cancel();
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) {
        _syncFromFirestoreToHive();
        _listenToFirestore();
        registerFcmToken(userId: user.uid, role: 'admin');
      } else {
        _cancelFirestoreSubscription();
      }
    });

    if (FirebaseAuth.instance.currentUser != null) {
      _syncFromFirestoreToHive();
      _listenToFirestore();
    }
  }

  // ── 3. Permission Prompt & FCM Setup ──────────────────────────────────

  static Future<void> requestPermissionWithRationale(BuildContext context) async {
    final prefBox = await Hive.openBox(_prefBoxName);
    final bool rationaleShown = prefBox.get('rationaleShown', defaultValue: false);

    if (!rationaleShown) {
      if (!context.mounted) return;
      final bool? userAccepted = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.notifications_active_rounded, color: AppTheme.primaryBlue),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Academy Notifications',
                  style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Text(
            'Allow notifications to receive attendance updates, fee reminders, announcements, results, and important academy alerts.',
            style: GoogleFonts.poppins(fontSize: 13, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Not Now', style: TextStyle(color: Colors.grey.shade600)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Allow Notifications'),
            ),
          ],
        ),
      );

      await prefBox.put('rationaleShown', true);
      if (userAccepted != true) return;
    }

    await initializePushNotifications();
  }

  static Future<void> initializePushNotifications() async {
    try {
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      debugPrint('[NotificationService] Permission status: ${settings.authorizationStatus}');

      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        debugPrint('[NotificationService] User denied notification permissions');
        return;
      }

      await _messaging.subscribeToTopic('academy_all');
      await _messaging.subscribeToTopic('students');
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // Handle Foreground Notifications
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
<<<<<<< HEAD
        debugPrint('[NotificationService] Foreground message received: ${message.notification?.title}');
        final notification = message.notification;
        final android = message.notification?.android;

        if (notification != null) {
          showLocalNotification(
            channelId: android?.channelId ?? 'academy_important_alerts',
            title: notification.title ?? 'Quaid Academy Alert',
            body: notification.body ?? '',
            payload: jsonEncode(message.data),
=======
        if (message.notification != null) {
          showLocalNotification(
            title: message.notification?.title ?? 'Notification',
            body: message.notification?.body ?? '',
>>>>>>> f3ea761015c75ae110b34ffdbd3ba32c332190b4
          );
        }
      });

      // Handle Background Tap Navigation
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('[NotificationService] Notification opened from background!');
        handleNotificationPayload(jsonEncode(message.data));
      });

      // Handle Terminated Tap Navigation
      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        debugPrint('[NotificationService] Terminated app launched from notification!');
        handleNotificationPayload(jsonEncode(initialMessage.data));
      }

      // Listen for FCM Token refreshes
      _messaging.onTokenRefresh.listen((newToken) {
        registerFcmToken(fcmToken: newToken);
      });

      await registerFcmToken();
    } catch (e) {
      debugPrint('[NotificationService] Push init error: $e');
    }
  }

<<<<<<< HEAD
  // ── 4. FCM Token Management ──────────────────────────────────────────

  static Future<void> registerFcmToken({
    String? fcmToken,
    String? userId,
    String? role,
    String? studentId,
  }) async {
    try {
      final token = fcmToken ?? await _messaging.getToken();
      if (token == null || token.isEmpty) return;

      final currentUid = userId ?? FirebaseAuth.instance.currentUser?.uid ?? 'guest';
      final deviceInfo = DeviceInfoPlugin();
      String deviceId = 'unknown_device';
      String platformName = kIsWeb ? 'web' : defaultTargetPlatform.name;

      if (!kIsWeb) {
        if (defaultTargetPlatform == TargetPlatform.android) {
          final androidInfo = await deviceInfo.androidInfo;
          deviceId = androidInfo.id;
        } else if (defaultTargetPlatform == TargetPlatform.iOS) {
          final iosInfo = await deviceInfo.iosInfo;
          deviceId = iosInfo.identifierForVendor ?? 'ios_device';
        }
      }

      await _firestore.collection('devices').doc('${currentUid}_$deviceId').set(
        {
          'fcmToken': token,
          'platform': platformName,
          'deviceId': deviceId,
          'userId': currentUid,
          'role': role ?? 'student',
          'studentId': studentId ?? '',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'isActive': true,
        },
        SetOptions(merge: true),
      );

      debugPrint('[NotificationService] FCM token registered for $currentUid ($deviceId)');
    } catch (e) {
      debugPrint('[NotificationService] Token register error: $e');
    }
  }

  static Future<void> unregisterFcmToken() async {
    try {
      final currentUid = FirebaseAuth.instance.currentUser?.uid;
      if (currentUid == null) return;
      final snapshot = await _firestore.collection('devices').where('userId', isEqualTo: currentUid).get();
      for (final doc in snapshot.docs) {
        await doc.reference.update({'isActive': false, 'updatedAt': FieldValue.serverTimestamp()});
      }
    } catch (e) {
      debugPrint('[NotificationService] Unregister token error: $e');
    }
  }

  // ── 5. Display Local Notification ────────────────────────────────────

  static Future<void> showLocalNotification({
    String channelId = 'academy_important_alerts',
=======
  static Future<void> showLocalNotification({
>>>>>>> f3ea761015c75ae110b34ffdbd3ba32c332190b4
    required String title,
    required String body,
    String? payload,
  }) async {
    AndroidNotificationDetails androidDetails;

    switch (channelId) {
      case 'fee_reminders':
        androidDetails = const AndroidNotificationDetails(
          'fee_reminders',
          'Fee Reminders',
          channelDescription: 'Pending fee reminders & payment confirmations',
          importance: Importance.high,
          priority: Priority.high,
          visibility: NotificationVisibility.public,
          playSound: true,
          enableVibration: true,
        );
        break;
      case 'attendance_updates':
        androidDetails = const AndroidNotificationDetails(
          'attendance_updates',
          'Attendance Updates',
          channelDescription: 'Student check-in, check-out, absent, and late alerts',
          importance: Importance.high,
          priority: Priority.high,
          visibility: NotificationVisibility.public,
          playSound: true,
          enableVibration: true,
        );
        break;
      case 'general_notifications':
        androidDetails = const AndroidNotificationDetails(
          'general_notifications',
          'General Notifications',
          channelDescription: 'News, results, timetable updates',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          playSound: true,
        );
        break;
      default:
        androidDetails = const AndroidNotificationDetails(
          'academy_important_alerts',
          'Academy Important Alerts',
          channelDescription: 'Emergency notices, arrivals, and urgent alerts',
          importance: Importance.max,
          priority: Priority.high,
          visibility: NotificationVisibility.public,
          playSound: true,
          enableVibration: true,
        );
    }

    final platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    await _localNotificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      platformDetails,
      payload: payload,
    );
  }

  // ── 6. Notification Payload Routing ──────────────────────────────────

  static void handleNotificationPayload(String? payloadJson) {
    if (payloadJson == null || payloadJson.isEmpty) return;

    try {
      final Map<String, dynamic> data = jsonDecode(payloadJson);
      final String? type = data['type']?.toString();
      final String? screen = data['screen']?.toString();

      debugPrint('[NotificationService] Navigating for payload type: $type, screen: $screen');

      final context = navigatorKey?.currentContext;
      if (context == null) return;

      if (type == 'fee_reminder' || screen == 'fee_details') {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const FeeRemindersScreen()));
      } else if (type == 'attendance_check_in' || type == 'attendance_check_out' || type == 'absent_alert') {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const StudentDashboardScreen()));
      } else if (type == 'timetable_updated' || screen == 'class_schedules') {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const ClassSchedulesScreen()));
      } else {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen()));
      }
    } catch (e) {
      debugPrint('[NotificationService] Payload parse error: $e');
    }
  }

  // ── 7. Cached Stream & Persistence ───────────────────────────────────

  static Stream<List<NotificationModel>> notificationsStream() {
    if (!_initialized) init();
    return _controller.stream;
  }

  static Future<void> _syncFromFirestoreToHive() async {
    try {
      final snapshot = await _firestore.collection(_collection).orderBy('timestamp', descending: true).get();
      final notifications = snapshot.docs.map((doc) {
        final rawData = doc.data();
        final map = {...rawData, 'id': doc.id};
        return NotificationModel.fromMap(map, doc.id);
      }).toList();

      await _notificationBox.clear();
      for (final notification in notifications) {
        await _notificationBox.put(notification.id, notification.toHiveMap());
      }
      _controller.add(_sortedNotifications(_fromHive()));
    } catch (e) {
      debugPrint("Notification sync error: $e");
    }
  }

  static void _listenToFirestore() {
    _firestoreSubscription?.cancel();
    _firestoreSubscription = _firestore.collection(_collection).orderBy('timestamp', descending: true).snapshots().listen(
      (snapshot) {
        final notifications = snapshot.docs.map((doc) {
          final rawData = doc.data();
          final map = {...rawData, 'id': doc.id};
          return NotificationModel.fromMap(map, doc.id);
        }).toList();

        _persistHiveBatch(notifications);
        _controller.add(_sortedNotifications(notifications));
      },
      onError: (e) => debugPrint("Notification Firestore Error: $e"),
    );
  }

  static void _cancelFirestoreSubscription() {
    _firestoreSubscription?.cancel();
    _firestoreSubscription = null;
  }

  static Future<void> _persistHiveBatch(List<NotificationModel> notifications) async {
    await _notificationBox.clear();
    for (final notification in notifications) {
      await _notificationBox.put(notification.id, notification.toHiveMap());
    }
  }

  static List<NotificationModel> _fromHive() {
    return _notificationBox.values.map((value) => NotificationModel.fromHiveMap(Map<String, dynamic>.from(value))).toList();
  }

  static List<NotificationModel> _sortedNotifications(List<NotificationModel> notifications) {
    notifications.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return notifications;
  }

  static List<NotificationModel> getCachedNotifications() {
    if (!_initialized) return [];
    return _sortedNotifications(_fromHive());
  }

  static Future<int> unreadCount() async {
    if (!_initialized) await init();
    return _fromHive().where((n) => !n.isRead).length;
  }

<<<<<<< HEAD
  // ── 8. Notification Creation Triggers ────────────────────────────────
=======
  static Future<void> createStudentRegistrationNotification({
    required StudentModel student,
    String? registeredBy,
  }) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    final notification = buildStudentRegistrationNotification(
      student: student,
      registeredBy: registeredBy ?? currentUser?.email ?? 'Administrator',
    );

    if (currentUser != null) {
      try {
        final exists = await _firestore
            .collection(_collection)
            .where('studentId', isEqualTo: student.id)
            .where('notificationType', isEqualTo: 'student_registered')
            .get();
        if (exists.docs.isNotEmpty) {
          return;
        }
      } catch (_) {}
    }

    await _saveNotification(notification, emitLocal: true);
    showLocalNotification(title: notification.title, body: notification.message);
  }
>>>>>>> f3ea761015c75ae110b34ffdbd3ba32c332190b4

  static NotificationModel buildStudentRegistrationNotification({
    required StudentModel student,
    String? registeredBy,
  }) {
    final fullName = '${student.firstName} ${student.lastName}'.trim();
    return NotificationModel(
      id: 'reg_${student.id}_${DateTime.now().millisecondsSinceEpoch}',
      title: 'New Student Registered',
      message: '$fullName has been registered in ${student.classType} ${student.grade} (${student.subject}).',
      studentName: fullName,
      className: student.classType,
      subject: student.subject,
      registeredBy: registeredBy ?? 'Administrator',
      timestamp: DateTime.now(),
      notificationType: 'student_registered',
      isRead: false,
      studentId: student.id,
    );
  }

  static Future<void> createStudentRegistrationNotification({
    required StudentModel student,
    String? registeredBy,
  }) async {
    final notification = buildStudentRegistrationNotification(
      student: student,
      registeredBy: registeredBy,
    );

    await _saveNotification(notification, emitLocal: true);
    showLocalNotification(
      channelId: 'general_notifications',
      title: notification.title,
      body: notification.message,
    );
  }

  static Future<void> createFeePaymentNotification({
    required StudentModel student,
    required double amount,
    bool isSecondInstallment = false,
  }) async {
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
      registeredBy: 'Administrator',
      timestamp: DateTime.now(),
      notificationType: isSecondInstallment ? 'second_installment' : 'fee_payment',
      isRead: false,
      studentId: student.id,
    );

    await _saveNotification(notification, emitLocal: true);
<<<<<<< HEAD
    showLocalNotification(
      channelId: 'fee_reminders',
      title: notification.title,
      body: notification.message,
    );
  }

  static Future<void> createAttendanceNotification({
    required String studentId,
    required String studentName,
    required String status,
    required String time,
  }) async {
    final title = 'Attendance Update: $status';
    final body = '$studentName marked $status at $time.';

    final notification = NotificationModel(
      id: 'att_${studentId}_${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      message: body,
      studentName: studentName,
      className: '',
      subject: '',
      registeredBy: 'System',
      timestamp: DateTime.now(),
      notificationType: 'attendance_$status',
      isRead: false,
      studentId: studentId,
    );

    await _saveNotification(notification, emitLocal: true);
    showLocalNotification(
      channelId: 'attendance_updates',
      title: title,
      body: body,
    );
=======
    showLocalNotification(title: notification.title, body: notification.message);
>>>>>>> f3ea761015c75ae110b34ffdbd3ba32c332190b4
  }

  static Future<void> _saveNotification(NotificationModel notification, {required bool emitLocal}) async {
    if (!_initialized) await init();
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
    if (!_initialized) await init();
    try {
      await _firestore.collection(_collection).doc(notificationId).update({'isRead': true});
    } catch (_) {}
    final existing = _notificationBox.get(notificationId);
    if (existing != null) {
      final updated = Map<String, dynamic>.from(existing)..['isRead'] = true;
      await _notificationBox.put(notificationId, updated);
    }
    _controller.add(_sortedNotifications([..._fromHive()]));
  }

  static Future<void> markAllAsRead() async {
    if (!_initialized) await init();
    final notifications = _fromHive();
    try {
      final batch = _firestore.batch();
      for (final notification in notifications.where((n) => !n.isRead)) {
        batch.update(_firestore.collection(_collection).doc(notification.id), {'isRead': true});
      }
      await batch.commit();
    } catch (_) {}
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
    if (!_initialized) await init();
    try {
      await _firestore.collection(_collection).doc(notificationId).delete();
    } catch (_) {}
    await _notificationBox.delete(notificationId);
    _controller.add(_sortedNotifications([..._fromHive()]));
  }

  static Future<void> clearAllNotifications() async {
    if (!_initialized) await init();
    try {
      final snapshot = await _firestore.collection(_collection).get();
      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } catch (_) {}
    await _notificationBox.clear();
    _controller.add([]);
  }

  static Future<void> dispose() async {
    await _authSubscription?.cancel();
    await _firestoreSubscription?.cancel();
    await _controller.close();
    _initialized = false;
  }
}
