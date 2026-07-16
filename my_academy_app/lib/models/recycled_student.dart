import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';
import 'package:my_academy_app/models/student_model.dart';

@HiveType(typeId: 1)
class RecycledStudent extends StudentModel {
  @HiveField(22)
  DateTime deletedAt;

  RecycledStudent({
    required super.id,
    required super.firstName,
    required super.lastName,
    required super.fatherName,
    required super.phone,
    required super.email,
    required super.schedule,
    required super.feeSubmitted,
    required super.feeRemaining,
    required super.biologyFee,
    required super.physicsFee,
    required super.chemistryFee,
    required super.englishFee,
    required super.profilePicUrl,
    super.enrollmentStatus = 'active',
    super.classType = 'FSc',
    super.grade = 'First Year',
    super.subject = 'Biology',
    super.mathFee = 0,
    DateTime? createdAt,
    super.updatedAt,
    super.isActive = true,
    required this.deletedAt,
  }) : super(
          createdAt: createdAt ?? DateTime.now(),
        );

  Map<String, dynamic> toRecycleMap() {
    final map = toMap();    
    map['deletedAt'] = Timestamp.fromDate(deletedAt);
    return map;
  }

  factory RecycledStudent.fromMap(Map<String, dynamic> map, String docId) {
    final student = StudentModel.fromMap(map, docId);
    // Handle deletedAt as Timestamp (Firestore), String (ISO), or DateTime
    DateTime deletedAt;
    final raw = map['deletedAt'];
    if (raw is Timestamp) {
      deletedAt = raw.toDate();
    } else if (raw is String) {
      deletedAt = DateTime.tryParse(raw) ?? DateTime.now();
    } else if (raw is DateTime) {
      deletedAt = raw;
    } else {
      deletedAt = DateTime.now();
    }
    return RecycledStudent(
      id: student.id,
      firstName: student.firstName,
      lastName: student.lastName,
      fatherName: student.fatherName,
      phone: student.phone,
      email: student.email,
      schedule: student.schedule,
      feeSubmitted: student.feeSubmitted,
      feeRemaining: student.feeRemaining,
      biologyFee: student.biologyFee,
      physicsFee: student.physicsFee,
      chemistryFee: student.chemistryFee,
      englishFee: student.englishFee,
      profilePicUrl: student.profilePicUrl,
      enrollmentStatus: student.enrollmentStatus,
      classType: student.classType,
      grade: student.grade,
      subject: student.subject,
      mathFee: student.mathFee,
      createdAt: student.createdAt,
      updatedAt: student.updatedAt,
      isActive: student.isActive,
      deletedAt: deletedAt,
    );
  }
}
