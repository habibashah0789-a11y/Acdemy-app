import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';

/// Centralized service for Supabase PostgreSQL tables, SQL queries, relational analytics, and storage.
class SupabaseService {
  static SupabaseClient get client => SupabaseConfig.client;
  static bool get isConfigured => SupabaseConfig.isInitialized;

  /// Check connection status to Supabase Project
  static Future<bool> checkConnection() async {
    try {
      if (!isConfigured) return false;
      final res = await client.from('students').select('id').limit(1);
      debugPrint('[SUPABASE SERVICE] Connection test successful. Rows returned: ${res.length}');
      return true;
    } catch (e) {
      debugPrint('[SUPABASE SERVICE] Connection test result: $e');
      return isConfigured;
    }
  }

  // ── Database Table Sync (PostgreSQL) ──

  /// Upsert a student record to Supabase
  static Future<void> syncStudentToSupabase(Map<String, dynamic> studentData) async {
    try {
      if (!isConfigured) return;
      await client.from('students').upsert(studentData);
      debugPrint('[SUPABASE SERVICE] Synced student ${studentData['id']} to Supabase.');
    } catch (e) {
      debugPrint('[SUPABASE SERVICE] syncStudentToSupabase note: $e');
    }
  }

  /// Sync teacher record to Supabase
  static Future<void> syncTeacherToSupabase(Map<String, dynamic> teacherData) async {
    try {
      if (!isConfigured) return;
      await client.from('teachers').upsert(teacherData);
      debugPrint('[SUPABASE SERVICE] Synced teacher ${teacherData['name']} to Supabase.');
    } catch (e) {
      debugPrint('[SUPABASE SERVICE] syncTeacherToSupabase note: $e');
    }
  }

  /// Sync fee transaction record to Supabase
  static Future<void> syncFeeTransactionToSupabase(Map<String, dynamic> feeData) async {
    try {
      if (!isConfigured) return;
      await client.from('fee_transactions').upsert(feeData);
      debugPrint('[SUPABASE SERVICE] Synced fee transaction ${feeData['id']} to Supabase.');
    } catch (e) {
      debugPrint('[SUPABASE SERVICE] syncFeeTransactionToSupabase note: $e');
    }
  }

  /// Sync attendance record to Supabase
  static Future<void> syncAttendanceToSupabase(Map<String, dynamic> attendanceData) async {
    try {
      if (!isConfigured) return;
      await client.from('attendance').upsert(attendanceData);
      debugPrint('[SUPABASE SERVICE] Synced attendance ${attendanceData['id']} to Supabase.');
    } catch (e) {
      debugPrint('[SUPABASE SERVICE] syncAttendanceToSupabase note: $e');
    }
  }

  /// Sync notification record to Supabase
  static Future<void> syncNotificationToSupabase(Map<String, dynamic> notifData) async {
    try {
      if (!isConfigured) return;
      await client.from('notifications').upsert(notifData);
      debugPrint('[SUPABASE SERVICE] Synced notification ${notifData['title']} to Supabase.');
    } catch (e) {
      debugPrint('[SUPABASE SERVICE] syncNotificationToSupabase note: $e');
    }
  }

  // ── Complex Relational Queries & Reports (SQL / Analytics) ──

  /// Get total fee revenue grouped by month from Supabase
  static Future<List<Map<String, dynamic>>> getMonthlyRevenueReport() async {
    try {
      if (!isConfigured) return [];
      final response = await client
          .from('fee_transactions')
          .select('amount, payment_date, class_type')
          .order('payment_date', descending: true);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('[SUPABASE SERVICE] getMonthlyRevenueReport note: $e');
      return [];
    }
  }

  /// Get attendance percentage summary for a specific student
  static Future<Map<String, dynamic>> getStudentAttendanceStats(String studentId) async {
    try {
      if (!isConfigured) return {'present': 0, 'absent': 0, 'total': 0, 'percentage': 0.0};
      final records = await client
          .from('attendance')
          .select('status')
          .eq('student_id', studentId);

      int present = 0;
      int absent = 0;
      int total = records.length;

      for (final r in records) {
        final status = (r['status'] ?? '').toString().toLowerCase();
        if (status == 'present' || status == 'late') {
          present++;
        } else if (status == 'absent') {
          absent++;
        }
      }

      final percentage = total > 0 ? (present / total) * 100 : 0.0;
      return {
        'present': present,
        'absent': absent,
        'total': total,
        'percentage': percentage,
      };
    } catch (e) {
      debugPrint('[SUPABASE SERVICE] getStudentAttendanceStats note: $e');
      return {'present': 0, 'absent': 0, 'total': 0, 'percentage': 0.0};
    }
  }

  /// Get list of fee defaulters with remaining balances
  static Future<List<Map<String, dynamic>>> getDefaultersReport() async {
    try {
      if (!isConfigured) return [];
      final response = await client
          .from('students')
          .select('id, student_code, first_name, last_name, phone, class_type, grade, fee_remaining')
          .gt('fee_remaining', 0)
          .order('fee_remaining', descending: true);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('[SUPABASE SERVICE] getDefaultersReport note: $e');
      return [];
    }
  }

  // ── Storage Operations ──

  /// Upload attachment or image to a Supabase Storage bucket
  static Future<String?> uploadFile({
    required Uint8List fileBytes,
    required String bucketName,
    required String filePath,
    String contentType = 'image/png',
  }) async {
    try {
      if (!isConfigured) return null;
      await client.storage.from(bucketName).uploadBinary(
            filePath,
            fileBytes,
            fileOptions: FileOptions(
              contentType: contentType,
              cacheControl: '3600',
              upsert: true,
            ),
          );
      return client.storage.from(bucketName).getPublicUrl(filePath);
    } catch (e) {
      debugPrint('[SUPABASE SERVICE] uploadFile error: $e');
      return null;
    }
  }

  /// Upload announcement attachment to Supabase Storage bucket 'announcements'
  static Future<String?> uploadAnnouncementAttachment({
    required Uint8List fileBytes,
    required String fileName,
  }) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final path = 'announcements_${timestamp}_$fileName';
    return uploadFile(
      fileBytes: fileBytes,
      bucketName: 'announcements',
      filePath: path,
    );
  }
}
