import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

part 'teacher_model.g.dart';

@HiveType(typeId: 1)
class TeacherModel extends HiveObject {
  @HiveField(0)
  String id;
  @HiveField(1)
  String name;
  @HiveField(2)
  String phone;
  @HiveField(3)
  String email;
  @HiveField(4)
  String subject;
  @HiveField(5)
  double salary;
  @HiveField(6)
  String profilePicUrl;
  @HiveField(7)
  String classType;

  TeacherModel({
    required this.id, required this.name, required this.phone,
    required this.email, required this.subject, required this.salary,
    required this.profilePicUrl, this.classType = 'FSc',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id, 'name': name, 'phone': phone, 'email': email,
      'subject': subject, 'salary': salary, 'profilePicUrl': profilePicUrl,
      'classType': classType,
    };
  }

  factory TeacherModel.fromMap(Map<String, dynamic> map, String docId) {
    return TeacherModel(
      id: docId, name: map['name'] ?? '', phone: map['phone'] ?? '',
      email: map['email'] ?? '', subject: map['subject'] ?? '',
      salary: (map['salary'] ?? 0).toDouble(),
      profilePicUrl: map['profilePicUrl'] ?? '',
      classType: map['classType'] ?? 'FSc',
    );
  }

  Color get subjectColor {
    switch (subject) {
      case 'Biology': return const Color(0xFF4CAF50);
      case 'Physics': return const Color(0xFF2196F3);
      case 'Chemistry': return const Color(0xFFFF9800);
      case 'English': return const Color(0xFF9C27B0);
      default: return const Color(0xFF1B5E20);
    }
  }
}