import 'package:cloud_firestore/cloud_firestore.dart';

class PaymentTransactionStatus {
  static const String pending = 'pending';
  static const String processing = 'processing';
  static const String successful = 'successful';
  static const String failed = 'failed';
  static const String cancelled = 'cancelled';
  static const String refunded = 'refunded';
  static const String verificationRequired = 'verification_required';
  static const String rejected = 'rejected';
}

class PaymentPurpose {
  static const String feePayment = 'FEE_PAYMENT';
  static const String teacherSalary = 'TEACHER_SALARY';
  static const String feeRefund = 'FEE_REFUND';
  static const String other = 'OTHER';
}

class PaymentTransactionModel {
  final String transactionId;
  final String? studentId;
  final String? studentName;
  final String? studentCode;
  final String? teacherId;
  final String? teacherName;
  final String? adminId;
  final String? adminName;
  final String payerId;
  final String payerName;
  final String payerRole; // STUDENT, ADMIN, TEACHER
  final String receiverId;
  final String receiverName;
  final String receiverRole; // ACADEMY, TEACHER, STUDENT
  final double amount;
  final String currency; // PKR
  final String paymentMethod; // BANK_TRANSFER, EASYPAISA, JAZZCASH, GATEWAY
  final String provider; // e.g. "Meezan Bank", "Easypaisa", "JazzCash"
  final String providerTransactionId; // Reference or transaction ID
  final String status; // pending, processing, successful, failed, cancelled, refunded, verification_required, rejected
  final String purpose; // FEE_PAYMENT, TEACHER_SALARY, etc.
  final String description;
  final String? proofUrl;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? verifiedAt;
  final String? verifiedBy;
  final String? failureReason;

  PaymentTransactionModel({
    required this.transactionId,
    this.studentId,
    this.studentName,
    this.studentCode,
    this.teacherId,
    this.teacherName,
    this.adminId,
    this.adminName,
    required this.payerId,
    required this.payerName,
    required this.payerRole,
    required this.receiverId,
    required this.receiverName,
    required this.receiverRole,
    required this.amount,
    this.currency = 'PKR',
    required this.paymentMethod,
    required this.provider,
    required this.providerTransactionId,
    required this.status,
    required this.purpose,
    required this.description,
    this.proofUrl,
    DateTime? createdAt,
    this.updatedAt,
    this.verifiedAt,
    this.verifiedBy,
    this.failureReason,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'transactionId': transactionId,
      'studentId': studentId,
      'studentName': studentName,
      'studentCode': studentCode,
      'teacherId': teacherId,
      'teacherName': teacherName,
      'adminId': adminId,
      'adminName': adminName,
      'payerId': payerId,
      'payerName': payerName,
      'payerRole': payerRole,
      'receiverId': receiverId,
      'receiverName': receiverName,
      'receiverRole': receiverRole,
      'amount': amount,
      'currency': currency,
      'paymentMethod': paymentMethod,
      'provider': provider,
      'providerTransactionId': providerTransactionId,
      'status': status,
      'purpose': purpose,
      'description': description,
      'proofUrl': proofUrl,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : FieldValue.serverTimestamp(),
      'verifiedAt': verifiedAt != null ? Timestamp.fromDate(verifiedAt!) : null,
      'verifiedBy': verifiedBy,
      'failureReason': failureReason,
    };
  }

  factory PaymentTransactionModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    
    DateTime parseDate(dynamic field) {
      if (field is Timestamp) return field.toDate();
      if (field is String) return DateTime.tryParse(field) ?? DateTime.now();
      return DateTime.now();
    }

    return PaymentTransactionModel(
      transactionId: doc.id,
      studentId: data['studentId'] as String?,
      studentName: data['studentName'] as String?,
      studentCode: data['studentCode'] as String?,
      teacherId: data['teacherId'] as String?,
      teacherName: data['teacherName'] as String?,
      adminId: data['adminId'] as String?,
      adminName: data['adminName'] as String?,
      payerId: data['payerId'] as String? ?? '',
      payerName: data['payerName'] as String? ?? 'Unknown',
      payerRole: data['payerRole'] as String? ?? 'STUDENT',
      receiverId: data['receiverId'] as String? ?? 'ACADEMY',
      receiverName: data['receiverName'] as String? ?? 'Quaid Academy',
      receiverRole: data['receiverRole'] as String? ?? 'ACADEMY',
      amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
      currency: data['currency'] as String? ?? 'PKR',
      paymentMethod: data['paymentMethod'] as String? ?? 'BANK_TRANSFER',
      provider: data['provider'] as String? ?? 'Bank Transfer',
      providerTransactionId: data['providerTransactionId'] as String? ?? '',
      status: data['status'] as String? ?? PaymentTransactionStatus.pending,
      purpose: data['purpose'] as String? ?? PaymentPurpose.feePayment,
      description: data['description'] as String? ?? '',
      proofUrl: data['proofUrl'] as String?,
      createdAt: parseDate(data['createdAt']),
      updatedAt: data['updatedAt'] != null ? parseDate(data['updatedAt']) : null,
      verifiedAt: data['verifiedAt'] != null ? parseDate(data['verifiedAt']) : null,
      verifiedBy: data['verifiedBy'] as String?,
      failureReason: data['failureReason'] as String?,
    );
  }
}
