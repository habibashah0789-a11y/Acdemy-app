import 'package:cloud_firestore/cloud_firestore.dart';

/// Model representing Academy Announcements with class targeting and priority levels.
class AnnouncementModel {
  final String id;
  final String title;
  final String content;
  final String? targetClassId; // null = Academy-wide
  final String? targetClassName;
  final String? authorId;
  final String priority; // 'low', 'normal', 'urgent'
  final bool isPublished;
  final DateTime? expiresAt;
  final DateTime createdAt;

  const AnnouncementModel({
    required this.id,
    required this.title,
    required this.content,
    this.targetClassId,
    this.targetClassName,
    this.authorId,
    this.priority = 'normal',
    this.isPublished = true,
    this.expiresAt,
    required this.createdAt,
  });

  bool get isUrgent => priority.toLowerCase() == 'urgent';
  bool get isAcademyWide => targetClassId == null || targetClassId!.isEmpty;

  // ── Supabase Serialization ──
  Map<String, dynamic> toSupabaseMap() {
    final map = <String, dynamic>{
      'title': title,
      'content': content,
      'target_class_id': targetClassId,
      'author_id': authorId,
      'priority': priority,
      'is_published': isPublished,
      'expires_at': expiresAt?.toIso8601String(),
    };
    if (id.isNotEmpty) {
      map['id'] = id;
    }
    return map;
  }

  factory AnnouncementModel.fromSupabase(Map<String, dynamic> map) {
    return AnnouncementModel(
      id: map['id']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      content: map['content']?.toString() ?? '',
      targetClassId: map['target_class_id']?.toString(),
      targetClassName: map['target_class_name']?.toString(),
      authorId: map['author_id']?.toString(),
      priority: map['priority']?.toString() ?? 'normal',
      isPublished: map['is_published'] as bool? ?? true,
      expiresAt: map['expires_at'] != null 
          ? DateTime.tryParse(map['expires_at'].toString()) 
          : null,
      createdAt: map['created_at'] != null 
          ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  // ── Firestore Serialization ──
  Map<String, dynamic> toFirestoreMap() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'targetClassId': targetClassId,
      'targetClassName': targetClassName,
      'priority': priority,
      'isPublished': isPublished,
      'expiresAt': expiresAt != null ? Timestamp.fromDate(expiresAt!) : null,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory AnnouncementModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    DateTime created = DateTime.now();
    final rawCreated = data['createdAt'];
    if (rawCreated is Timestamp) {
      created = rawCreated.toDate();
    }

    DateTime? expires;
    final rawExpires = data['expiresAt'];
    if (rawExpires is Timestamp) {
      expires = rawExpires.toDate();
    }

    return AnnouncementModel(
      id: doc.id,
      title: data['title']?.toString() ?? '',
      content: data['content']?.toString() ?? '',
      targetClassId: data['targetClassId']?.toString(),
      targetClassName: data['targetClassName']?.toString(),
      priority: data['priority']?.toString() ?? 'normal',
      isPublished: data['isPublished'] as bool? ?? true,
      expiresAt: expires,
      createdAt: created,
    );
  }
}
