import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
part 'student_model.g.dart';



@HiveType(typeId: 0)
class StudentModel extends HiveObject {
  @HiveField(0)
  String id;
  
  @HiveField(1)
  String firstName;
  
  @HiveField(2)
  String lastName;
  
  @HiveField(3)
  String fatherName;
  
  @HiveField(4)
  String phone;
  
  @HiveField(5)
  String email;
  
  @HiveField(6)
  String schedule;
  
  @HiveField(7)
  double feeSubmitted;
  
  @HiveField(8)
  double feeRemaining;
  
  @HiveField(9)
  double biologyFee;
  
  @HiveField(10)
  double physicsFee;
  
  @HiveField(11)
  double chemistryFee;
  
  @HiveField(12)
  double englishFee;
  
  @HiveField(13)
  String profilePicUrl;
  
  @HiveField(14)
  String enrollmentStatus;
  
  @HiveField(15)
  String classType;
  
  @HiveField(16)
  String grade;
  
  @HiveField(17)
  String subject;
  
  @HiveField(18)
  double mathFee;
  
  @HiveField(19)
  DateTime createdAt;
  
  @HiveField(20)
  DateTime? updatedAt;
  
  @HiveField(21)
  bool isActive;

  @HiveField(22)
  String? subjectPaymentsJson;

  @HiveField(23)
  String? paymentHistoryJson;

  @HiveField(24)
  String? subjectSchedulesJson;

  StudentModel({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.fatherName,
    required this.phone,
    required this.email,
    required this.schedule,
    required this.feeSubmitted,
    required this.feeRemaining,
    required this.biologyFee,
    required this.physicsFee,
    required this.chemistryFee,
    required this.englishFee,
    required this.profilePicUrl,
    this.enrollmentStatus = 'active',
    this.classType = 'FSc',
    this.grade = 'First Year',
    this.subject = 'Biology',
    this.mathFee = 0,
    DateTime? createdAt,
    this.updatedAt,
    this.isActive = true,
    this.subjectPaymentsJson,
    this.paymentHistoryJson,
    this.subjectSchedulesJson,
  }) : createdAt = createdAt ?? DateTime.now();

  // Computed properties
  Map<String, double> get subjectPayments {
    if (subjectPaymentsJson == null || subjectPaymentsJson!.isEmpty) return {};
    try {
      final Map<String, dynamic> decoded = jsonDecode(subjectPaymentsJson!);
      return decoded.map((key, value) => MapEntry(key, (value as num).toDouble()));
    } catch (e) {
      return {};
    }
  }

  double getSubjectPaid(String sub) {
    final payments = subjectPayments;
    if (payments.containsKey(sub)) return payments[sub]!;
    
    // Fallback logic for old data if needed
    // If the student only has one subject and subjectPayments is empty, 
    // we could assume feeSubmitted belongs to that subject.
    final subjects = subject.split(',').map((e) => e.trim()).toList();
    if (subjects.length == 1 && subjects.first == sub && payments.isEmpty) {
      return feeSubmitted;
    }
    
    return 0.0;
  }

  double getSubjectTotalFee(String sub) {
    switch (sub) {
      case 'Biology': return biologyFee;
      case 'Physics': return physicsFee;
      case 'Chemistry': return chemistryFee;
      case 'English': return englishFee;
      case 'Math': return mathFee;
      default: return 0.0;
    }
  }

  double getSubjectRemaining(String sub) {
    return getSubjectTotalFee(sub) - getSubjectPaid(sub);
  }

  bool isSubjectPaid(String sub) => getSubjectRemaining(sub) <= 0;

  Map<String, String> get subjectSchedules {
    if (subjectSchedulesJson == null || subjectSchedulesJson!.isEmpty) {
      if (subject.isNotEmpty && schedule.isNotEmpty) {
        final Map<String, String> parsed = {};
        if (schedule.contains(':')) {
          final scheduleParts = schedule.split(',');
          for (final part in scheduleParts) {
            final kv = part.split(':');
            if (kv.length == 2) {
              parsed[kv[0].trim()] = kv[1].trim();
            }
          }
        }
        if (parsed.isNotEmpty) return parsed;
        return {subject: schedule};
      }
      return {};
    }
    try {
      final Map<String, dynamic> decoded = jsonDecode(subjectSchedulesJson!);
      return decoded.map((key, value) => MapEntry(key, value.toString()));
    } catch (e) {
      return {};
    }
  }

  String getScheduleForSubject(String subj) {
    final map = subjectSchedules;
    if (map.containsKey(subj)) {
      return map[subj]!;
    }
    final cleanSubj = subj.trim().toLowerCase();
    for (final entry in map.entries) {
      if (entry.key.trim().toLowerCase() == cleanSubj) {
        return entry.value;
      }
    }
    // Fallback to legacy single fields
    if (subject.trim().toLowerCase() == cleanSubj) {
      return schedule;
    }
    return '';
  }
  String get studentCode {
    if (id.isEmpty) return 'QA-000000';
    if (id.startsWith('QA-')) return id;
    final cleanId = id.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
    final suffix = cleanId.length >= 6 
        ? cleanId.substring(cleanId.length - 6).toUpperCase() 
        : cleanId.padLeft(6, '0').toUpperCase();
    return 'QA-$suffix';
  }

  String get qrData => 'QA-STUDENT:$studentCode:ID=$id:NAME=$name:CLASS=$classType-$grade';

  String get name => '$firstName $lastName'.trim();
  String get fullName => name;
  String get initials => 
      '${firstName.isNotEmpty ? firstName[0] : ''}${lastName.isNotEmpty ? lastName[0] : ''}';
  
  double get totalFee => biologyFee + physicsFee + chemistryFee + englishFee + mathFee;
  double get totalPaid => feeSubmitted;
  double get totalRemaining => feeRemaining;
  bool get isFeeFullyPaid => feeRemaining <= 0;
  double get feePaymentPercentage => totalFee > 0 ? (feeSubmitted / totalFee) * 100 : 0;
  
  bool get isFsc => classType.toLowerCase().contains('fsc');
  bool get isMatric => classType.toLowerCase().contains('matric');
  
  bool get isFirstYear => grade.toLowerCase().contains('first') || grade.toLowerCase().contains('ninth');
  bool get isSecondYear => grade.toLowerCase().contains('second') || grade.toLowerCase().contains('tenth');
  
  String get classLevel {
    if (isFsc) {
      return isFirstYear ? 'FSc Part 1' : 'FSc Part 2';
    } else {
      return isFirstYear ? 'Matric 9th' : 'Matric 10th';
    }
  }
  
  String get enrollmentStatusText {
    switch (enrollmentStatus.toLowerCase()) {
      case 'active':
        return 'Active';
      case 'inactive':
        return 'Inactive';
      case 'suspended':
        return 'Suspended';
      case 'graduated':
        return 'Graduated';
      default:
        return 'Active';
    }
  }
  
  Color get enrollmentStatusColor {
    switch (enrollmentStatus.toLowerCase()) {
      case 'active':
        return Colors.green;
      case 'inactive':
        return Colors.grey;
      case 'suspended':
        return Colors.orange;
      case 'graduated':
        return Colors.blue;
      default:
        return Colors.green;
    }
  }

  // Convert to Firestore map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'firstName': firstName,
      'lastName': lastName,
      'fatherName': fatherName,
      'phone': phone,
      'email': email,
      'schedule': schedule,
      'feeSubmitted': feeSubmitted,
      'feeRemaining': feeRemaining,
      'biologyFee': biologyFee,
      'physicsFee': physicsFee,
      'chemistryFee': chemistryFee,
      'englishFee': englishFee,
      'profilePicUrl': profilePicUrl,
      'enrollmentStatus': enrollmentStatus,
      'classType': classType,
      'grade': grade,
      'subject': subject,
      'mathFee': mathFee,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'isActive': isActive,
      'subjectPaymentsJson': subjectPaymentsJson,
      'paymentHistoryJson': paymentHistoryJson,
      'subjectSchedulesJson': subjectSchedulesJson,
    };
  }

  // Create from Firestore document
  factory StudentModel.fromMap(Map<String, dynamic> map, String docId) {
    // Safely parse createdAt
    DateTime parsedCreatedAt;
    final rawCreatedAt = map['createdAt'];
    if (rawCreatedAt is Timestamp) {
      parsedCreatedAt = rawCreatedAt.toDate();
    } else if (rawCreatedAt is String) {
      parsedCreatedAt = DateTime.tryParse(rawCreatedAt) ?? DateTime.now();
    } else if (rawCreatedAt is DateTime) {
      parsedCreatedAt = rawCreatedAt;
    } else {
      parsedCreatedAt = DateTime.now();
    }
    
    // Safely parse updatedAt
    DateTime? parsedUpdatedAt;
    final rawUpdatedAt = map['updatedAt'];
    if (rawUpdatedAt is Timestamp) {
      parsedUpdatedAt = rawUpdatedAt.toDate();
    } else if (rawUpdatedAt is String) {
      parsedUpdatedAt = DateTime.tryParse(rawUpdatedAt);
    } else if (rawUpdatedAt is DateTime) {
      parsedUpdatedAt = rawUpdatedAt;
    }
    
    // Safely parse name fields (handle legacy data)
    String firstName = map['firstName'] ?? '';
    String lastName = map['lastName'] ?? '';
    
    // If firstName is empty but there's a 'name' field, parse it
    if (firstName.isEmpty && map['name'] != null) {
      final nameParts = map['name'].toString().split(' ');
      firstName = nameParts.isNotEmpty ? nameParts[0] : '';
      lastName = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';
    }
    
    // Handle null values for all fields
    return StudentModel(
      id: docId,
      firstName: firstName,
      lastName: lastName,
      fatherName: map['fatherName'] ?? '',
      phone: map['phone'] ?? '',
      email: map['email'] ?? '',
      schedule: map['schedule'] ?? '',
      feeSubmitted: (map['feeSubmitted'] ?? 0.0).toDouble(),
      feeRemaining: (map['feeRemaining'] ?? 0.0).toDouble(),
      biologyFee: (map['biologyFee'] ?? 0.0).toDouble(),
      physicsFee: (map['physicsFee'] ?? 0.0).toDouble(),
      chemistryFee: (map['chemistryFee'] ?? 0.0).toDouble(),
      englishFee: (map['englishFee'] ?? 0.0).toDouble(),
      profilePicUrl: map['profilePicUrl'] ?? '',
      enrollmentStatus: map['enrollmentStatus'] ?? 'active',
      classType: map['classType'] ?? 'FSc',
      grade: map['grade'] ?? 'First Year',
      subject: map['subject'] ?? 'Biology',
      mathFee: (map['mathFee'] ?? 0.0).toDouble(),
      createdAt: parsedCreatedAt,
      updatedAt: parsedUpdatedAt,
      isActive: map['isActive'] ?? true,
      subjectPaymentsJson: map['subjectPaymentsJson'],
      paymentHistoryJson: map['paymentHistoryJson'],
      subjectSchedulesJson: map['subjectSchedulesJson'],
    );
  }
    // 🔥 INSERT THIS ENTIRE BLOCK between fromMap and empty() 🔥
  factory StudentModel.fromFirestore(DocumentSnapshot doc) {
    final rawData = doc.data();
    if (rawData is Map<String, dynamic>) {
      return StudentModel.fromMap(rawData, doc.id);
    }
    return StudentModel.empty().copyWith(id: doc.id);
  }
  
  // Create empty student (useful for forms)
  factory StudentModel.empty() {
    return StudentModel(
      id: '',
      firstName: '',
      lastName: '',
      fatherName: '',
      phone: '',
      email: '',
      schedule: '',
      feeSubmitted: 0.0,
      feeRemaining: 0.0,
      biologyFee: 0.0,
      physicsFee: 0.0,
      chemistryFee: 0.0,
      englishFee: 0.0,
      profilePicUrl: '',
      mathFee: 0.0,
    );
  }
  
  // Create copy with updated fields
  StudentModel copyWith({
    String? id,
    String? firstName,
    String? lastName,
    String? fatherName,
    String? phone,
    String? email,
    String? schedule,
    double? feeSubmitted,
    double? feeRemaining,
    double? biologyFee,
    double? physicsFee,
    double? chemistryFee,
    double? englishFee,
    String? profilePicUrl,
    String? enrollmentStatus,
    String? classType,
    String? grade,
    String? subject,
    double? mathFee,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isActive,
    String? subjectPaymentsJson,
    String? paymentHistoryJson,
    String? subjectSchedulesJson,
  }) {
    return StudentModel(
      id: id ?? this.id,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      fatherName: fatherName ?? this.fatherName,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      schedule: schedule ?? this.schedule,
      feeSubmitted: feeSubmitted ?? this.feeSubmitted,
      feeRemaining: feeRemaining ?? this.feeRemaining,
      biologyFee: biologyFee ?? this.biologyFee,
      physicsFee: physicsFee ?? this.physicsFee,
      chemistryFee: chemistryFee ?? this.chemistryFee,
      englishFee: englishFee ?? this.englishFee,
      profilePicUrl: profilePicUrl ?? this.profilePicUrl,
      enrollmentStatus: enrollmentStatus ?? this.enrollmentStatus,
      classType: classType ?? this.classType,
      grade: grade ?? this.grade,
      subject: subject ?? this.subject,
      mathFee: mathFee ?? this.mathFee,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isActive: isActive ?? this.isActive,
      subjectPaymentsJson: subjectPaymentsJson ?? this.subjectPaymentsJson,
      paymentHistoryJson: paymentHistoryJson ?? this.paymentHistoryJson,
      subjectSchedulesJson: subjectSchedulesJson ?? this.subjectSchedulesJson,
    );
  }
  
  // Update fee remaining based on subject fees
  void updateFeeRemaining() {
    feeRemaining = totalFee - feeSubmitted;
    if (feeRemaining < 0) feeRemaining = 0;
  }
  
  // Add payment
  void addPayment(double amount) {
    if (amount <= 0) return;
    feeSubmitted += amount;
    updateFeeRemaining();
    updatedAt = DateTime.now();
  }
  
  @override
  String toString() {
    return 'StudentModel(id: $id, name: $name, classType: $classType, grade: $grade)';
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is StudentModel && other.id == id;
  }
  
  @override
  int get hashCode => id.hashCode;
}

// Extension for List<StudentModel>
extension StudentListExtension on List<StudentModel> {
  double get totalFeeSubmitted => fold(0, (total, student) => total + student.feeSubmitted);
  double get totalFeeRemaining => fold(0, (total, student) => total + student.feeRemaining);
  double get totalFee => fold(0, (total, student) => total + student.totalFee);
  
  List<StudentModel> get activeStudents => where((s) => s.isActive).toList();
  List<StudentModel> get inactiveStudents => where((s) => !s.isActive).toList();
  List<StudentModel> get fscStudents => where((s) => s.isFsc).toList();
  List<StudentModel> get matricStudents => where((s) => s.isMatric).toList();
  List<StudentModel> get feePendingStudents => where((s) => s.feeRemaining > 0).toList();
  List<StudentModel> get feePaidStudents => where((s) => s.feeRemaining <= 0).toList();
  
  Map<String, List<StudentModel>> groupByClass() {
    final Map<String, List<StudentModel>> grouped = {};
    for (final student in this) {
      final key = student.classLevel;
      grouped.putIfAbsent(key, () => []).add(student);
    }
    return grouped;
  }
  
  Map<String, double> getFeeSummaryByClass() {
    final Map<String, double> summary = {};
    for (final student in this) {
      final key = student.classLevel;
      summary[key] = (summary[key] ?? 0) + student.feeRemaining;
    }
    return summary;
  }
}