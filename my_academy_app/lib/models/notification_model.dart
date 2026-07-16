import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationModel {
  final String id;
  final String title;
  final String message;
  final String studentName;
  final String className;
  final String subject;
  final String registeredBy;
  final DateTime timestamp;
  final String notificationType;
  bool isRead;
  final String studentId;

  NotificationModel({
    required this.id,
    required this.title,
    required this.message,
    required this.studentName,
    required this.className,
    required this.subject,
    required this.registeredBy,
    required this.timestamp,
    required this.notificationType,
    required this.isRead,
    this.studentId = '',
  });

  String get studentClass => className;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'message': message,
      'studentName': studentName,
      'class': className,
      'subject': subject,
      'registeredBy': registeredBy,
      'timestamp': Timestamp.fromDate(timestamp),
      'notificationType': notificationType,
      'isRead': isRead,
      'studentId': studentId,
    };
  }

  Map<String, dynamic> toHiveMap() {
    return {
      'id': id,
      'title': title,
      'message': message,
      'studentName': studentName,
      'class': className,
      'subject': subject,
      'registeredBy': registeredBy,
      'timestamp': timestamp.toIso8601String(),
      'notificationType': notificationType,
      'isRead': isRead,
      'studentId': studentId,
    };
  }

  factory NotificationModel.fromMap(Map<String, dynamic> map, String? docId) {
    DateTime parsedTimestamp;
    final rawTimestamp = map['timestamp'];
    if (rawTimestamp is Timestamp) {
      parsedTimestamp = rawTimestamp.toDate();
    } else if (rawTimestamp is String) {
      parsedTimestamp = DateTime.tryParse(rawTimestamp) ?? DateTime.now();
    } else if (rawTimestamp is DateTime) {
      parsedTimestamp = rawTimestamp;
    } else {
      parsedTimestamp = DateTime.now();
    }

    return NotificationModel(
      id: (docId ?? map['id'] ?? '').toString(),
      title: map['title']?.toString() ?? 'Notification',
      message: map['message']?.toString() ?? '',
      studentName: map['studentName']?.toString() ?? '',
      className: map['class']?.toString() ?? '',
      subject: map['subject']?.toString() ?? '',
      registeredBy: map['registeredBy']?.toString() ?? '',
      timestamp: parsedTimestamp,
      notificationType: map['notificationType']?.toString() ?? 'general',
      isRead: map['isRead'] == true,
      studentId: map['studentId']?.toString() ?? '',
    );
  }

  factory NotificationModel.fromHiveMap(Map<String, dynamic> map) {
    return NotificationModel.fromMap(map, map['id']?.toString());
  }
}
