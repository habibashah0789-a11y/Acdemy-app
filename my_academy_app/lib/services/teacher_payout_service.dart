import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/teacher_payout_model.dart';
import 'notification_service.dart';

class TeacherPayoutService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'teacher_payouts';

  /// Generate a unique, bank-style reference ID
  static String generateTxnRef() {
    final now = DateTime.now();
    final year = now.year.toString();
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    final randomSuffix = (1000 + (now.microsecondsSinceEpoch % 9000)).toString();
    return 'TXN-$year$month$day-$randomSuffix';
  }

  /// Create a payout transaction record and dispatch targeted notification
  static Future<TeacherPayoutModel> recordPayout({
    required String teacherId,
    required String teacherName,
    required String teacherSubject,
    required String teacherSection,
    required double amount,
    required String reason,
    required DateTime paymentDate,
    required String adminName,
  }) async {
    final docRef = _firestore.collection(_collection).doc();
    final txnRef = generateTxnRef();

    final payout = TeacherPayoutModel(
      id: docRef.id,
      txnRef: txnRef,
      teacherId: teacherId,
      teacherName: teacherName,
      teacherSubject: teacherSubject,
      teacherSection: teacherSection,
      amount: amount,
      reason: reason,
      paymentDate: paymentDate,
      adminName: adminName,
      status: 'COMPLETED',
      createdAt: DateTime.now(),
    );

    // Save to Firestore
    await docRef.set(payout.toMap());

    // Dispatch targeted notification to teacher
    try {
      await _dispatchPayoutNotification(payout);
    } catch (e) {
      debugPrint('[TeacherPayoutService] Error sending payout notification: $e');
    }

    return payout;
  }

  /// Helper to send targeted notification to the specific teacher
  static Future<void> _dispatchPayoutNotification(TeacherPayoutModel payout) async {
    final noticeId = 'payout_${payout.id}';
    final amountFormatted = payout.amount.toStringAsFixed(0);
    final dateFormatted =
        '${payout.paymentDate.day}/${payout.paymentDate.month}/${payout.paymentDate.year}';

    final noticeData = {
      'id': noticeId,
      'title': '💵 Payment Received: Rs $amountFormatted',
      'message':
          'Payment of Rs $amountFormatted credited by ${payout.adminName}.\n'
          'Ref: ${payout.txnRef}\n'
          'Reason: ${payout.reason}\n'
          'Date: $dateFormatted',
      'studentName': payout.teacherName, // Reuse field for recipient display
      'className': payout.teacherSection,
      'subject': payout.teacherSubject,
      'registeredBy': payout.adminName,
      'timestamp': FieldValue.serverTimestamp(),
      'notificationType': 'teacher_payout',
      'isRead': false,
      'teacherId': payout.teacherId, // Targeted teacher ID
      'txnRef': payout.txnRef,
      'amount': payout.amount,
      'reason': payout.reason,
    };

    // Save to global notifications collection with targeted teacherId
    await _firestore.collection('notifications').doc(noticeId).set(noticeData);

    // Also trigger FCM Push Notification target if token exists
    try {
      await NotificationService.triggerPushNotification(
        targetUserId: payout.teacherId,
        targetTopic: 'teacher_${payout.teacherId}',
        title: '💵 Payment Received: Rs $amountFormatted',
        body: 'Ref: ${payout.txnRef} - ${payout.reason}',
        payload: {
          'type': 'teacher_payout',
          'payoutId': payout.id,
          'teacherId': payout.teacherId,
        },
      );
    } catch (e) {
      debugPrint('[TeacherPayoutService] FCM push trigger note: $e');
    }
  }

  /// Stream payouts specifically targeted to a given teacherId
  static Stream<List<TeacherPayoutModel>> getTeacherPayoutsStream(String teacherId) {
    if (teacherId.isEmpty) {
      return Stream.value([]);
    }

    return _firestore
        .collection(_collection)
        .where('teacherId', isEqualTo: teacherId)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs
          .map((doc) => TeacherPayoutModel.fromFirestore(doc))
          .toList();
      // Sort descending by paymentDate
      list.sort((a, b) => b.paymentDate.compareTo(a.paymentDate));
      return list;
    });
  }

  /// Stream all payout history for Admin audit log
  static Stream<List<TeacherPayoutModel>> getAllPayoutsStream() {
    return _firestore.collection(_collection).snapshots().map((snapshot) {
      final list = snapshot.docs
          .map((doc) => TeacherPayoutModel.fromFirestore(doc))
          .toList();
      list.sort((a, b) => b.paymentDate.compareTo(a.paymentDate));
      return list;
    });
  }
}
