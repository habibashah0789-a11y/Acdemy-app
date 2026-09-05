import 'package:cloud_firestore/cloud_firestore.dart';

class TeacherPayoutModel {
  final String id;
  final String txnRef;
  final String teacherId;
  final String teacherName;
  final String teacherSubject;
  final String teacherSection;
  final double amount;
  final String reason;
  final DateTime paymentDate;
  final String adminName;
  final String status;
  final DateTime createdAt;

  const TeacherPayoutModel({
    required this.id,
    required this.txnRef,
    required this.teacherId,
    required this.teacherName,
    required this.teacherSubject,
    required this.teacherSection,
    required this.amount,
    required this.reason,
    required this.paymentDate,
    required this.adminName,
    this.status = 'COMPLETED',
    required this.createdAt,
  });

  factory TeacherPayoutModel.fromMap(Map<String, dynamic> map, String docId) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    return TeacherPayoutModel(
      id: docId,
      txnRef: map['txnRef'] ?? 'TXN-${docId.take(8).toUpperCase()}',
      teacherId: map['teacherId'] ?? '',
      teacherName: map['teacherName'] ?? '',
      teacherSubject: map['teacherSubject'] ?? '',
      teacherSection: map['teacherSection'] ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      reason: map['reason'] ?? '',
      paymentDate: parseDate(map['paymentDate']),
      adminName: map['adminName'] ?? 'Admin',
      status: map['status'] ?? 'COMPLETED',
      createdAt: parseDate(map['createdAt']),
    );
  }

  factory TeacherPayoutModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) {
      return TeacherPayoutModel(
        id: doc.id,
        txnRef: '',
        teacherId: '',
        teacherName: '',
        teacherSubject: '',
        teacherSection: '',
        amount: 0,
        reason: '',
        paymentDate: DateTime.now(),
        adminName: 'Admin',
        createdAt: DateTime.now(),
      );
    }
    return TeacherPayoutModel.fromMap(data, doc.id);
  }

  Map<String, dynamic> toMap() {
    return {
      'txnRef': txnRef,
      'teacherId': teacherId,
      'teacherName': teacherName,
      'teacherSubject': teacherSubject,
      'teacherSection': teacherSection,
      'amount': amount,
      'reason': reason,
      'paymentDate': Timestamp.fromDate(paymentDate),
      'adminName': adminName,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  TeacherPayoutModel copyWith({
    String? id,
    String? txnRef,
    String? teacherId,
    String? teacherName,
    String? teacherSubject,
    String? teacherSection,
    double? amount,
    String? reason,
    DateTime? paymentDate,
    String? adminName,
    String? status,
    DateTime? createdAt,
  }) {
    return TeacherPayoutModel(
      id: id ?? this.id,
      txnRef: txnRef ?? this.txnRef,
      teacherId: teacherId ?? this.teacherId,
      teacherName: teacherName ?? this.teacherName,
      teacherSubject: teacherSubject ?? this.teacherSubject,
      teacherSection: teacherSection ?? this.teacherSection,
      amount: amount ?? this.amount,
      reason: reason ?? this.reason,
      paymentDate: paymentDate ?? this.paymentDate,
      adminName: adminName ?? this.adminName,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

extension StringTakeExtension on String {
  String take(int n) {
    if (length <= n) return this;
    return substring(0, n);
  }
}
