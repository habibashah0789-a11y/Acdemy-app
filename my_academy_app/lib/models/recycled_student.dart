import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';
import 'package:my_academy_app/models/student_model.dart';

@HiveType(typeId: 1)
class RecycledStudent extends StudentModel {
  @HiveField(22)
  DateTime deletedAt;

  RecycledStudent({
    required String id,
    required String firstName,
    required String lastName,
    required String fatherName,
    required String phone,
    required String email,
    required String schedule,
    required double feeSubmitted,
    required double feeRemaining,
    required double biologyFee,
    required double physicsFee,
    required double chemistryFee,
    required double englishFee,
    required String profilePicUrl,
    String enrollmentStatus = 'active',
    String classType = 'FSc',
    String grade = 'First Year',
    String subject = 'Biology',
    double mathFee = 0,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool isActive = true,
    required this.deletedAt,
  }) : super(
          id: id,
          firstName: firstName,
          lastName: lastName,
          fatherName: fatherName,
          phone: phone,
          email: email,
          schedule: schedule,
          feeSubmitted: feeSubmitted,
          feeRemaining: feeRemaining,
          biologyFee: biologyFee,
          physicsFee: physicsFee,
          chemistryFee: chemistryFee,
          englishFee: englishFee,
          profilePicUrl: profilePicUrl,
          enrollmentStatus: enrollmentStatus,
          classType: classType,
          grade: grade,
          subject: subject,
          mathFee: mathFee,
          createdAt: createdAt ?? DateTime.now(),
          updatedAt: updatedAt,
          isActive: isActive,
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
