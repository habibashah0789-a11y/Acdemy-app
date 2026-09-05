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
  final String mediaUrl;
  final String mediaType; // 'image', 'pdf', 'audio', 'none'
  final String teacherName;
  final String teacherSubject;

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
    this.mediaUrl = '',
    this.mediaType = 'none',
    this.teacherName = '',
    this.teacherSubject = '',
  });

  String get studentClass => className;

  bool get isTeacherAnnouncement =>
      notificationType == 'teacher_announcement' ||
      teacherName.isNotEmpty ||
      (registeredBy.isNotEmpty &&
          !registeredBy.toLowerCase().contains('admin') &&
          !registeredBy.toLowerCase().contains('system') &&
          subject.isNotEmpty);

  String get teacherDisplayName {
    if (teacherName.isNotEmpty) return teacherName;
    if (registeredBy.isNotEmpty &&
        !registeredBy.toLowerCase().contains('admin') &&
        !registeredBy.toLowerCase().contains('system')) {
      if (registeredBy.contains('(')) {
        return registeredBy.split('(').first.trim();
      }
      return registeredBy;
    }
    return '';
  }

  String get teacherSubjectDisplay {
    if (teacherSubject.isNotEmpty) return teacherSubject;
    if (subject.isNotEmpty &&
        subject.toLowerCase() != 'all' &&
        subject.toLowerCase() != 'general') {
      return subject;
    }
    return '';
  }

  String get authorDisplay {
    final tName = teacherDisplayName;
    final tSub = teacherSubjectDisplay;
    if (tName.isNotEmpty && tSub.isNotEmpty) {
      return '$tName ($tSub Teacher)';
    } else if (tName.isNotEmpty) {
      return '$tName (Teacher)';
    } else if (registeredBy.isNotEmpty) {
      return registeredBy;
    }
    return 'Administration';
  }

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
      'mediaUrl': mediaUrl,
      'mediaType': mediaType,
      'teacherName': teacherName,
      'teacherSubject': teacherSubject,
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
      'mediaUrl': mediaUrl,
      'mediaType': mediaType,
      'teacherName': teacherName,
      'teacherSubject': teacherSubject,
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

    final rawRegisteredBy = map['registeredBy']?.toString() ?? '';
    final rawTeacherName = map['teacherName']?.toString() ??
        (map['notificationType'] == 'teacher_announcement' ? rawRegisteredBy : '');
    final rawTeacherSubject = map['teacherSubject']?.toString() ??
        map['subject']?.toString() ??
        map['targetSubject']?.toString() ??
        '';

    return NotificationModel(
      id: (docId ?? map['id'] ?? '').toString(),
      title: map['title']?.toString() ?? 'Notification',
      message: map['message']?.toString() ?? '',
      studentName: map['studentName']?.toString() ?? '',
      className: map['class']?.toString() ?? map['targetSection']?.toString() ?? '',
      subject: map['subject']?.toString() ?? map['targetSubject']?.toString() ?? '',
      registeredBy: rawRegisteredBy,
      timestamp: parsedTimestamp,
      notificationType: map['notificationType']?.toString() ?? map['type']?.toString() ?? 'general',
      isRead: map['isRead'] == true,
      studentId: map['studentId']?.toString() ?? '',
      mediaUrl: map['mediaUrl']?.toString() ?? map['attachmentUrl']?.toString() ?? '',
      mediaType: map['mediaType']?.toString() ?? map['attachmentType']?.toString() ?? 'none',
      teacherName: rawTeacherName,
      teacherSubject: rawTeacherSubject,
    );
  }

  factory NotificationModel.fromHiveMap(Map<String, dynamic> map) {
    return NotificationModel.fromMap(map, map['id']?.toString());
  }
}
