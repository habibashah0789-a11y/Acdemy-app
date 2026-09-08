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
  final String teacherId;
  final String targetHour;

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
    this.teacherId = '',
    this.targetHour = '',
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

  String get teacherClassDisplay {
    if (className.isNotEmpty &&
        className.toLowerCase() != 'all' &&
        className.toLowerCase() != 'general') {
      return className;
    }
    return '';
  }

  String get targetHourDisplay {
    if (targetHour.isNotEmpty &&
        targetHour.toLowerCase() != 'all' &&
        targetHour.toLowerCase() != 'all hours') {
      return targetHour;
    }
    return '';
  }

  String get teacherIdentityDisplay {
    final tName = teacherDisplayName;
    final tSub = teacherSubjectDisplay;
    final tCls = teacherClassDisplay;
    final tHr = targetHourDisplay;
    final parts = <String>[];
    if (tName.isNotEmpty) parts.add(tName);
    if (tSub.isNotEmpty) parts.add('$tSub Teacher');
    if (tCls.isNotEmpty) parts.add('Class: $tCls');
    if (tHr.isNotEmpty) parts.add('Batch: $tHr');
    if (parts.isNotEmpty) {
      return parts.join(' • ');
    }
    return authorDisplay;
  }

  String get authorDisplay {
    final tName = teacherDisplayName;
    final tSub = teacherSubjectDisplay;
    final tCls = teacherClassDisplay;
    final tHr = targetHourDisplay;

    if (tName.isNotEmpty) {
      final details = <String>[];
      if (tSub.isNotEmpty) details.add('$tSub Teacher');
      if (tCls.isNotEmpty) details.add(tCls);
      if (tHr.isNotEmpty) details.add(tHr);

      if (details.isNotEmpty) {
        return '$tName (${details.join(' • ')})';
      }
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
      'teacherId': teacherId,
      'targetHour': targetHour,
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
      'teacherId': teacherId,
      'targetHour': targetHour,
    };
  }

  factory NotificationModel.fromMap(Map<String, dynamic> map, String? docId) {
    DateTime parsedTimestamp;
    final rawTimestamp = map['timestamp'] ?? map['createdAt'];
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
        (map['notificationType'] == 'teacher_announcement' || map['type'] == 'teacher_announcement'
            ? (rawRegisteredBy.contains('(') ? rawRegisteredBy.split('(').first.trim() : rawRegisteredBy)
            : '');
    final rawTeacherSubject = map['teacherSubject']?.toString() ??
        map['subject']?.toString() ??
        map['targetSubject']?.toString() ??
        '';

    final parsedTeacherId = map['teacherId']?.toString() ?? map['senderId']?.toString() ?? '';

    final parsedClassName = map['className']?.toString() ??
        map['targetClass']?.toString() ??
        map['class']?.toString() ??
        map['targetSection']?.toString() ??
        '';

    final parsedSubject = map['subject']?.toString() ??
        map['targetSubject']?.toString() ??
        map['teacherSubject']?.toString() ??
        '';

    final parsedTargetHour = map['targetHour']?.toString() ??
        map['targetTime']?.toString() ??
        map['scheduleSlot']?.toString() ??
        map['targetSchedule']?.toString() ??
        '';

    return NotificationModel(
      id: (docId ?? map['id'] ?? '').toString(),
      title: map['title']?.toString() ?? 'Notification',
      message: map['message']?.toString() ?? map['body']?.toString() ?? '',
      studentName: map['studentName']?.toString() ?? '',
      className: parsedClassName,
      subject: parsedSubject,
      registeredBy: rawRegisteredBy,
      timestamp: parsedTimestamp,
      notificationType: map['notificationType']?.toString() ?? map['type']?.toString() ?? 'general',
      isRead: map['isRead'] == true,
      studentId: map['studentId']?.toString() ?? '',
      mediaUrl: map['mediaUrl']?.toString() ?? map['attachmentUrl']?.toString() ?? '',
      mediaType: map['mediaType']?.toString() ?? map['attachmentType']?.toString() ?? 'none',
      teacherName: rawTeacherName,
      teacherSubject: rawTeacherSubject,
      teacherId: parsedTeacherId,
      targetHour: parsedTargetHour,
    );
  }

  factory NotificationModel.fromHiveMap(Map<String, dynamic> map) {
    return NotificationModel.fromMap(map, map['id']?.toString());
  }
}
