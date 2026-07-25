import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_academy_app/models/student_model.dart';
import 'package:my_academy_app/models/recycled_student.dart';

void main() {
  test('Student serialization roundtrip with legacy fields', () {
    final s = StudentModel(
      id: 'student123',
      firstName: 'John',
      lastName: 'Doe',
      email: 'john@example.com',
      phone: '123456789',
      enrollmentStatus: 'active',
      fatherName: 'Mr. Doe',
      schedule: 'Morning',
      feeSubmitted: 1000,
      feeRemaining: 500,
      biologyFee: 0,
      physicsFee: 0,
      chemistryFee: 0,
      englishFee: 0,
      profilePicUrl: '',
      subject: 'Biology',
    );
    final map = s.toMap();
    final s2 = StudentModel.fromMap(map, 'student123');
    expect(s2.id, 'student123');
    expect(s2.firstName, 'John');
    expect(s2.lastName, 'Doe');
    expect(s2.email, 'john@example.com');
    expect(s2.phone, '123456789');
    expect(s2.enrollmentStatus, 'active');
    
    // Check fallback logic
    expect(s2.subjectSchedules, {'Biology': 'Morning'});
    expect(s2.getScheduleForSubject('Biology'), 'Morning');
  });

  test('Student serialization with multiple subjects and schedules', () {
    final originalSchedules = {
      'Chemistry': '9:00 AM',
      'Math': '10:00 AM',
    };
    final s = StudentModel(
      id: 'student456',
      firstName: 'Jane',
      lastName: 'Smith',
      email: 'jane@example.com',
      phone: '987654321',
      fatherName: 'Mr. Smith',
      schedule: 'Chemistry: 9:00 AM, Math: 10:00 AM',
      feeSubmitted: 2000,
      feeRemaining: 1000,
      biologyFee: 0,
      physicsFee: 0,
      chemistryFee: 1500,
      englishFee: 0,
      mathFee: 1500,
      profilePicUrl: '',
      subject: 'Chemistry, Math',
      subjectSchedulesJson: jsonEncode(originalSchedules),
    );

    final map = s.toMap();
    final s2 = StudentModel.fromMap(map, 'student456');

    expect(s2.subjectSchedules, originalSchedules);
    expect(s2.getScheduleForSubject('Chemistry'), '9:00 AM');
    expect(s2.getScheduleForSubject('Math'), '10:00 AM');
    expect(s2.getScheduleForSubject('Biology'), '');
    expect(s2.totalFee, 3000);
  });

  test('Student fullName getter', () {
    final s = StudentModel(
      id: '1',
      firstName: 'Jane',
      lastName: 'Smith',
      email: 'jane@example.com',
      phone: '987654321',
      fatherName: '',
      schedule: '',
      feeSubmitted: 0,
      feeRemaining: 0,
      biologyFee: 0,
      physicsFee: 0,
      chemistryFee: 0,
      englishFee: 0,
      profilePicUrl: '',
    );
    expect(s.fullName, 'Jane Smith');
  });

  test('RecycledStudent serialization roundtrip', () {
    final deletedTime = DateTime.now();
    final r = RecycledStudent(
      id: 'studentRecycled',
      firstName: 'Recycled',
      lastName: 'User',
      email: 'recycled@example.com',
      phone: '123',
      fatherName: 'Father',
      schedule: 'Afternoon',
      feeSubmitted: 500,
      feeRemaining: 100,
      biologyFee: 0,
      physicsFee: 0,
      chemistryFee: 0,
      englishFee: 0,
      profilePicUrl: '',
      deletedAt: deletedTime,
      paymentHistoryJson: '[]',
    );
    final map = r.toRecycleMap();
    final r2 = RecycledStudent.fromMap(map, 'studentRecycled');
    expect(r2.id, 'studentRecycled');
    expect(r2.firstName, 'Recycled');
    expect(r2.lastName, 'User');
    expect(r2.deletedAt.millisecondsSinceEpoch, deletedTime.millisecondsSinceEpoch);
    expect(r2.paymentHistoryJson, '[]');
  });
}
