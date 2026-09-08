import '../models/announcement_model.dart';
import '../services/announcement_service.dart';

/// Repository coordinating Announcements across Supabase and Firestore.
class AnnouncementRepository {
  /// Fetch all active announcements, optionally filtered by class
  static Future<List<AnnouncementModel>> getActiveAnnouncements({String? classId}) {
    return AnnouncementService.getActiveAnnouncements(classId: classId);
  }

  /// Publish a new announcement
  static Future<bool> publishAnnouncement(AnnouncementModel announcement) {
    return AnnouncementService.publishAnnouncement(announcement);
  }
}
