import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class AuditLogService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'audit_logs';

  static Future<void> logAction({
    required String actorId,
    required String actorName,
    required String actorRole, // ADMIN, STUDENT, TEACHER
    required String action, // e.g. PAYMENT_SUBMITTED, PAYMENT_VERIFIED, PAYMENT_REJECTED
    required String transactionId,
    required String details,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final docRef = _firestore.collection(_collection).doc();
      await docRef.set({
        'id': docRef.id,
        'actorId': actorId,
        'actorName': actorName,
        'actorRole': actorRole,
        'action': action,
        'transactionId': transactionId,
        'details': details,
        'metadata': metadata ?? {},
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('[AuditLogService] Error logging audit action: $e');
    }
  }

  static Stream<List<Map<String, dynamic>>> getAuditLogsStream() {
    return _firestore
        .collection(_collection)
        .orderBy('timestamp', descending: true)
        .limit(100)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    });
  }
}
