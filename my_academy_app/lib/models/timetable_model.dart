import 'package:flutter/material.dart';

/// Model representing a class timetable schedule slot.
/// Supports both Supabase relational queries and local caching.
class TimetableModel {
  final String id;
  final String classId;
  final String className;
  final String classLevel;
  final String subjectId;
  final String subjectName;
  final String subjectCode;
  final String? teacherId;
  final String? teacherName;
  final String dayOfWeek; // 'Monday', 'Tuesday', etc.
  final String startTime; // '08:00:00'
  final String endTime;   // '09:00:00'
  final String room;
  final bool isActive;
  final DateTime? createdAt;

  const TimetableModel({
    required this.id,
    required this.classId,
    this.className = '',
    this.classLevel = '',
    required this.subjectId,
    this.subjectName = '',
    this.subjectCode = '',
    this.teacherId,
    this.teacherName,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    this.room = 'Room 1',
    this.isActive = true,
    this.createdAt,
  });

  TimeOfDay get parsedStartTime {
    final parts = startTime.split(':');
    return TimeOfDay(
      hour: int.tryParse(parts[0]) ?? 8,
      minute: parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0,
    );
  }

  TimeOfDay get parsedEndTime {
    final parts = endTime.split(':');
    return TimeOfDay(
      hour: int.tryParse(parts[0]) ?? 9,
      minute: parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0,
    );
  }

  String get formattedSlot => '$startTime - $endTime';

  // ── Supabase Serialization ──
  Map<String, dynamic> toSupabaseMap() {
    final map = <String, dynamic>{
      'class_id': classId,
      'subject_id': subjectId,
      'teacher_id': teacherId,
      'day_of_week': dayOfWeek,
      'start_time': startTime,
      'end_time': endTime,
      'room': room,
      'is_active': isActive,
    };
    if (id.isNotEmpty) {
      map['id'] = id;
    }
    return map;
  }

  factory TimetableModel.fromSupabase(Map<String, dynamic> map) {
    return TimetableModel(
      id: map['id']?.toString() ?? '',
      classId: map['class_id']?.toString() ?? '',
      className: map['class_name']?.toString() ?? '',
      classLevel: map['class_level']?.toString() ?? '',
      subjectId: map['subject_id']?.toString() ?? '',
      subjectName: map['subject_name']?.toString() ?? '',
      subjectCode: map['subject_code']?.toString() ?? '',
      teacherId: map['teacher_id']?.toString(),
      teacherName: map['teacher_name']?.toString(),
      dayOfWeek: map['day_of_week']?.toString() ?? 'Monday',
      startTime: map['start_time']?.toString() ?? '08:00:00',
      endTime: map['end_time']?.toString() ?? '09:00:00',
      room: map['room']?.toString() ?? 'Room 1',
      isActive: map['is_active'] as bool? ?? true,
      createdAt: map['created_at'] != null 
          ? DateTime.tryParse(map['created_at'].toString()) 
          : null,
    );
  }

  TimetableModel copyWith({
    String? id,
    String? classId,
    String? className,
    String? classLevel,
    String? subjectId,
    String? subjectName,
    String? subjectCode,
    String? teacherId,
    String? teacherName,
    String? dayOfWeek,
    String? startTime,
    String? endTime,
    String? room,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return TimetableModel(
      id: id ?? this.id,
      classId: classId ?? this.classId,
      className: className ?? this.className,
      classLevel: classLevel ?? this.classLevel,
      subjectId: subjectId ?? this.subjectId,
      subjectName: subjectName ?? this.subjectName,
      subjectCode: subjectCode ?? this.subjectCode,
      teacherId: teacherId ?? this.teacherId,
      teacherName: teacherName ?? this.teacherName,
      dayOfWeek: dayOfWeek ?? this.dayOfWeek,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      room: room ?? this.room,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
