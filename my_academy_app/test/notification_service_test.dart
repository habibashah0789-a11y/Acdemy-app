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

  group('Teacher Notification Filtering Tests', () {
    const teacherBiology = TeacherModel(
      id: 'teacher-bio-uid',
      name: 'Sir Ahmed',
      email: 'ahmed@academy.com',
      teacherId: 'T-BIO-FSC-001',
      subject: 'Biology',
      section: 'FSc',
      assignedClasses: ['First Year', 'Second Year'],
      createdAt: null as dynamic,
    );

    test('Teacher receives payout notification specifically addressed to them', () {
      final payoutNotif = NotificationModel(
        id: 'payout_123',
        title: '💵 Payment Received: Rs 50000',
        message: 'Payment credited',
        studentName: 'Sir Ahmed',
        className: 'FSc',
        subject: 'Biology',
        registeredBy: 'Admin',
        timestamp: DateTime.now(),
        notificationType: 'teacher_payout',
        isRead: false,
        teacherId: 'teacher-bio-uid',
      );

      expect(NotificationService.isNotificationForTeacher(teacherBiology, payoutNotif), isTrue);
    });

    test('Teacher DOES NOT receive payout notification addressed to another teacher', () {
      final otherPayoutNotif = NotificationModel(
        id: 'payout_456',
        title: '💵 Payment Received: Rs 40000',
        message: 'Payment credited',
        studentName: 'Sir Bilal',
        className: 'FSc',
        subject: 'Physics',
        registeredBy: 'Admin',
        timestamp: DateTime.now(),
        notificationType: 'teacher_payout',
        isRead: false,
        teacherId: 'teacher-phy-uid',
      );

      expect(NotificationService.isNotificationForTeacher(teacherBiology, otherPayoutNotif), isFalse);
    });

    test('Teacher receives student registration notification for student enrolled in their subject', () {
      final studentBioReg = NotificationModel(
        id: 'reg_student_1',
        title: '🎓 New Student Registered',
        message: 'Enrolled in Biology',
        studentName: 'Ali Khan',
        className: 'FSc',
        subject: 'Biology',
        registeredBy: 'Admin',
        timestamp: DateTime.now(),
        notificationType: 'student_registered',
        isRead: false,
      );

      expect(NotificationService.isNotificationForTeacher(teacherBiology, studentBioReg), isTrue);
    });

    test('Teacher DOES NOT receive student registration notification for other subjects', () {
      final studentMathReg = NotificationModel(
        id: 'reg_student_2',
        title: '🎓 New Student Registered',
        message: 'Enrolled in Mathematics',
        studentName: 'Usman Ali',
        className: 'FSc',
        subject: 'Mathematics',
        registeredBy: 'Admin',
        timestamp: DateTime.now(),
        notificationType: 'student_registered',
        isRead: false,
      );

      expect(NotificationService.isNotificationForTeacher(teacherBiology, studentMathReg), isFalse);
    });

    test('Teacher receives fee payment notification for their subject student', () {
      final feeBioNotif = NotificationModel(
        id: 'pay_student_1',
        title: '💳 Fee Payment: Ali Khan',
        message: 'Paid fee for Biology',
        studentName: 'Ali Khan',
        className: 'FSc',
        subject: 'Biology',
        registeredBy: 'Admin',
        timestamp: DateTime.now(),
        notificationType: 'fee_payment',
        isRead: false,
      );

      expect(NotificationService.isNotificationForTeacher(teacherBiology, feeBioNotif), isTrue);
    });

    test('Teacher DOES NOT receive fee payment notification when fee was paid for another subject', () {
      final feePhyNotif = NotificationModel(
        id: 'pay_student_1_Physics_123',
        title: '💳 Fee Payment: Ali Khan',
        message: 'Student Ali Khan (FSc First Year - Physics) has paid a fee installment of Rs 3000.',
        studentName: 'Ali Khan',
        className: 'FSc',
        subject: 'Physics',
        registeredBy: 'Admin',
        timestamp: DateTime.now(),
        notificationType: 'fee_payment',
        isRead: false,
      );

      expect(NotificationService.isNotificationForTeacher(teacherBiology, feePhyNotif), isFalse);
    });

    test('Teacher DOES NOT receive multi-subject general fee notification', () {
      final multiSubNotif = NotificationModel(
        id: 'pay_student_1_general',
        title: '💳 Fee Payment Received',
        message: 'Ali Khan has paid Rs 5000.',
        studentName: 'Ali Khan',
        className: 'FSc',
        subject: 'Biology, Physics, Chemistry',
        registeredBy: 'Admin',
        timestamp: DateTime.now(),
        notificationType: 'fee_payment',
        isRead: false,
      );

      expect(NotificationService.isNotificationForTeacher(teacherBiology, multiSubNotif), isFalse);
    });

    test('Teacher receives fee edited notification specifically for their subject', () {
      final feeEditBioNotif = NotificationModel(
        id: 'fee_edit_student_1_Biology_123',
        title: '📝 Fee Updated: Ali Khan',
        message: 'Fee details for Ali Khan (FSc First Year - Biology) have been edited: Total Rs 6000, Paid Rs 2000.',
        studentName: 'Ali Khan',
        className: 'FSc',
        subject: 'Biology',
        registeredBy: 'Admin',
        timestamp: DateTime.now(),
        notificationType: 'fee_edited',
        isRead: false,
      );

      expect(NotificationService.isNotificationForTeacher(teacherBiology, feeEditBioNotif), isTrue);
    });

    test('Teacher DOES NOT receive fee edited notification for another subject', () {
      final feeEditChemNotif = NotificationModel(
        id: 'fee_edit_student_1_Chemistry_123',
        title: '📝 Fee Updated: Ali Khan',
        message: 'Fee details for Ali Khan (FSc First Year - Chemistry) have been edited: Total Rs 6000, Paid Rs 2000.',
        studentName: 'Ali Khan',
        className: 'FSc',
        subject: 'Chemistry',
        registeredBy: 'Admin',
        timestamp: DateTime.now(),
        notificationType: 'fee_edited',
        isRead: false,
      );

      expect(NotificationService.isNotificationForTeacher(teacherBiology, feeEditChemNotif), isFalse);
    });

    test('Teacher DOES NOT receive generic admin announcements or fee reminders', () {
      final genericAdminNotif = NotificationModel(
        id: 'announcement_1',
        title: '📢 Academy Holiday',
        message: 'Academy will remain closed tomorrow',
        studentName: '',
        className: 'All',
        subject: 'General',
        registeredBy: 'Admin',
        timestamp: DateTime.now(),
        notificationType: 'admin_announcement',
        isRead: false,
      );

      expect(NotificationService.isNotificationForTeacher(teacherBiology, genericAdminNotif), isFalse);
    });
  });
}

