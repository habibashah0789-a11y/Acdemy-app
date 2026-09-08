import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/fee_model.dart';
import '../models/student_model.dart';
import '../services/firestore_service.dart';
import '../services/supabase_service.dart';
import '../services/database_service.dart';

/// Repository for Fee Transactions and Financial Records.
/// Synchronizes fee payments with Firestore Realtime NoSQL and Supabase PostgreSQL.
class FeeRepository {
  /// Record a new fee payment transaction
  static Future<bool> recordPayment({
    required StudentModel student,
    required double amount,
    required String subject,
    String paymentMethod = 'Cash',
    String? receiptNo,
    String? note,
    String recordedBy = 'Admin',
  }) async {
    try {
      final txId = '${DateTime.now().millisecondsSinceEpoch}_${student.id}';
      final newRemaining = (student.feeRemaining - amount).clamp(0.0, double.infinity);

      final feeRecord = FeeModel(
        id: txId,
        studentId: student.id,
        studentCode: student.studentCode,
        studentName: student.name,
        amount: amount,
        remainingAfter: newRemaining,
        subject: subject,
        classType: student.classType,
        grade: student.grade,
        paymentMethod: paymentMethod,
        receiptNo: receiptNo,
        note: note,
        date: DateTime.now(),
        recordedBy: recordedBy,
      );

      // 1. Update Student record in Hive & Firestore
      final updatedStudent = student.copyWith(
        feeSubmitted: student.feeSubmitted + amount,
        feeRemaining: newRemaining,
        updatedAt: DateTime.now(),
      );
      await DatabaseService.updateStudent(updatedStudent);

      // 2. Write to Firestore 'fee_transactions' collection
      unawaited(() async {
        try {
          await FirestoreService.setDoc(
            collection: 'fee_transactions',
            docId: txId,
            data: feeRecord.toFirestoreMap(),
          );
        } catch (e) {
          debugPrint('[FEE REPO] Firestore fee tx error: $e');
        }
      }());

      // 3. Write to Supabase 'fee_transactions' PostgreSQL table
      unawaited(() async {
        try {
          await SupabaseService.syncFeeTransactionToSupabase(feeRecord.toSupabaseMap());
        } catch (e) {
          debugPrint('[FEE REPO] Supabase fee tx error: $e');
        }
      }());

      return true;
    } catch (e) {
      debugPrint('[FEE REPO] recordPayment error: $e');
      return false;
    }
  }

  /// Realtime Stream of Fee Transactions for a student or overall
  static Stream<QuerySnapshot<Map<String, dynamic>>> getFeeStream({String? studentId}) {
    return FirestoreService.getFeeTransactionsStream(studentId: studentId);
  }

  /// Get Monthly Revenue Analytics from Supabase PostgreSQL
  static Future<List<Map<String, dynamic>>> getMonthlyRevenueReport() {
    return SupabaseService.getMonthlyRevenueReport();
  }

  /// Get Defaulters list from Supabase
  static Future<List<Map<String, dynamic>>> getDefaultersReport() {
    return SupabaseService.getDefaultersReport();
  }
}
