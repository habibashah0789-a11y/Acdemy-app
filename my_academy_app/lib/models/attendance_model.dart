import 'package:cloud_firestore/cloud_firestore.dart';

/// Attendance record model for students and teachers.
/// Supports both Firestore NoSQL and Supabase PostgreSQL schemas.
class AttendanceModel {
  final String id;
  final String studentId;
  final String studentCode;
  final String studentName;
  final String classType;
  final String grade;
  final String subject;
  final String status; // 'present', 'absent', 'late', 'leave'
  final DateTime date;
  final String? remarks;
  final String markedBy; // Teacher ID or 'Admin'

  const AttendanceModel({
    required this.id,
    required this.studentId,
    required this.studentCode,
    required this.studentName,
    required this.classType,
    required this.grade,
    required this.subject,
    required this.status,
    required this.date,
    this.remarks,
    this.markedBy = 'Admin',
  });

  bool get isPresent => status.toLowerCase() == 'present';
  bool get isAbsent => status.toLowerCase() == 'absent';
  bool get isLate => status.toLowerCase() == 'late';
  bool get isLeave => status.toLowerCase() == 'leave';

  // ── Firestore NoSQL Serialization ──
  Map<String, dynamic> toFirestoreMap() {
    return {
      'id': id,
      'studentId': studentId,
      'studentCode': studentCode,
      'studentName': studentName,
      'classType': classType,
      'grade': grade,
      'subject': subject,
      'status': status,
      'date': Timestamp.fromDate(date),
      'remarks': remarks ?? '',
      'markedBy': markedBy,
      'createdAt': Timestamp.fromDate(date),
    };
  }

  factory AttendanceModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    DateTime parsedDate = DateTime.now();
    final rawDate = data['date'] ?? data['createdAt'];
    if (rawDate is Timestamp) {
      parsedDate = rawDate.toDate();
    } else if (rawDate is String) {
      parsedDate = DateTime.tryParse(rawDate) ?? DateTime.now();
    }

    return AttendanceModel(
      id: doc.id,
      studentId: data['studentId']?.toString() ?? '',
      studentCode: data['studentCode']?.toString() ?? '',
      studentName: data['studentName']?.toString() ?? '',
      classType: data['classType']?.toString() ?? 'FSc',
      grade: data['grade']?.toString() ?? '',
      subject: data['subject']?.toString() ?? '',
      status: data['status']?.toString() ?? 'present',
      date: parsedDate,
      remarks: data['remarks']?.toString(),
      markedBy: data['markedBy']?.toString() ?? 'Admin',
    );
  }

  // ── Supabase PostgreSQL Serialization ──
  Map<String, dynamic> toSupabaseMap() {
    return {
      'id': id,
      'student_id': studentId,
      'student_code': studentCode,
      'student_name': studentName,
      'class_type': classType,
      'grade': grade,
      'subject': subject,
      'status': status,
      'attendance_date': date.toIso8601String().split('T').first,
      'remarks': remarks,
      'marked_by': markedBy,
      'created_at': date.toIso8601String(),
    };
  }

  factory AttendanceModel.fromSupabase(Map<String, dynamic> map) {
    return AttendanceModel(
      id: map['id']?.toString() ?? '',
      studentId: map['student_id']?.toString() ?? '',
      studentCode: map['student_code']?.toString() ?? '',
      studentName: map['student_name']?.toString() ?? '',
      classType: map['class_type']?.toString() ?? 'FSc',
      grade: map['grade']?.toString() ?? '',
      subject: map['subject']?.toString() ?? '',
      status: map['status']?.toString() ?? 'present',
      date: DateTime.tryParse(map['attendance_date']?.toString() ?? '') ?? DateTime.now(),
      remarks: map['remarks']?.toString(),
      markedBy: map['marked_by']?.toString() ?? 'Admin',
    );
  }
}
