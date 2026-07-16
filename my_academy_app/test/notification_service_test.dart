import 'package:flutter_test/flutter_test.dart';
import 'package:my_academy_app/models/notification_model.dart';
import 'package:my_academy_app/models/student_model.dart';
import 'package:my_academy_app/services/notification_service.dart';

void main() {
  test('builds a student registration notification with expected content', () {
    final student = StudentModel(
      id: 'student-1',
      firstName: 'Ali',
      lastName: 'Khan',
      fatherName: 'Imran',
      phone: '03001234567',
      email: 'ali@example.com',
      schedule: '7:00 AM',
      feeSubmitted: 0,
      feeRemaining: 12000,
      biologyFee: 12000,
      physicsFee: 0,
      chemistryFee: 0,
      englishFee: 0,
      profilePicUrl: '',
      classType: 'FSc',
      grade: 'First Year',
      subject: 'Biology',
    );

    final notification = NotificationService.buildStudentRegistrationNotification(
      student: student,
      registeredBy: 'Admin User',
    );

    expect(notification.notificationType, 'student_registered');
    expect(notification.title, 'New Student Registered');
    expect(notification.studentName, 'Ali Khan');
    expect(notification.studentClass, 'FSc');
    expect(notification.subject, 'Biology');
    expect(notification.registeredBy, 'Admin User');
    expect(notification.isRead, isFalse);
  });

  test('notification model serializes and deserializes correctly', () {
    final notification = NotificationModel(
      id: 'n1',
      title: 'Test',
      message: 'Message',
      studentName: 'Test Student',
      className: 'FSc',
      subject: 'Physics',
      registeredBy: 'Admin',
      timestamp: DateTime(2024, 1, 1),
      notificationType: 'student_registered',
      isRead: false,
    );

    final map = notification.toMap();
    final restored = NotificationModel.fromMap(map, 'n1');

    expect(restored.title, notification.title);
    expect(restored.message, notification.message);
    expect(restored.isRead, notification.isRead);
  });
}
