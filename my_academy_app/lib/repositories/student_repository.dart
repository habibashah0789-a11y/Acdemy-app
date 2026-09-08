import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/student_model.dart';
import '../services/database_service.dart';
import '../services/firestore_service.dart';
import '../services/supabase_service.dart';
import '../services/notification_service.dart';

/// Repository for Student Data.
/// Bridges Local Hive Cache, Firestore Realtime Database, and Supabase SQL Replication.
class StudentRepository {
  // ── 1. Read Operations ──

  /// Get all students from local Hive database (<1ms)
  static List<StudentModel> getStudentsLocal() {
    return DatabaseService.getAllStudentsLocal();
  }

  /// Get a single student by ID (Hive first, fallback to Firestore)
  static Future<StudentModel?> getStudentById(String id) async {
    return DatabaseService.getStudentById(id);
  }

  /// Realtime Stream of Students from Firestore
  static Stream<QuerySnapshot<Map<String, dynamic>>> getStudentsStream() {
    return FirestoreService.getStudentsStream();
  }

  // ── 2. Write Operations (Hybrid Dual-Write) ──

  /// Save / Add a new Student (Local Hive + Firestore Cloud + Supabase Replication)
  static Future<bool> addStudent(StudentModel student) async {
    try {
      // 1. Instant local Hive put
      await DatabaseService.addStudent(student);

      // 2. Non-blocking Supabase PostgreSQL Replication
      unawaited(() async {
        try {
          await SupabaseService.syncStudentToSupabase({
            'id': student.id,
            'student_code': student.studentCode,
            'first_name': student.firstName,
            'last_name': student.lastName,
            'father_name': student.fatherName,
            'phone': student.phone,
            'email': student.email,
            'class_type': student.classType,
            'grade': student.grade,
            'subject': student.subject,
            'fee_submitted': student.feeSubmitted,
            'fee_remaining': student.feeRemaining,
            'profile_pic_url': student.profilePicUrl,
            'enrollment_status': student.enrollmentStatus,
            'is_active': student.isActive,
            'created_at': student.createdAt.toIso8601String(),
          });
        } catch (e) {
          debugPrint('[STUDENT REPO] Supabase background sync note: $e');
        }
      }());

      return true;
    } catch (e) {
      debugPrint('[STUDENT REPO] addStudent error: $e');
      return false;
    }
  }

  /// Update an existing Student record across both backends
  static Future<bool> updateStudent(StudentModel student) async {
    try {
      // 1. Local Hive & Firestore update
      await DatabaseService.updateStudent(student);

      // 2. Non-blocking Supabase sync
      unawaited(() async {
        try {
          await SupabaseService.syncStudentToSupabase({
            'id': student.id,
            'student_code': student.studentCode,
            'first_name': student.firstName,
            'last_name': student.lastName,
            'father_name': student.fatherName,
            'phone': student.phone,
            'email': student.email,
            'class_type': student.classType,
            'grade': student.grade,
            'subject': student.subject,
            'fee_submitted': student.feeSubmitted,
            'fee_remaining': student.feeRemaining,
            'profile_pic_url': student.profilePicUrl,
            'enrollment_status': student.enrollmentStatus,
            'is_active': student.isActive,
            'updated_at': DateTime.now().toIso8601String(),
          });
        } catch (e) {
          debugPrint('[STUDENT REPO] Supabase update sync note: $e');
        }
      }());

      return true;
    } catch (e) {
      debugPrint('[STUDENT REPO] updateStudent error: $e');
      return false;
    }
  }

  /// Delete / Move Student to Recycle Bin
  static Future<bool> deleteStudent(String id) async {
    return DatabaseService.deleteStudent(id);
  }
}
