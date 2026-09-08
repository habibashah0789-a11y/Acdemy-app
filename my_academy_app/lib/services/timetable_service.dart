import 'package:flutter/foundation.dart';
import '../config/supabase_config.dart';
import '../models/timetable_model.dart';
import 'supabase_service.dart';

/// Service for managing academy timetables and schedules (7:00 AM to 10:00 PM) via Supabase.
class TimetableService {
  /// Fetch all active timetable slots across the academy
  static Future<List<TimetableModel>> getWeeklyTimetable() async {
    try {
      if (!SupabaseService.isConfigured) return [];
      final response = await SupabaseConfig.client
          .from('v_class_timetables')
          .select()
          .eq('is_active', true);

      return (response as List)
          .map((json) => TimetableModel.fromSupabase(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[TIMETABLE SERVICE] getWeeklyTimetable error: $e');
      return [];
    }
  }

  /// Fetch timetable slots for a specific class
  static Future<List<TimetableModel>> getTimetableByClass(String classId) async {
    try {
      if (!SupabaseService.isConfigured) return [];
      final response = await SupabaseConfig.client
          .from('v_class_timetables')
          .select()
          .eq('class_id', classId)
          .eq('is_active', true);

      return (response as List)
          .map((json) => TimetableModel.fromSupabase(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[TIMETABLE SERVICE] getTimetableByClass error: $e');
      return [];
    }
  }

  /// Fetch timetable slots assigned to a specific teacher
  static Future<List<TimetableModel>> getTimetableByTeacher(String teacherId) async {
    try {
      if (!SupabaseService.isConfigured) return [];
      final response = await SupabaseConfig.client
          .from('v_class_timetables')
          .select()
          .eq('teacher_id', teacherId)
          .eq('is_active', true);

      return (response as List)
          .map((json) => TimetableModel.fromSupabase(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[TIMETABLE SERVICE] getTimetableByTeacher error: $e');
      return [];
    }
  }

  /// Create a new timetable slot
  static Future<bool> addSlot(TimetableModel slot) async {
    try {
      if (!SupabaseService.isConfigured) return false;
      await SupabaseConfig.client
          .from('timetables')
          .insert(slot.toSupabaseMap());
      return true;
    } catch (e) {
      debugPrint('[TIMETABLE SERVICE] addSlot error: $e');
      return false;
    }
  }

  /// Update an existing timetable slot
  static Future<bool> updateSlot(TimetableModel slot) async {
    try {
      if (!SupabaseService.isConfigured) return false;
      await SupabaseConfig.client
          .from('timetables')
          .update(slot.toSupabaseMap())
          .eq('id', slot.id);
      return true;
    } catch (e) {
      debugPrint('[TIMETABLE SERVICE] updateSlot error: $e');
      return false;
    }
  }

  /// Delete or deactivate a timetable slot
  static Future<bool> deleteSlot(String slotId) async {
    try {
      if (!SupabaseService.isConfigured) return false;
      await SupabaseConfig.client
          .from('timetables')
          .delete()
          .eq('id', slotId);
      return true;
    } catch (e) {
      debugPrint('[TIMETABLE SERVICE] deleteSlot error: $e');
      return false;
    }
  }
}
