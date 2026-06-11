import 'package:hive/hive.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
  @HiveField(19)                          // ← NEW: registration timestamp
  DateTime createdAt;

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
    DateTime? createdAt,                  // optional so old code still compiles
  }) : createdAt = createdAt ?? DateTime.now();

  String get name => '$firstName $lastName'.trim();
  String get fullName => name;

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
      'createdAt': Timestamp.fromDate(createdAt), // ← saved to Firestore
    };
  }

  factory StudentModel.fromMap(Map<String, dynamic> map, String docId) {
    // Handle createdAt coming back as Firestore Timestamp or missing
    DateTime parsedCreatedAt;
    final raw = map['createdAt'];
    if (raw is Timestamp) {
      parsedCreatedAt = raw.toDate();
    } else if (raw is String) {
      parsedCreatedAt = DateTime.tryParse(raw) ?? DateTime.now();
    } else {
      parsedCreatedAt = DateTime.now();
    }

    return StudentModel(
      id: docId,
      firstName: map['firstName'] ?? map['name']?.split(' ').first ?? '',
      lastName: map['lastName'] ??
          (map['name']?.split(' ').length > 1
              ? map['name']?.split(' ').sublist(1).join(' ')
              : '') ??
          '',
      fatherName: map['fatherName'] ?? '',
      phone: map['phone'] ?? '',
      email: map['email'] ?? '',
      schedule: map['schedule'] ?? '',
      feeSubmitted: (map['feeSubmitted'] ?? 0).toDouble(),
      feeRemaining: (map['feeRemaining'] ?? 0).toDouble(),
      biologyFee: (map['biologyFee'] ?? 0).toDouble(),
      physicsFee: (map['physicsFee'] ?? 0).toDouble(),
      chemistryFee: (map['chemistryFee'] ?? 0).toDouble(),
      englishFee: (map['englishFee'] ?? 0).toDouble(),
      profilePicUrl: map['profilePicUrl'] ?? '',
      enrollmentStatus: map['enrollmentStatus'] ?? 'active',
      classType: map['classType'] ?? 'FSc',
      grade: map['grade'] ?? 'First Year',
      subject: map['subject'] ?? 'Biology',
      mathFee: (map['mathFee'] ?? 0).toDouble(),
      createdAt: parsedCreatedAt,         // ← read from Firestore
    );
  }
}