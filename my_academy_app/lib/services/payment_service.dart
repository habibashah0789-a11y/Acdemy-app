import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/payment_config_model.dart';
import '../models/payment_transaction_model.dart';
import '../models/student_model.dart';
import 'audit_log_service.dart';
import 'notification_service.dart';

/// Provider Abstraction Layer for Payments
abstract class PaymentProvider {
  String get id;
  String get name;
  Future<PaymentResult> processPayment(PaymentRequest request);
}

class PaymentRequest {
  final String transactionId;
  final String studentId;
  final String studentName;
  final String studentCode;
  final double amount;
  final String currency;
  final String paymentMethod;
  final String providerTransactionId;
  final String description;
  final String? proofUrl;

  PaymentRequest({
    required this.transactionId,
    required this.studentId,
    required this.studentName,
    required this.studentCode,
    required this.amount,
    this.currency = 'PKR',
    required this.paymentMethod,
    required this.providerTransactionId,
    required this.description,
    this.proofUrl,
  });
}

class PaymentResult {
  final bool isInitiated;
  final String status;
  final String providerTransactionId;
  final String message;
  final Map<String, dynamic>? rawResponse;

  PaymentResult({
    required this.isInitiated,
    required this.status,
    required this.providerTransactionId,
    required this.message,
    this.rawResponse,
  });
}

/// Bank Transfer / Manual Provider (Requires Admin Verification)
class BankTransferPaymentProvider implements PaymentProvider {
  @override
  String get id => 'BANK_TRANSFER';
  @override
  String get name => 'Bank Transfer / Manual Upload';

  @override
  Future<PaymentResult> processPayment(PaymentRequest request) async {
    return PaymentResult(
      isInitiated: true,
      status: PaymentTransactionStatus.verificationRequired,
      providerTransactionId: request.providerTransactionId,
      message: 'Bank transfer submitted and pending admin verification.',
    );
  }
}

/// Easypaisa Provider Adapter
class EasypaisaPaymentProvider implements PaymentProvider {
  @override
  String get id => 'EASYPAISA';
  @override
  String get name => 'Easypaisa Mobile Wallet';

  @override
  Future<PaymentResult> processPayment(PaymentRequest request) async {
    // Requires merchant API configuration for automated instant verification.
    // Falls back to manual verification requirement until live API credentials are key-bound.
    return PaymentResult(
      isInitiated: true,
      status: PaymentTransactionStatus.verificationRequired,
      providerTransactionId: request.providerTransactionId,
      message: 'Easypaisa transaction reference submitted for verification.',
    );
  }
}

/// JazzCash Provider Adapter
class JazzCashPaymentProvider implements PaymentProvider {
  @override
  String get id => 'JAZZCASH';
  @override
  String get name => 'JazzCash Mobile Wallet';

  @override
  Future<PaymentResult> processPayment(PaymentRequest request) async {
    return PaymentResult(
      isInitiated: true,
      status: PaymentTransactionStatus.verificationRequired,
      providerTransactionId: request.providerTransactionId,
      message: 'JazzCash transaction reference submitted for verification.',
    );
  }
}

/// Online Gateway Adapter (Clean architecture adapter for merchant API)
class GatewayPaymentProvider implements PaymentProvider {
  @override
  String get id => 'GATEWAY';
  @override
  String get name => 'Online Payment Gateway';

  @override
  Future<PaymentResult> processPayment(PaymentRequest request) async {
    return PaymentResult(
      isInitiated: true,
      status: PaymentTransactionStatus.pending,
      providerTransactionId: request.providerTransactionId,
      message: 'Payment gateway order created. Awaiting payment completion.',
    );
  }
}

/// Core Payment Service managing Firestore Transactions and State Synchronization
class PaymentService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _transactionsCollection = 'payment_transactions';
  static const String _configCollection = 'payment_config';
  static const String _configDocId = 'academy_payment_config';

  static final Map<String, PaymentProvider> _providers = {
    'BANK_TRANSFER': BankTransferPaymentProvider(),
    'EASYPAISA': EasypaisaPaymentProvider(),
    'JAZZCASH': JazzCashPaymentProvider(),
    'GATEWAY': GatewayPaymentProvider(),
  };

  /// Stream Academy Payment Config
  static Stream<PaymentConfigModel> getPaymentConfigStream() {
    return _firestore
        .collection(_configCollection)
        .doc(_configDocId)
        .snapshots()
        .map((doc) => PaymentConfigModel.fromFirestore(doc));
  }

  /// Get Payment Config Once
  static Future<PaymentConfigModel> getPaymentConfigOnce() async {
    try {
      final doc = await _firestore.collection(_configCollection).doc(_configDocId).get();
      return PaymentConfigModel.fromFirestore(doc);
    } catch (_) {
      return PaymentConfigModel.defaultConfig();
    }
  }

  /// Update Payment Config (Admin Only)
  static Future<void> updatePaymentConfig(PaymentConfigModel config, {required String adminName}) async {
    await _firestore.collection(_configCollection).doc(_configDocId).set(config.toMap(), SetOptions(merge: true));
    await AuditLogService.logAction(
      actorId: 'ADMIN',
      actorName: adminName,
      actorRole: 'ADMIN',
      action: 'PAYMENT_CONFIG_UPDATED',
      transactionId: 'CONFIG',
      details: 'Updated academy bank details and active payment methods.',
    );
  }

  /// Submit Student Fee Payment
  static Future<PaymentTransactionModel> submitStudentFeePayment({
    required StudentModel student,
    required double amount,
    required String paymentMethod,
    required String providerName,
    required String providerTransactionId,
    required String description,
    String? proofUrl,
  }) async {
    final cleanRef = providerTransactionId.trim();

    // 1. Prevent duplicate submission check
    final existingCheck = await _firestore
        .collection(_transactionsCollection)
        .where('studentId', isEqualTo: student.id)
        .where('providerTransactionId', isEqualTo: cleanRef)
        .get();

    if (existingCheck.docs.isNotEmpty) {
      throw Exception('A transaction with reference ID "$cleanRef" has already been submitted.');
    }

    final docRef = _firestore.collection(_transactionsCollection).doc();
    final txnId = docRef.id;

    final provider = _providers[paymentMethod] ?? BankTransferPaymentProvider();
    final request = PaymentRequest(
      transactionId: txnId,
      studentId: student.id,
      studentName: '${student.firstName} ${student.lastName}'.trim(),
      studentCode: student.storedStudentCode ?? student.id,
      amount: amount,
      paymentMethod: paymentMethod,
      providerTransactionId: cleanRef,
      description: description,
      proofUrl: proofUrl,
    );

    final result = await provider.processPayment(request);

    final transaction = PaymentTransactionModel(
      transactionId: txnId,
      studentId: student.id,
      studentName: '${student.firstName} ${student.lastName}'.trim(),
      studentCode: student.storedStudentCode ?? student.id,
      payerId: student.id,
      payerName: '${student.firstName} ${student.lastName}'.trim(),
      payerRole: 'STUDENT',
      receiverId: 'ACADEMY',
      receiverName: 'Quaid Academy',
      receiverRole: 'ACADEMY',
      amount: amount,
      currency: 'PKR',
      paymentMethod: paymentMethod,
      provider: providerName,
      providerTransactionId: cleanRef,
      status: result.status,
      purpose: PaymentPurpose.feePayment,
      description: description,
      proofUrl: proofUrl,
      createdAt: DateTime.now(),
    );

    await docRef.set(transaction.toMap());

    // Send Notification to Admin
    try {
      await NotificationService.createFeePaymentNotification(
        student: student,
        amount: amount,
      );
    } catch (e) {
      debugPrint('[PaymentService] Error sending admin notification: $e');
    }

    // Log Audit
    await AuditLogService.logAction(
      actorId: student.id,
      actorName: '${student.firstName} ${student.lastName}',
      actorRole: 'STUDENT',
      action: 'PAYMENT_SUBMITTED',
      transactionId: txnId,
      details: 'Submitted Rs $amount via $providerName (Ref: $cleanRef).',
      metadata: {'status': result.status, 'paymentMethod': paymentMethod},
    );

    return transaction;
  }

  /// Admin Verifies and Approves Manual / Pending Payment
  static Future<void> verifyPaymentByAdmin({
    required String transactionId,
    required String adminName,
  }) async {
    final txnRef = _firestore.collection(_transactionsCollection).doc(transactionId);

    await _firestore.runTransaction((transaction) async {
      final txnSnapshot = await transaction.get(txnRef);
      if (!txnSnapshot.exists) {
        throw Exception('Transaction record not found.');
      }

      final txnData = PaymentTransactionModel.fromFirestore(txnSnapshot);
      if (txnData.status == PaymentTransactionStatus.successful) {
        throw Exception('Transaction has already been verified and processed.');
      }

      final studentId = txnData.studentId;
      if (studentId == null || studentId.isEmpty) {
        throw Exception('No student associated with this transaction.');
      }

      final studentRef = _firestore.collection('students').doc(studentId);
      final studentSnapshot = await transaction.get(studentRef);

      if (!studentSnapshot.exists) {
        throw Exception('Associated student record not found in Firestore.');
      }

      final currentStudent = StudentModel.fromFirestore(studentSnapshot);

      // Compute updated fee numbers
      final double paymentAmount = txnData.amount;
      final double newSubmitted = currentStudent.feeSubmitted + paymentAmount;
      final double newRemaining = (currentStudent.feeRemaining - paymentAmount).clamp(0.0, double.infinity);

      // Parse existing payment history JSON
      List<dynamic> historyList = [];
      if (currentStudent.paymentHistoryJson != null && currentStudent.paymentHistoryJson!.isNotEmpty) {
        try {
          historyList = jsonDecode(currentStudent.paymentHistoryJson!) as List;
        } catch (_) {}
      }

      historyList.insert(0, {
        'amount': paymentAmount,
        'date': DateTime.now().toIso8601String(),
        'note': 'Verified Payment (Ref: ${txnData.providerTransactionId}) - ${txnData.description}',
        'txnId': transactionId,
        'paymentMethod': txnData.paymentMethod,
      });

      // Update Student Document
      transaction.update(studentRef, {
        'feeSubmitted': newSubmitted,
        'feeRemaining': newRemaining,
        'paymentHistoryJson': jsonEncode(historyList),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update Transaction Document
      transaction.update(txnRef, {
        'status': PaymentTransactionStatus.successful,
        'verifiedAt': FieldValue.serverTimestamp(),
        'verifiedBy': adminName,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });

    // Fetch updated transaction info for notifications
    final updatedTxnDoc = await txnRef.get();
    final updatedTxn = PaymentTransactionModel.fromFirestore(updatedTxnDoc);

    // Send Notification to Student
    try {
      if (updatedTxn.studentId != null) {
        await _firestore.collection('notifications').doc('pay_ver_${updatedTxn.transactionId}').set({
          'id': 'pay_ver_${updatedTxn.transactionId}',
          'title': '✅ Fee Payment Verified: Rs ${updatedTxn.amount.toStringAsFixed(0)}',
          'message': 'Your fee payment of Rs ${updatedTxn.amount.toStringAsFixed(0)} (Ref: ${updatedTxn.providerTransactionId}) has been verified and credited by $adminName.',
          'studentName': updatedTxn.studentName,
          'registeredBy': adminName,
          'timestamp': FieldValue.serverTimestamp(),
          'notificationType': 'fee_payment_verified',
          'isRead': false,
          'targetStudentId': updatedTxn.studentId,
        });
      }
    } catch (e) {
      debugPrint('[PaymentService] Error sending verification notification: $e');
    }

    // Log Audit Action
    await AuditLogService.logAction(
      actorId: 'ADMIN',
      actorName: adminName,
      actorRole: 'ADMIN',
      action: 'PAYMENT_VERIFIED',
      transactionId: transactionId,
      details: 'Verified payment of Rs ${updatedTxn.amount} for student ${updatedTxn.studentName}.',
    );
  }

  /// Admin Rejects Manual / Pending Payment
  static Future<void> rejectPaymentByAdmin({
    required String transactionId,
    required String adminName,
    required String failureReason,
  }) async {
    final txnRef = _firestore.collection(_transactionsCollection).doc(transactionId);
    final doc = await txnRef.get();
    if (!doc.exists) throw Exception('Transaction record not found.');

    final txn = PaymentTransactionModel.fromFirestore(doc);

    await txnRef.update({
      'status': PaymentTransactionStatus.rejected,
      'failureReason': failureReason,
      'verifiedAt': FieldValue.serverTimestamp(),
      'verifiedBy': adminName,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Send Notification to Student
    try {
      if (txn.studentId != null) {
        await _firestore.collection('notifications').doc('pay_rej_${txn.transactionId}').set({
          'id': 'pay_rej_${txn.transactionId}',
          'title': '❌ Fee Payment Rejected',
          'message': 'Payment ref: ${txn.providerTransactionId} for Rs ${txn.amount.toStringAsFixed(0)} was rejected by administration.\nReason: $failureReason',
          'studentName': txn.studentName,
          'registeredBy': adminName,
          'timestamp': FieldValue.serverTimestamp(),
          'notificationType': 'fee_payment_rejected',
          'isRead': false,
          'targetStudentId': txn.studentId,
        });
      }
    } catch (e) {
      debugPrint('[PaymentService] Error sending rejection notification: $e');
    }

    // Log Audit Action
    await AuditLogService.logAction(
      actorId: 'ADMIN',
      actorName: adminName,
      actorRole: 'ADMIN',
      action: 'PAYMENT_REJECTED',
      transactionId: transactionId,
      details: 'Rejected payment ref ${txn.providerTransactionId}. Reason: $failureReason',
    );
  }

  /// Stream Student Transactions
  static Stream<List<PaymentTransactionModel>> getStudentTransactionsStream(String studentId) {
    if (studentId.isEmpty) return Stream.value([]);
    return _firestore
        .collection(_transactionsCollection)
        .where('studentId', isEqualTo: studentId)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs.map((d) => PaymentTransactionModel.fromFirestore(d)).toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  /// Stream All Transactions (Admin Only)
  static Stream<List<PaymentTransactionModel>> getAllTransactionsStream() {
    return _firestore
        .collection(_transactionsCollection)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs.map((d) => PaymentTransactionModel.fromFirestore(d)).toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }
}
