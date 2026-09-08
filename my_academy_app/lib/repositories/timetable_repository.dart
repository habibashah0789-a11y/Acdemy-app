import '../models/timetable_model.dart';
import '../services/timetable_service.dart';

/// Repository coordinating Timetable data between Supabase and UI layers.
class TimetableRepository {
  /// Fetch all active timetable slots
  static Future<List<TimetableModel>> getWeeklyTimetable() {
    return TimetableService.getWeeklyTimetable();
  }

  /// Fetch timetable for a specific class
  static Future<List<TimetableModel>> getTimetableByClass(String classId) {
    return TimetableService.getTimetableByClass(classId);
  }

  /// Fetch timetable for a specific teacher
  static Future<List<TimetableModel>> getTimetableByTeacher(String teacherId) {
    return TimetableService.getTimetableByTeacher(teacherId);
  }

  /// Save or update a timetable slot
  static Future<bool> saveSlot(TimetableModel slot) {
    if (slot.id.isNotEmpty) {
      return TimetableService.updateSlot(slot);
    } else {
      return TimetableService.addSlot(slot);
    }
  }

  /// Delete a timetable slot
  static Future<bool> deleteSlot(String slotId) {
    return TimetableService.deleteSlot(slotId);
  }
}
