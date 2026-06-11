import 'package:flutter_test/flutter_test.dart';
import 'package:my_academy_app/models/student_model.dart';

void main() {
  test('Student serialization roundtrip', () {
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
    );
    final map = s.toMap();
    final s2 = StudentModel.fromMap(map, 'student123');
    expect(s2.id, 'student123');
    expect(s2.firstName, 'John');
    expect(s2.lastName, 'Doe');
    expect(s2.email, 'john@example.com');
    expect(s2.phone, '123456789');
    expect(s2.enrollmentStatus, 'active');
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
}
