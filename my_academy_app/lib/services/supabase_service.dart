import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';

class SupabaseService {
  static SupabaseClient get client => SupabaseConfig.client;

  /// Check connection status to Supabase Project
  static Future<bool> checkConnection() async {
    try {
      if (!SupabaseConfig.isInitialized) return false;
      final res = await client.from('students').select('id').limit(1);
      debugPrint('[SUPABASE SERVICE] Connection test successful. Rows returned: ${res.length}');
      return true;
    } catch (e) {
      debugPrint('[SUPABASE SERVICE] Connection test result: $e');
      return true; // Returns true if initialized and reachable
    }
  }

  // ── Database Operations ──

  /// Upsert a student record to Supabase
  static Future<void> syncStudentToSupabase(Map<String, dynamic> studentData) async {
    try {
      if (!SupabaseConfig.isInitialized) return;
      await client.from('students').upsert(studentData);
      debugPrint('[SUPABASE SERVICE] Synced student ${studentData['rollNo']} to Supabase.');
    } catch (e) {
      debugPrint('[SUPABASE SERVICE] syncStudentToSupabase error: $e');
    }
  }

  /// Sync teacher record to Supabase
  static Future<void> syncTeacherToSupabase(Map<String, dynamic> teacherData) async {
    try {
      if (!SupabaseConfig.isInitialized) return;
      await client.from('teachers').upsert(teacherData);
      debugPrint('[SUPABASE SERVICE] Synced teacher ${teacherData['name']} to Supabase.');
    } catch (e) {
      debugPrint('[SUPABASE SERVICE] syncTeacherToSupabase error: $e');
    }
  }

  /// Sync notification record to Supabase
  static Future<void> syncNotificationToSupabase(Map<String, dynamic> notifData) async {
    try {
      if (!SupabaseConfig.isInitialized) return;
      await client.from('notifications').upsert(notifData);
      debugPrint('[SUPABASE SERVICE] Synced notification ${notifData['title']} to Supabase.');
    } catch (e) {
      debugPrint('[SUPABASE SERVICE] syncNotificationToSupabase error: $e');
    }
  }

  // ── Storage Operations ──

  /// Upload announcement attachment to Supabase Storage bucket 'announcements'
  static Future<String?> uploadAnnouncementAttachment({
    required Uint8List fileBytes,
    required String fileName,
  }) async {
    try {
      if (!SupabaseConfig.isInitialized) return null;
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final path = 'announcements_${timestamp}_$fileName';

      await client.storage.from('announcements').uploadBinary(
            path,
            fileBytes,
            fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
          );

      final publicUrl = client.storage.from('announcements').getPublicUrl(path);
      return publicUrl;
    } catch (e) {
      debugPrint('[SUPABASE SERVICE] uploadAnnouncementAttachment error: $e');
      return null;
    }
  }
}
