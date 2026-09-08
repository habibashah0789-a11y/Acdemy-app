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
    // Use a Firestore query filter to only fetch payouts for this teacher.
    // We check both the original document ID (cleanId) and the new Auth UID (authUid)
    // because admin might have recorded the payout using the original doc ID before the teacher logged in.
    final targetIds = <String>{};
    if (cleanId.isNotEmpty) targetIds.add(cleanId);
    if (authUid.isNotEmpty) targetIds.add(authUid);

    Query query = _firestore.collection(_collection);
    if (targetIds.isNotEmpty) {
      query = query.where('teacherId', whereIn: targetIds.toList());
    }

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

  /// Delete an individual payout record and its corresponding notification
  static Future<void> deletePayout(String payoutId) async {
    try {
      final docRef = _firestore.collection(_collection).doc(payoutId);
      final doc = await docRef.get();
      TeacherPayoutModel? payout;
      if (doc.exists && doc.data() != null) {
        payout = TeacherPayoutModel.fromFirestore(doc);
      }

      await docRef.delete();

      // Delete corresponding notification if created
      try {
        await _firestore.collection('notifications').doc('payout_$payoutId').delete();
      } catch (_) {}

      // Log audit action
      try {
        await AuditLogService.logAction(
          actorId: 'ADMIN',
          actorName: 'Administrator',
          actorRole: 'ADMIN',
          action: 'TEACHER_PAYOUT_DELETED',
          transactionId: payoutId,
          details: payout != null
              ? 'Deleted payout record of Rs ${payout.amount.toStringAsFixed(0)} for teacher ${payout.teacherName} (Ref: ${payout.txnRef}).'
              : 'Deleted payout record ($payoutId).',
        );
      } catch (_) {}
    } catch (e) {
      debugPrint('[TeacherPayoutService] deletePayout error: $e');
      rethrow;
    }
  }

  /// Permanently delete all payout records and notifications for a specific teacher only.
  /// All other teachers' payout records are strictly preserved and unaffected.
  static Future<int> deletePayoutsForTeacher({
    required String teacherDocId,
    String? customTeacherId,
    String? teacherEmail,
    String? teacherName,
    String? teacherSubject,
    String? teacherSection,
  }) async {
    try {
      final cleanDocId = teacherDocId.trim();
      final cleanCustomId = (customTeacherId ?? '').trim();
      final cleanEmail = (teacherEmail ?? '').trim().toLowerCase();
      final cleanName = (teacherName ?? '').trim().toLowerCase();
      final cleanSubject = (teacherSubject ?? '').trim().toLowerCase();
      final cleanSection = (teacherSection ?? '').trim().toLowerCase();

      final snapshot = await _firestore.collection(_collection).get();
      final List<DocumentSnapshot> toDelete = [];
      final List<String> deletedPayoutIds = [];

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final pId = (data['teacherId'] ?? '').toString().trim();
        final pEmail = pId.toLowerCase();
        final pName = (data['teacherName'] ?? '').toString().trim().toLowerCase();
        final pSubject = (data['teacherSubject'] ?? '').toString().trim().toLowerCase();
        final pSection = (data['teacherSection'] ?? '').toString().trim().toLowerCase();

        bool isMatch = false;

        // 1. Direct match with doc ID or custom teacher ID
        if (cleanDocId.isNotEmpty && pId == cleanDocId) isMatch = true;
        if (cleanCustomId.isNotEmpty && pId == cleanCustomId) isMatch = true;

        // 2. Email match
        if (!isMatch && cleanEmail.isNotEmpty && (pEmail == cleanEmail || pId.toLowerCase() == cleanEmail)) {
          isMatch = true;
        }

        // 3. Fallback: exact match of Name + Subject + Section for this specific teacher
        if (!isMatch && cleanName.isNotEmpty && cleanSubject.isNotEmpty && cleanSection.isNotEmpty) {
          if (pName == cleanName && pSubject == cleanSubject && pSection == cleanSection) {
            isMatch = true;
          }
        }

        if (isMatch) {
          toDelete.add(doc);
          deletedPayoutIds.add(doc.id);
        }
      }

      if (toDelete.isNotEmpty) {
        // Delete in batch
        final batch = _firestore.batch();
        for (final doc in toDelete) {
          batch.delete(doc.reference);
        }
        await batch.commit();

        // Also delete associated payout notifications
        for (final payoutId in deletedPayoutIds) {
          try {
            await _firestore.collection('notifications').doc('payout_$payoutId').delete();
          } catch (_) {}
        }
      }

      return toDelete.length;
    } catch (e) {
      debugPrint('[TeacherPayoutService] deletePayoutsForTeacher error: $e');
      return 0;
    }
  }
}
