import 'package:cloud_firestore/cloud_firestore.dart';

class TeacherModel {
  final String id; // Firebase Auth UID = Firestore doc ID
  final String name;
  final String email;
  final String teacherId; // e.g., T-BIO-FSC-001
  final String subject; // e.g., "Biology"
  final String section; // "FSc" | "Matric"
  final List<String> assignedClasses; // ["First Year", "Second Year"]
  final String profilePicUrl;
  final bool isActive;
  final String role; // always "teacher"
  final DateTime createdAt;
  final DateTime? updatedAt;

  const TeacherModel({
    required this.id,
    required this.name,
    required this.email,
    required this.teacherId,
    required this.subject,
    required this.section,
    required this.assignedClasses,
    this.profilePicUrl = '',
    this.isActive = true,
    this.role = 'teacher',
    required this.createdAt,
    this.updatedAt,
  });

  String get classesDisplay => assignedClasses.join(', ');
  String get tagLine => '$subject \u2022 $section';

  factory TeacherModel.fromMap(Map<String, dynamic> map, String docId) {
    DateTime createdAt;
    final rawCreatedAt = map['createdAt'];
    if (rawCreatedAt is Timestamp) {
      createdAt = rawCreatedAt.toDate();
    } else if (rawCreatedAt is String) {
      createdAt = DateTime.tryParse(rawCreatedAt) ?? DateTime.now();
    } else {
      createdAt = DateTime.now();
    }

    DateTime? updatedAt;
    final rawUpdatedAt = map['updatedAt'];
    if (rawUpdatedAt is Timestamp) {
      updatedAt = rawUpdatedAt.toDate();
    }

    List<String> classes = [];
    final rawClasses = map['assignedClasses'];
    if (rawClasses is List) {
      classes = rawClasses.map((e) => e.toString()).toList();
    }

    return TeacherModel(
      id: docId,
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      teacherId: map['teacherId'] ?? '',
      subject: map['subject'] ?? '',
      section: map['section'] ?? '',
      assignedClasses: classes,
      profilePicUrl: map['profilePicUrl'] ?? '',
      isActive: map['isActive'] ?? true,
      role: map['role'] ?? 'teacher',
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  factory TeacherModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) return TeacherModel.empty();
    return TeacherModel.fromMap(data, doc.id);
  }

  factory TeacherModel.empty() {
    return TeacherModel(
      id: '',
      name: '',
      email: '',
      teacherId: '',
      subject: '',
      section: '',
      assignedClasses: [],
      createdAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'teacherId': teacherId,
      'subject': subject,
      'section': section,
      'assignedClasses': assignedClasses,
      'profilePicUrl': profilePicUrl,
      'isActive': isActive,
      'role': role,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null
          ? Timestamp.fromDate(updatedAt!)
          : FieldValue.serverTimestamp(),
    };
  }

  /// Convert to Supabase PostgreSQL table row format
  Map<String, dynamic> toSupabaseMap() {
    return {
      'id': id,
      'teacher_id': teacherId,
      'name': name,
      'email': email,
      'subject': subject,
      'section': section,
      'profile_pic_url': profilePicUrl,
      'status': isActive ? 'active' : 'inactive',
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': (updatedAt ?? DateTime.now()).toIso8601String(),
    };
  }

  /// Create TeacherModel from Supabase row
  factory TeacherModel.fromSupabase(Map<String, dynamic> map) {
    return TeacherModel(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      email: map['email']?.toString() ?? '',
      teacherId: map['teacher_id']?.toString() ?? '',
      subject: map['subject']?.toString() ?? '',
      section: map['section']?.toString() ?? 'FSc',
      assignedClasses: [],
      profilePicUrl: map['profile_pic_url']?.toString() ?? '',
      isActive: map['is_active'] as bool? ?? true,
      role: 'teacher',
      createdAt: map['created_at'] != null 
          ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: map['updated_at'] != null 
          ? DateTime.tryParse(map['updated_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toUpdateMap() {
    return {
      'name': name,
      'teacherId': teacherId,
      'subject': subject,
      'section': section,
      'assignedClasses': assignedClasses,
      'profilePicUrl': profilePicUrl,
      'isActive': isActive,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  TeacherModel copyWith({
    String? id,
    String? name,
    String? email,
    String? teacherId,
    String? subject,
    String? section,
    List<String>? assignedClasses,
    String? profilePicUrl,
    bool? isActive,
    String? role,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TeacherModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      teacherId: teacherId ?? this.teacherId,
      subject: subject ?? this.subject,
      section: section ?? this.section,
      assignedClasses: assignedClasses ?? this.assignedClasses,
      profilePicUrl: profilePicUrl ?? this.profilePicUrl,
      isActive: isActive ?? this.isActive,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() =>
      'TeacherModel(id: $id, name: $name, subject: $subject, section: $section)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is TeacherModel && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
