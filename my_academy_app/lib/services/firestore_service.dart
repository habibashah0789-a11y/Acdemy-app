import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'firebase_service.dart';

/// Centralized Firestore service for real-time streams, CRUD, queries, and batch writes.
class FirestoreService {
  static FirebaseFirestore get instance => FirebaseFirestore.instance;

  // ── Collection References ──
  static CollectionReference<Map<String, dynamic>> get studentsCol =>
      instance.collection('students');
  static CollectionReference<Map<String, dynamic>> get teachersCol =>
      instance.collection('teachers');
  static CollectionReference<Map<String, dynamic>> get feesCol =>
      instance.collection('fee_transactions');
  static CollectionReference<Map<String, dynamic>> get attendanceCol =>
      instance.collection('attendance');
  static CollectionReference<Map<String, dynamic>> get notificationsCol =>
      instance.collection('notifications');

  // ── Real-Time Streams ──
  static Stream<QuerySnapshot<Map<String, dynamic>>> getStudentsStream() {
    if (!FirebaseService.isAuthenticated) return const Stream.empty();
    return studentsCol.orderBy('createdAt', descending: true).snapshots();
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> getTeachersStream() {
    if (!FirebaseService.isAuthenticated) return const Stream.empty();
    return teachersCol.orderBy('createdAt', descending: true).snapshots();
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> getFeeTransactionsStream({String? studentId}) {
    if (!FirebaseService.isAuthenticated) return const Stream.empty();
    Query<Map<String, dynamic>> query = feesCol.orderBy('date', descending: true);
    if (studentId != null && studentId.isNotEmpty) {
      query = query.where('studentId', isEqualTo: studentId);
    }
    return query.snapshots();
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> getAttendanceStream({
    required DateTime date,
    String? classType,
    String? grade,
  }) {
    if (!FirebaseService.isAuthenticated) return const Stream.empty();
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

    Query<Map<String, dynamic>> query = attendanceCol
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay));

    if (classType != null && classType.isNotEmpty) {
      query = query.where('classType', isEqualTo: classType);
    }
    if (grade != null && grade.isNotEmpty) {
      query = query.where('grade', isEqualTo: grade);
    }

    return query.snapshots();
  }

  // ── Generic Document CRUD ──
  static Future<void> setDoc({
    required String collection,
    required String docId,
    required Map<String, dynamic> data,
    bool merge = true,
  }) async {
    try {
      await instance.collection(collection).doc(docId).set(data, SetOptions(merge: merge));
    } catch (e) {
      debugPrint('[FIRESTORE SERVICE] setDoc error ($collection/$docId): $e');
      rethrow;
    }
  }

  static Future<void> updateDoc({
    required String collection,
    required String docId,
    required Map<String, dynamic> data,
  }) async {
    try {
      await instance.collection(collection).doc(docId).update(data);
    } catch (e) {
      debugPrint('[FIRESTORE SERVICE] updateDoc error ($collection/$docId): $e');
      rethrow;
    }
  }

  static Future<void> deleteDoc({
    required String collection,
    required String docId,
  }) async {
    try {
      await instance.collection(collection).doc(docId).delete();
    } catch (e) {
      debugPrint('[FIRESTORE SERVICE] deleteDoc error ($collection/$docId): $e');
      rethrow;
    }
  }

  static Future<DocumentSnapshot<Map<String, dynamic>>?> getDoc({
    required String collection,
    required String docId,
  }) async {
    try {
      return await instance.collection(collection).doc(docId).get();
    } catch (e) {
      debugPrint('[FIRESTORE SERVICE] getDoc error ($collection/$docId): $e');
      return null;
    }
  }
}
