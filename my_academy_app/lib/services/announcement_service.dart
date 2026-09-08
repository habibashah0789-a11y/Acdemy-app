import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../config/supabase_config.dart';
import '../models/announcement_model.dart';
import 'supabase_service.dart';

/// Service for publishing and fetching academy announcements across Supabase & Firestore.
class AnnouncementService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _firestoreCollection = 'announcements';

  /// Get active announcements (optionally filtered by class ID, includes academy-wide announcements)
  static Future<List<AnnouncementModel>> getActiveAnnouncements({String? classId}) async {
    // 1. Try fetching from Supabase
    if (SupabaseService.isConfigured) {
      try {
        var query = SupabaseConfig.client
            .from('v_active_announcements')
            .select();

        final response = await query;
        final list = (response as List)
            .map((json) => AnnouncementModel.fromSupabase(json as Map<String, dynamic>))
            .where((a) => classId == null || a.isAcademyWide || a.targetClassId == classId)
            .toList();

        if (list.isNotEmpty) return list;
      } catch (e) {
        debugPrint('[ANNOUNCEMENT SERVICE] Supabase query note: $e');
      }
    }

    // 2. Fallback to Firestore
    try {
      final snap = await _firestore
          .collection(_firestoreCollection)
          .where('isPublished', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .get();

      return snap.docs
          .map((doc) => AnnouncementModel.fromFirestore(doc))
          .where((a) => classId == null || a.isAcademyWide || a.targetClassId == classId)
          .toList();
    } catch (e) {
      debugPrint('[ANNOUNCEMENT SERVICE] Firestore query error: $e');
      return [];
    }
  }

  /// Create and broadcast a new announcement (writes to both Supabase and Firestore)
  static Future<bool> publishAnnouncement(AnnouncementModel announcement) async {
    bool success = false;

    // 1. Write to Supabase
    if (SupabaseService.isConfigured) {
      try {
        await SupabaseConfig.client
            .from('announcements')
            .insert(announcement.toSupabaseMap());
        success = true;
      } catch (e) {
        debugPrint('[ANNOUNCEMENT SERVICE] Supabase insert note: $e');
      }
    }

    // 2. Write to Firestore
    try {
      final docRef = announcement.id.isNotEmpty
          ? _firestore.collection(_firestoreCollection).doc(announcement.id)
          : _firestore.collection(_firestoreCollection).doc();

      await docRef.set(announcement.toFirestoreMap());
      success = true;
    } catch (e) {
      debugPrint('[ANNOUNCEMENT SERVICE] Firestore insert note: $e');
    }

    return success;
  }
}
