import 'package:cloud_firestore/cloud_firestore.dart';

/// Fee transaction and payment record model.
/// Supports both Firestore NoSQL and Supabase PostgreSQL formats.
class FeeModel {
  final String id;
  final String studentId;
  final String studentCode;
  final String studentName;
  final double amount;
  final double remainingAfter;
  final String subject;
  final String classType;
  final String grade;
  final String paymentMethod; // 'Cash', 'Bank Transfer', 'Online', etc.
  final String? receiptNo;
  final String? note;
  final DateTime date;
  final String recordedBy; // Admin or Teacher ID

  const FeeModel({
    required this.id,
    required this.studentId,
    required this.studentCode,
    required this.studentName,
    required this.amount,
    required this.remainingAfter,
    required this.subject,
    required this.classType,
    required this.grade,
    this.paymentMethod = 'Cash',
    this.receiptNo,
    this.note,
    required this.date,
    this.recordedBy = 'Admin',
  });

  // ── Firestore NoSQL Serialization ──
  Map<String, dynamic> toFirestoreMap() {
    return {
      'id': id,
      'studentId': studentId,
      'studentCode': studentCode,
      'studentName': studentName,
      'amount': amount,
      'remainingAfter': remainingAfter,
      'subject': subject,
      'classType': classType,
      'grade': grade,
      'paymentMethod': paymentMethod,
      'receiptNo': receiptNo ?? '',
      'note': note ?? '',
      'date': Timestamp.fromDate(date),
      'recordedBy': recordedBy,
      'createdAt': Timestamp.fromDate(date),
    };
  }

  factory FeeModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    DateTime parsedDate = DateTime.now();
    final rawDate = data['date'] ?? data['createdAt'];
    if (rawDate is Timestamp) {
      parsedDate = rawDate.toDate();
    } else if (rawDate is String) {
      parsedDate = DateTime.tryParse(rawDate) ?? DateTime.now();
    }

    return FeeModel(
      id: doc.id,
      studentId: data['studentId']?.toString() ?? '',
      studentCode: data['studentCode']?.toString() ?? '',
      studentName: data['studentName']?.toString() ?? '',
      amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
      remainingAfter: (data['remainingAfter'] as num?)?.toDouble() ?? 0.0,
      subject: data['subject']?.toString() ?? '',
      classType: data['classType']?.toString() ?? 'FSc',
      grade: data['grade']?.toString() ?? '',
      paymentMethod: data['paymentMethod']?.toString() ?? 'Cash',
      receiptNo: data['receiptNo']?.toString(),
      note: data['note']?.toString(),
      date: parsedDate,
      recordedBy: data['recordedBy']?.toString() ?? 'Admin',
    );
  }

  // ── Supabase PostgreSQL Serialization ──
  Map<String, dynamic> toSupabaseMap() {
    return {
      'id': id,
      'student_id': studentId,
      'student_code': studentCode,
      'student_name': studentName,
      'amount': amount,
      'remaining_after': remainingAfter,
      'subject': subject,
      'class_type': classType,
      'grade': grade,
      'payment_method': paymentMethod,
      'receipt_no': receiptNo,
      'note': note,
      'payment_date': date.toIso8601String(),
      'recorded_by': recordedBy,
      'created_at': date.toIso8601String(),
    };
  }

  factory FeeModel.fromSupabase(Map<String, dynamic> map) {
    return FeeModel(
      id: map['id']?.toString() ?? '',
      studentId: map['student_id']?.toString() ?? '',
      studentCode: map['student_code']?.toString() ?? '',
      studentName: map['student_name']?.toString() ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      remainingAfter: (map['remaining_after'] as num?)?.toDouble() ?? 0.0,
      subject: map['subject']?.toString() ?? '',
      classType: map['class_type']?.toString() ?? 'FSc',
      grade: map['grade']?.toString() ?? '',
      paymentMethod: map['payment_method']?.toString() ?? 'Cash',
      receiptNo: map['receipt_no']?.toString(),
      note: map['note']?.toString(),
      date: DateTime.tryParse(map['payment_date']?.toString() ?? '') ?? DateTime.now(),
      recordedBy: map['recorded_by']?.toString() ?? 'Admin',
    );
  }
}
