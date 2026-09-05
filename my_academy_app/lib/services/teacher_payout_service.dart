import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/teacher_payout_model.dart';
import 'audit_log_service.dart';
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

    // Log Audit action
    try {
      await AuditLogService.logAction(
        actorId: 'ADMIN',
        actorName: adminName,
        actorRole: 'ADMIN',
        action: 'TEACHER_PAYOUT_CREATED',
        transactionId: payout.id,
        details: 'Recorded payout of Rs ${amount.toStringAsFixed(0)} for teacher $teacherName ($teacherSubject - $teacherSection). Note: $reason',
      );
    } catch (e) {
      debugPrint('[TeacherPayoutService] Error logging audit action: $e');
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

  /// Stream payouts specifically targeted to a given teacherId / email / name / auth user
  static Stream<List<TeacherPayoutModel>> getTeacherPayoutsStream(
    String teacherId, {
    String? teacherEmail,
    String? teacherName,
    String? teacherSubject,
    String? teacherSection,
  }) {
    final cleanId = teacherId.trim();
    final cleanEmail = (teacherEmail ?? '').trim().toLowerCase();
    final cleanName = (teacherName ?? '').trim().toLowerCase();
    final cleanSubject = (teacherSubject ?? '').trim().toLowerCase();
    final cleanSection = (teacherSection ?? '').trim().toLowerCase();

    final authUser = FirebaseAuth.instance.currentUser;
    final authUid = authUser?.uid ?? '';
    final authEmail = (authUser?.email ?? '').trim().toLowerCase();

    // Use a Firestore query filter to only fetch payouts for this teacher.
    // We use a client-side filter instead of a strict Firestore `where` query.
    // This allows the fallback name/subject/section matching to work,
    // solving the issue where the teacher's Auth UID changed from the original doc ID.
    Query query = _firestore.collection(_collection);

    return query.snapshots().map((snapshot) {
      final list = snapshot.docs
          .map((doc) => TeacherPayoutModel.fromFirestore(doc))
          .where((p) {
            final pId = p.teacherId.trim();
            final pEmail = p.teacherId.trim().toLowerCase();
            final pName = p.teacherName.trim().toLowerCase();
            final pSubject = p.teacherSubject.trim().toLowerCase();
            final pSection = p.teacherSection.trim().toLowerCase();

            // 1. Direct ID / Auth UID match
            if (cleanId.isNotEmpty && pId == cleanId) return true;
            if (authUid.isNotEmpty && pId == authUid) return true;

            // 2. Email match
            if (cleanEmail.isNotEmpty && (pEmail == cleanEmail || p.teacherId.toLowerCase() == cleanEmail)) return true;
            if (authEmail.isNotEmpty && (pEmail == authEmail || p.teacherId.toLowerCase() == authEmail)) return true;

            // 3. Name match (exact or substring)
            if (cleanName.isNotEmpty && pName.isNotEmpty) {
              if (pName == cleanName || pName.contains(cleanName) || cleanName.contains(pName)) return true;
            }

            // 4. Subject + Section match fallback
            if (cleanSubject.isNotEmpty && cleanSection.isNotEmpty && pSubject.isNotEmpty && pSection.isNotEmpty) {
              if (pSubject == cleanSubject && pSection == cleanSection) return true;
            }

            return false;
          })
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
