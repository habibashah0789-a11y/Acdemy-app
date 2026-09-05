import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive/hive.dart';

import '../models/notification_model.dart';
import 'sound_service.dart';
import '../models/student_model.dart';
import '../screens/fee_reminders_screen.dart';
import '../screens/notifications_screen.dart';
import '../settings/class_schedules_screen.dart';
import '../student_portal/student_auth_service.dart';
import '../student_portal/student_dashboard_screen.dart';
import '../student_portal/student_notifications_screen.dart';
import '../theme/app_theme.dart';
import 'database_service.dart';
import 'sound_service.dart';

/// Top-level background message handler for FCM.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint("[FCM BACKGROUND] Received background message ID: ${message.messageId}");
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

  // Tracks IDs already seen by the Firestore stream so we only beep on
  // genuinely new notifications, not on the initial snapshot load.
  static final Set<String> _seenNotificationIds = {};
  static bool _firstSnapshotReceived = false;

  // Student specific notification stream elements
  static StreamSubscription<QuerySnapshot>? _studentFirestoreSubscription;
  static bool _studentFirstSnapshotReceived = false;
  static final Set<String> _studentSeenNotificationIds = {};

  // ── 1. Android Notification Channels ──────────────────────────────────

  static const String defaultChannelId = 'academy_notifications_v3';
  static const String defaultChannelName = 'Academy Notifications';
  static const String defaultSoundName = 'soft_chime_notification';

  static const String feeReminderChannelId = 'academy_fee_reminders_v3';
  static const String feeReminderChannelName = 'Fee Reminders';

  static const AndroidNotificationChannel _academyNotificationsV2Channel =
      AndroidNotificationChannel(
    defaultChannelId,
    defaultChannelName,
    description: 'Important academy notifications and student updates',
    importance: Importance.high,
    playSound: true,
    sound: RawResourceAndroidNotificationSound(defaultSoundName),
    enableVibration: true,
  );

  static const AndroidNotificationChannel _feeRemindersV2Channel =
      AndroidNotificationChannel(
    feeReminderChannelId,
    feeReminderChannelName,
    description: 'Fee reminders and payment notifications from the academy',
    importance: Importance.high,
    playSound: true,
    sound: RawResourceAndroidNotificationSound(defaultSoundName),
    enableVibration: true,
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
        await androidPlugin.createNotificationChannel(_academyNotificationsV2Channel);
        await androidPlugin.createNotificationChannel(_feeRemindersV2Channel);
        debugPrint('''
==============================
[FEE CHANNEL]
created = $feeReminderChannelId
sound = $defaultSoundName
importance = high
==============================''');
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

      final statusStr = settings.authorizationStatus.toString();
      debugPrint('''
==============================
[FCM DEBUG]
authorizationStatus = $statusStr
platform = ${defaultTargetPlatform.name}
Firebase projectId = ${Firebase.app().options.projectId}
==============================''');

      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        debugPrint('[FCM DEBUG] User denied notification permissions');
        return;
      }

      String? token;
      try {
        token = await _messaging.getToken();
        final tokenExists = token != null && token.isNotEmpty;
        debugPrint('''
==============================
[FCM DEBUG TOKEN]
token exists = ${tokenExists ? 'YES' : 'NO'}
token length = ${token?.length ?? 0}
platform = ${defaultTargetPlatform.name}
Firebase projectId = ${Firebase.app().options.projectId}
==============================''');

        await _messaging.subscribeToTopic('academy_all');
        await _messaging.subscribeToTopic('students');
      } catch (e) {
        debugPrint('[NotificationService] FCM token retrieval note (platform specific): $e');
      }
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      // Handle Foreground Notifications (App OPEN)
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('[NotificationService] Foreground message received: ${message.notification?.title}');
        final notification = message.notification;

        if (notification != null) {
          showLocalNotification(
            channelId: defaultChannelId,
            title: notification.title ?? 'Quaid Academy Alert',
            body: notification.body ?? '',
            payload: jsonEncode(message.data),
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
        debugPrint('[FCM DEBUG] Token refreshed (${newToken.length} chars)');
        registerFcmToken(fcmToken: newToken);
      });

      await registerFcmToken(fcmToken: token);
    } catch (e) {
      debugPrint('[NotificationService] Push init error: $e');
    }
  }

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

  static Future<void> unregisterFcmToken({String? userId}) async {
    try {
      final currentUid = userId ?? FirebaseAuth.instance.currentUser?.uid;
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
    String channelId = defaultChannelId,
    required String title,
    required String body,
    String? payload,
  }) async {
    try {
      final androidDetails = AndroidNotificationDetails(
        channelId,
        channelId == feeReminderChannelId ? feeReminderChannelName : defaultChannelName,
        channelDescription: channelId == feeReminderChannelId
            ? 'Fee reminders and payment notifications from the academy'
            : 'Important academy notifications and student updates',
        importance: Importance.high,
        priority: Priority.high,
        visibility: NotificationVisibility.public,
        playSound: true,
        sound: const RawResourceAndroidNotificationSound(defaultSoundName),
        enableVibration: true,
      );

      final platformDetails = NotificationDetails(
        android: androidDetails,
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          sound: 'academy_notification.wav',
        ),
      );

      await _localNotificationsPlugin.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title,
        body,
        platformDetails,
        payload: payload,
      );
      await SoundService.playNotification();
    } catch (e) {
      debugPrint('[NotificationService] Local notification sound lookup failed ($e), falling back to default sound');
      try {
        final fallbackAndroidDetails = AndroidNotificationDetails(
          channelId,
          channelId == feeReminderChannelId ? feeReminderChannelName : defaultChannelName,
          channelDescription: 'Important academy notifications',
          importance: Importance.high,
          priority: Priority.high,
          visibility: NotificationVisibility.public,
          playSound: true,
          enableVibration: true,
        );

        await _localNotificationsPlugin.show(
          DateTime.now().millisecondsSinceEpoch ~/ 1000,
          title,
          body,
          NotificationDetails(android: fallbackAndroidDetails),
          payload: payload,
        );
      } catch (fallbackError) {
        debugPrint('[NotificationService] Fallback local notification error: $fallbackError');
      }
    }
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

      // Detect if we're currently in the student portal
      StudentAuthService.getLocalSession().then((session) {
        final isStudentSession = session != null;
        if (isStudentSession) {
          // Route student portal notifications to student screens
          if (type == 'fee_reminder' || screen == 'fee_details') {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const StudentNotificationsScreen()));
          } else if (type == 'announcement' || type == 'broadcast' || screen == 'notifications') {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const StudentNotificationsScreen()));
          } else {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const StudentDashboardScreen()));
          }
        } else {
          // Admin portal routing
          if (type == 'fee_reminder' || screen == 'fee_details') {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const FeeRemindersScreen()));
          } else if (type == 'attendance_check_in' || type == 'attendance_check_out' || type == 'absent_alert') {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const StudentDashboardScreen()));
          } else if (type == 'timetable_updated' || screen == 'class_schedules') {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const ClassSchedulesScreen()));
          } else {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen()));
          }
        }
      });
    } catch (e) {
      debugPrint('[NotificationService] Payload parse error: $e');
    }
  }

  // ── 7. Cached Stream & Persistence ───────────────────────────────────

  static Stream<List<NotificationModel>> notificationsStream() {
    if (!_initialized) init();
    return _controller.stream;
  }

  static bool _isAdminNotification(NotificationModel n) {
    // Individual fee reminders targeted to specific students are NOT shown on the admin portal
    if (n.notificationType == 'fee_reminder' && n.studentId.isNotEmpty && n.studentId != 'admin_only') {
      return false;
    }
    return true;
  }

  static Future<void> _syncFromFirestoreToHive() async {
    try {
      final snapshot = await _firestore.collection(_collection).orderBy('timestamp', descending: true).get();
      final notifications = snapshot.docs.map((doc) {
        final rawData = doc.data();
        final map = {...rawData, 'id': doc.id};
        return NotificationModel.fromMap(map, doc.id);
      }).where((n) => _isAdminNotification(n)).toList();

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
    _firestoreSubscription = _firestore
        .collection(_collection)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .listen(
      (snapshot) {
        final notifications = snapshot.docs.map((doc) {
          final rawData = doc.data();
          final map = {...rawData, 'id': doc.id};
          return NotificationModel.fromMap(map, doc.id);
        }).where((n) => _isAdminNotification(n)).toList();

        // On the very first snapshot, just record what exists — don’t beep.
        if (!_firstSnapshotReceived) {
          _firstSnapshotReceived = true;
          for (final n in notifications) {
            _seenNotificationIds.add(n.id);
          }
        } else {
          // Find any notification IDs we haven’t seen before.
          final newUnread = notifications.where(
            (n) => !_seenNotificationIds.contains(n.id) && !n.isRead,
          ).toList();

          if (newUnread.isNotEmpty) {
            // Beep once regardless of how many new notifications arrived.
            SoundService.playNotification();
          }

          for (final n in notifications) {
            _seenNotificationIds.add(n.id);
          }
        }

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

  // ── 8. Notification Creation Triggers ────────────────────────────────

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
      studentId: 'admin_only', // Only Admin receives student registration notifications
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

    try {
      final subjects = student.subject
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();

      if (subjects.isEmpty) {
        subjects.add('all');
      }

      for (final sub in subjects) {
        final notifId = 'reg_${student.id}_${sub}_${DateTime.now().millisecondsSinceEpoch}';
        final title = '🎓 New Student Registered: ${student.name}';
        final body =
            'Student ${student.name} (Code: ${student.studentCode}, Grade: ${student.grade} - ${student.classType}) has been enrolled in $sub.';

        final data = {
          'id': notifId,
          'title': title,
          'body': body,
          'message': body,
          'studentName': student.name,
          'studentId': student.id,
          'studentCode': student.studentCode,
          'class': student.classType,
          'targetSection': student.classType,
          'subject': sub,
          'targetSubject': sub,
          'registeredBy': registeredBy ?? 'Administration',
          'timestamp': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
          'type': 'student_registered',
          'notificationType': 'student_registered',
          'isRead': false,
        };

        await _firestore.collection(_collection).doc(notifId).set(data);

        final topicName = 'class_${student.classType.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_')}';
        unawaited(triggerPushNotification(
          targetTopic: topicName,
          title: title,
          body: body,
          channelId: defaultChannelId,
          payload: {
            'type': 'student_registered',
            'studentId': student.id,
            'subject': sub,
          },
        ));
      }
      debugPrint('[NotificationService] Registration notification dispatched for ${student.name}');
    } catch (e) {
      debugPrint('[NotificationService] createStudentRegistrationNotification error: $e');
    }
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
    showLocalNotification(
      channelId: 'fee_reminders',
      title: notification.title,
      body: notification.message,
    );
  }

  /// Creates a personalized fee reminder notification targeted to a specific student.
  /// The student's [listenForStudent] subscription picks it up, plays sound, and
  /// shows a push notification with the student's personal fee breakdown.
  static Future<void> createFeeReminderNotificationForStudent({
    required StudentModel student,
  }) async {
    final fullName = student.name;
    final notification = NotificationModel(
      id: 'fee_alert_${student.id}_${DateTime.now().millisecondsSinceEpoch}',
      title: '💳 Fee Payment Reminder',
      message:
          'Dear $fullName, your fee balance is pending.\n'
          '• Total Fee: Rs. ${student.totalFee.toStringAsFixed(0)}\n'
          '• Paid: Rs. ${student.feeSubmitted.toStringAsFixed(0)}\n'
          '• Remaining: Rs. ${student.feeRemaining.toStringAsFixed(0)}\n'
          'Please clear your dues at the earliest.',
      studentName: fullName,
      className: student.classType,
      subject: student.subject,
      registeredBy: 'Administrator',
      timestamp: DateTime.now(),
      notificationType: 'fee_reminder',
      isRead: false,
      studentId: student.id,
    );

    // Persist to Firestore
    try {
      await _firestore
          .collection(_collection)
          .doc(notification.id)
          .set(notification.toMap());
    } catch (e) {
      debugPrint('[NotificationService] Fee reminder notification failed: $e');
    }

    // Check device token for logging
    bool tokenFound = false;
    try {
      final devicesSnap = await _firestore
          .collection('devices')
          .where('userId', isEqualTo: student.id)
          .where('isActive', isEqualTo: true)
          .get();

      if (devicesSnap.docs.isNotEmpty) {
        tokenFound = true;
      } else {
        final studentSnap = await _firestore
            .collection('devices')
            .where('studentId', isEqualTo: student.id)
            .where('isActive', isEqualTo: true)
            .get();
        if (studentSnap.docs.isNotEmpty) tokenFound = true;
      }
    } catch (_) {}

    debugPrint('''
==============================
[FEE REMINDER SEND]
studentCode = ${student.id}
studentId = ${student.id}
FCM token found = ${tokenFound ? 'YES' : 'NO'}
token source path = devices (userId/studentId == ${student.id})
Firebase project = ${Firebase.app().options.projectId}
==============================''');

    // Trigger push notification for background & terminated device delivery
    await triggerPushNotification(
      targetUserId: student.id,
      title: 'Fee Reminder',
      body: 'You have a new fee reminder from Quaid Academy.',
      channelId: feeReminderChannelId,
      payload: {
        'type': 'fee_reminder',
        'studentId': student.id,
        'studentCode': student.id,
        'screen': 'fee_details',
      },
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
      channelId: defaultChannelId,
      title: title,
      body: body,
    );
  }



  static Future<void> triggerPushNotification({
    String? targetUserId,
    String? targetTopic,
    required String title,
    required String body,
    String? channelId,
    Map<String, String>? payload,
  }) async {
    final targetChannel = channelId ?? defaultChannelId;
    try {
      final data = <String, dynamic>{
        'title': title,
        'body': body,
        'channelId': targetChannel,
        'sound': defaultSoundName,
        'payload': payload ?? {},
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      };

      if (targetTopic != null && targetTopic.isNotEmpty) {
        data['targetTopic'] = targetTopic;
      } else if (targetUserId != null && targetUserId.isNotEmpty) {
        data['targetUserId'] = targetUserId;
      }

      final docRef = await _firestore.collection('notification_triggers').add(data);

      debugPrint('''
==============================
[FCM SEND TRIGGER CREATED]
triggerId = ${docRef.id}
targetTopic = ${targetTopic ?? 'N/A'}
targetUserId = ${targetUserId ?? 'N/A'}
title = $title
channelId = $targetChannel
sound = $defaultSoundName
status = PENDING
==============================''');
    } catch (e) {
      debugPrint('[FCM TRIGGER ERROR] Failed to create push trigger: $e');
    }
  }

  static Future<void> _saveNotification(NotificationModel notification, {required bool emitLocal}) async {
    if (!_initialized) await init();
    final exists = _notificationBox.values.any((value) => value['id'] == notification.id);
    if (!exists) {
      await _notificationBox.put(notification.id, notification.toHiveMap());
      if (emitLocal) {
        _controller.add(_sortedNotifications([..._fromHive()]));
      }
      unawaited(_firestore
          .collection(_collection)
          .doc(notification.id)
          .set(notification.toMap())
          .catchError((_) {}));

      if (notification.studentId.isEmpty) {
        unawaited(triggerPushNotification(
          targetTopic: 'academy_all',
          title: notification.title,
          body: notification.message,
          channelId: defaultChannelId,
          payload: {
            'type': notification.notificationType,
            'screen': 'notifications',
          },
        ));
      } else if (notification.studentId != 'admin_only') {
        unawaited(triggerPushNotification(
          targetUserId: notification.studentId,
          title: notification.title,
          body: notification.message,
          channelId: defaultChannelId,
          payload: {
            'type': notification.notificationType,
            'studentId': notification.studentId,
          },
        ));
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

  // ── 9. Student Real-time Notifications Listener ────────────────────────────

  static Future<void> subscribeToStudentTopics(StudentModel student) async {
    try {
      final safeClass = student.classType.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');
      final subjects = student.subject.split(',').map((e) => e.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_')).toList();
      
      for (var sub in subjects) {
        if (sub.isNotEmpty) {
          await _messaging.subscribeToTopic('class_${safeClass}_subject_$sub');
        }
      }
    } catch (e) {
      debugPrint('[NotificationService] Error subscribing to student topics: $e');
    }
  }

  static void listenForStudent(String studentId) {
    if (!_initialized) {
      init();
    }
    
    // Fetch student info and subscribe to their class/subject topics
    final student = DatabaseService.studentBox.get(studentId);
    if (student != null) {
      subscribeToStudentTopics(student);
    }
    
    _studentFirestoreSubscription?.cancel();
    _studentFirstSnapshotReceived = false;
    _studentSeenNotificationIds.clear();

    _studentFirestoreSubscription = _firestore
        .collection(_collection)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .listen(
      (snapshot) {
        final notifications = snapshot.docs.map((doc) {
          final rawData = doc.data();
          final map = {...rawData, 'id': doc.id};
          return NotificationModel.fromMap(map, doc.id);
        }).toList();

        // Filter notices for this student
        final filteredNotices = notifications.where((n) {
          if (n.studentId == 'admin_only' || n.notificationType == 'fee_reminder_summary') return false;
          
          // Targeted specifically to this student
          if (n.studentId.isNotEmpty && n.studentId == studentId) return true;
          // If targeted to another specific student, ignore it
          if (n.studentId.isNotEmpty) return false;
          
          // If it's a teacher announcement, check if the student takes that subject
          if (n.notificationType == 'teacher_announcement' && student != null) {
            final classType = student.classType.trim().toLowerCase();
            final subjects = student.subject.split(',').map((e) => e.trim().toLowerCase()).toList();
            
            final nClass = n.className.trim().toLowerCase();
            final nSubj = n.subject.trim().toLowerCase();
            
            final matchesClass = (nClass.isEmpty || nClass == classType || nClass == 'all');
            final matchesSubject = (nSubj.isEmpty || nSubj == 'all' || subjects.contains(nSubj));
            
            return matchesClass && matchesSubject;
          }
          
          // General broadcasts
          return true;
        }).toList();

        _lastFilteredNotices = filteredNotices;
        _updateUnreadCount();

        // On the very first snapshot, just record what exists — don’t beep.
        if (!_studentFirstSnapshotReceived) {
          _studentFirstSnapshotReceived = true;
          for (final n in filteredNotices) {
            _studentSeenNotificationIds.add(n.id);
          }
        } else {
          // Find any notification IDs we haven’t seen before.
          final newUnread = filteredNotices.where(
            (n) => !_studentSeenNotificationIds.contains(n.id) && !n.isRead,
          ).toList();

          if (newUnread.isNotEmpty) {
            // Play custom chime sound
            SoundService.playNotification();

            // Show a local notification for each new unread message
            for (final n in newUnread) {
              String formattedTitle = n.title;
              if (n.isTeacherAnnouncement &&
                  n.teacherDisplayName.isNotEmpty &&
                  !n.title.contains(n.teacherDisplayName)) {
                formattedTitle = '📢 ${n.authorDisplay}: ${n.title}';
              }
              showLocalNotification(
                channelId: defaultChannelId,
                title: formattedTitle,
                body: n.message,
              );
            }
          }

          for (final n in filteredNotices) {
            _studentSeenNotificationIds.add(n.id);
          }
        }
      },
      onError: (e) => debugPrint("Student Notification Firestore Error: $e"),
    );
  }

  static void cancelStudentSubscription() {
    _studentFirestoreSubscription?.cancel();
    _studentFirestoreSubscription = null;
  }

  // ── 10. Teacher Real-time Notifications Listener ────────────────────────────

  static StreamSubscription? _teacherFirestoreSubscription;
  static bool _teacherFirstSnapshotReceived = false;
  static final Set<String> _teacherSeenNotificationIds = {};
  
  static final ValueNotifier<int> teacherUnreadNoticesCount = ValueNotifier<int>(0);
  static List<NotificationModel> _lastTeacherFilteredNotices = [];
  
  static void listenForTeacher(TeacherModel teacher) {
    if (!_initialized) {
      init();
    }
    
    _teacherFirestoreSubscription?.cancel();
    _teacherFirstSnapshotReceived = false;
    _teacherSeenNotificationIds.clear();

    _teacherFirestoreSubscription = _firestore
        .collection(_collection)
        .orderBy('timestamp', descending: true)
        .limit(100)
        .snapshots()
        .listen(
      (snapshot) {
        final notifications = snapshot.docs.map((doc) {
          final rawData = doc.data();
          final map = {...rawData, 'id': doc.id};
          return NotificationModel.fromMap(map, doc.id);
        }).toList();

        final filteredNotices = notifications.where((n) {
          // targeted payout
          if (n.notificationType == 'teacher_payout') {
            final targetTeacherId = n.teacherId;
            if (targetTeacherId.isNotEmpty) {
              return targetTeacherId == teacher.id;
            }
          }

          final targetSubject = n.subject.trim().toLowerCase();
          final targetSection = n.className.trim().toLowerCase();
          
          if (targetSubject.isEmpty || targetSubject == 'all' || targetSection == 'all') {
            return true;
          }
          final mySubject = teacher.subject.toLowerCase();
          final mySection = teacher.section.toLowerCase();
          return targetSubject == mySubject && (targetSection.isEmpty || targetSection == mySection);
        }).toList();

        _lastTeacherFilteredNotices = filteredNotices;
        _updateUnreadCount();

        if (!_teacherFirstSnapshotReceived) {
          _teacherFirstSnapshotReceived = true;
          for (final n in filteredNotices) {
            _teacherSeenNotificationIds.add(n.id);
          }
        } else {
          final newUnread = filteredNotices.where(
            (n) => !_teacherSeenNotificationIds.contains(n.id) && !isNoticeRead(n.id),
          ).toList();

          if (newUnread.isNotEmpty) {
            SoundService.playNotification();
            for (final n in newUnread) {
              showLocalNotification(
                channelId: defaultChannelId,
                title: n.title,
                body: n.message,
              );
            }
          }

          for (final n in filteredNotices) {
            _teacherSeenNotificationIds.add(n.id);
          }
        }
      },
      onError: (e) => debugPrint("Teacher Notification Firestore Error: $e"),
    );
  }

  static void cancelTeacherSubscription() {
    _teacherFirestoreSubscription?.cancel();
    _teacherFirestoreSubscription = null;
  }

  static final ValueNotifier<int> studentUnreadNoticesCount = ValueNotifier<int>(0);
  static List<NotificationModel> _lastFilteredNotices = [];
  static final StreamController<void> _readStatusController = StreamController<void>.broadcast();
  static Stream<void> get readStatusStream => _readStatusController.stream;

  static Future<void> markNoticeAsRead(String noticeId) async {
    final box = await Hive.openBox<bool>('read_notices');
    await box.put(noticeId, true);
    _readStatusController.add(null);
    _updateUnreadCount();
  }

  static bool isNoticeRead(String noticeId) {
    if (!Hive.isBoxOpen('read_notices')) {
      return false;
    }
    final box = Hive.box<bool>('read_notices');
    return box.get(noticeId, defaultValue: false) ?? false;
  }

  static void _updateUnreadCount() {
    studentUnreadNoticesCount.value = _lastFilteredNotices.where((n) => !isNoticeRead(n.id)).length;
    teacherUnreadNoticesCount.value = _lastTeacherFilteredNotices.where((n) => !isNoticeRead(n.id)).length;
  }

  static Future<void> dispose() async {
    await _authSubscription?.cancel();
    await _firestoreSubscription?.cancel();
    await _studentFirestoreSubscription?.cancel();
    await _teacherFirestoreSubscription?.cancel();
    await _controller.close();
    _initialized = false;
  }
}
