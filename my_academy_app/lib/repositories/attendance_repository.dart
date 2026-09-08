import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/attendance_model.dart';
import '../services/firestore_service.dart';
import '../services/supabase_service.dart';

/// Repository for Student and Teacher Attendance.
/// Combines Firestore Realtime Streams with Supabase SQL Attendance Analytics.
class AttendanceRepository {
  /// Mark attendance for a single student
  static Future<bool> markAttendance(AttendanceModel attendance) async {
    try {
      // 1. Write to Firestore 'attendance' collection
      await FirestoreService.setDoc(
        collection: 'attendance',
        docId: attendance.id,
        data: attendance.toFirestoreMap(),
      );

      // 2. Non-blocking Supabase PostgreSQL Sync
      unawaited(() async {
        try {
          await SupabaseService.syncAttendanceToSupabase(attendance.toSupabaseMap());
        } catch (e) {
          debugPrint('[ATTENDANCE REPO] Supabase sync error: $e');
        }
      }());

      return true;
    } catch (e) {
      debugPrint('[ATTENDANCE REPO] markAttendance error: $e');
      return false;
    }
  }

  /// Mark bulk attendance for a class session
  static Future<bool> markBulkAttendance(List<AttendanceModel> records) async {
    try {
      final batch = FirestoreService.instance.batch();
      for (final r in records) {
        final docRef = FirestoreService.attendanceCol.doc(r.id);
        batch.set(docRef, r.toFirestoreMap(), SetOptions(merge: true));
      }
      await batch.commit();

      // Background Supabase Sync
      unawaited(() async {
        for (final r in records) {
          try {
            await SupabaseService.syncAttendanceToSupabase(r.toSupabaseMap());
          } catch (_) {}
        }
      }());

      return true;
    } catch (e) {
      debugPrint('[ATTENDANCE REPO] markBulkAttendance error: $e');
      return false;
    }
  }

  /// Realtime Stream of Daily Attendance
  static Stream<QuerySnapshot<Map<String, dynamic>>> getDailyAttendanceStream({
    required DateTime date,
    String? classType,
    String? grade,
  }) {
    return FirestoreService.getAttendanceStream(
      date: date,
      classType: classType,
      grade: grade,
    );
  }

  /// Get attendance percentage summary for a student from Supabase SQL
  static Future<Map<String, dynamic>> getStudentAttendanceStats(String studentId) {
    return SupabaseService.getStudentAttendanceStats(studentId);
  }
}
