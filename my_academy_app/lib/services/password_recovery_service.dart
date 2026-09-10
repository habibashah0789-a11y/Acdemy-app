import 'dart:async';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/teacher_model.dart';
import 'audit_log_service.dart';

/// Handles password recovery, OTP generation, verification, and portal access routing
/// for both Administrators and Teachers.
class PasswordRecoveryService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Generates a cryptographically strong 6-digit numeric OTP.
  static String _generateOtp() {
    final random = math.Random.secure();
    final otp = 100000 + random.nextInt(900000);
    return otp.toString();
  }

  /// Sends a 6-digit verification OTP and a Firebase Auth password reset link
  /// to the given email, tailored for the requested role ('admin' or 'teacher').
  static Future<Map<String, dynamic>> sendRecoveryOtpAndLink({
    required String email,
    required String role,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    if (cleanEmail.isEmpty || !cleanEmail.contains('@')) {
      throw Exception('Please enter a valid email address.');
    }

    String userName = (role == 'admin') ? 'Administrator' : 'Teacher';
    TeacherModel? matchedTeacher;

    // 1. Verify existence based on role
    if (role == 'teacher') {
      final query = await _firestore
          .collection('teachers')
          .where('email', isEqualTo: cleanEmail)
          .limit(1)
          .get()
          .timeout(const Duration(seconds: 5));

      if (query.docs.isEmpty) {
        // Fallback: check all teachers case-insensitively
        final allTeachers = await _firestore.collection('teachers').get();
        final found = allTeachers.docs.where(
          (d) => (d.data()['email'] ?? '').toString().trim().toLowerCase() == cleanEmail,
        );
        if (found.isEmpty) {
          throw Exception('No registered teacher found with email: $cleanEmail.');
        }
        matchedTeacher = TeacherModel.fromFirestore(found.first);
      } else {
        matchedTeacher = TeacherModel.fromFirestore(query.docs.first);
      }

      if (!matchedTeacher.isActive) {
        throw Exception('This teacher account is deactivated. Please contact academy administration.');
      }
      userName = matchedTeacher.name;
    } else {
      // Admin account: verify email has admin privileges if known
      try {
        final adminQuery = await _firestore
            .collection('admins')
            .where('email', isEqualTo: cleanEmail)
            .limit(1)
            .get();
        if (adminQuery.docs.isNotEmpty) {
          userName = adminQuery.docs.first.data()['name'] ?? 'Administrator';
        }
      } catch (_) {}
    }

    // 2. Generate 6-digit OTP and set 15-minute expiration
    final otp = _generateOtp();
    final expiresAt = DateTime.now().add(const Duration(minutes: 15));
    final docId = cleanEmail.replaceAll('.', '_').replaceAll('@', '_at_');

    final otpData = {
      'email': cleanEmail,
      'otp': otp,
      'role': role,
      'userName': userName,
      'teacherId': matchedTeacher?.id,
      'expiresAt': Timestamp.fromDate(expiresAt),
      'createdAt': FieldValue.serverTimestamp(),
      'isUsed': false,
      'attempts': 0,
    };

    // Store in Firestore verification_otps collection
    await _firestore
        .collection('verification_otps')
        .doc(docId)
        .set(otpData, SetOptions(merge: true));

    // 3. Send official Firebase Password Reset Email Link
    bool resetEmailSent = false;
    String? resetEmailError;
    try {
      // First try sending with ActionCodeSettings targeting the app web/mobile continue URL
      try {
        final actionCodeSettings = ActionCodeSettings(
          url: 'https://quaid-academy.web.app/?mode=resetPassword&email=$cleanEmail&role=$role',
          handleCodeInApp: true,
          androidPackageName: 'com.example.myAcademyApp',
          androidInstallApp: true,
          androidMinimumVersion: '1',
        );
        await _auth.sendPasswordResetEmail(
          email: cleanEmail,
          actionCodeSettings: actionCodeSettings,
        );
        resetEmailSent = true;
        debugPrint('[PasswordRecoveryService] Password reset link sent with ActionCodeSettings to $cleanEmail');
      } catch (settingsError) {
        debugPrint('[PasswordRecoveryService] ActionCodeSettings failed ($settingsError), falling back to standard reset link');
        await _auth.sendPasswordResetEmail(email: cleanEmail);
        resetEmailSent = true;
        debugPrint('[PasswordRecoveryService] Firebase standard password reset link sent to $cleanEmail');
      }
    } catch (e) {
      debugPrint('[PasswordRecoveryService] Firebase reset email failed: $e');
      resetEmailError = e.toString();
    }

    // 4. Queue custom branded email into Firestore 'mail' collection (Firebase Email Extension)
    try {
      await _firestore.collection('mail').add({
        'to': [cleanEmail],
        'message': {
          'subject': '[$userName] Quaid Academy Verification OTP: $otp & Password Reset',
          'text': 'Your Quaid Academy verification code is: $otp. This code expires in 15 minutes. Use the reset link or OTP to access your portal.',
          'html': '''
            <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 24px; border: 1px solid #e2e8f0; border-radius: 16px;">
              <div style="text-align: center; margin-bottom: 20px;">
                <h1 style="color: #1E3A8A; margin: 0;">Quaid Academy</h1>
                <p style="color: #64748B; margin-top: 4px; font-size: 14px;">Portal Access & Security Verification</p>
              </div>
              <p style="font-size: 15px; color: #1E293B;">Hello <strong>$userName</strong>,</p>
              <p style="font-size: 14px; color: #334155; line-height: 1.6;">
                You requested a security verification code to access your <strong>${role.toUpperCase()}</strong> portal or reset your password.
              </p>
              <div style="background: #EFF6FF; border: 2px dashed #2563EB; padding: 20px; text-align: center; border-radius: 12px; margin: 24px 0;">
                <span style="font-size: 36px; font-weight: bold; letter-spacing: 8px; color: #1E3A8A; display: block;">$otp</span>
                <span style="font-size: 12px; color: #64748B; margin-top: 8px; display: block;">Valid for 15 minutes</span>
              </div>
              <p style="color: #64748B; font-size: 13px; line-height: 1.5;">
                Enter this 6-digit code in the app to verify your identity and access your portal directly.
                ${resetEmailSent ? '<br/>We have also sent an official password reset link to this email. Once reset, the app will authenticate you and load your portal.' : ''}
              </p>
              <hr style="border: 0; border-top: 1px solid #e2e8f0; margin: 24px 0;" />
              <p style="font-size: 11px; color: #94A3B8; text-align: center;">
                Quaid Academy Management System &bull; Automated Security Notification &bull; Do not share this code.
              </p>
            </div>
          ''',
        },
      });
    } catch (e) {
      debugPrint('[PasswordRecoveryService] Mail queue write error: $e');
    }

    // 5. Log audit trail
    try {
      await AuditLogService.logAction(
        actorId: cleanEmail,
        actorName: userName,
        actorRole: role.toUpperCase(),
        action: 'PASSWORD_RECOVERY_REQUESTED',
        transactionId: docId,
        details: 'OTP verification ($otp) & reset link requested for $role ($cleanEmail).',
      );
    } catch (_) {}

    return {
      'success': true,
      'otp': otp,
      'email': cleanEmail,
      'userName': userName,
      'role': role,
      'teacher': matchedTeacher,
      'resetEmailSent': resetEmailSent,
      'resetEmailError': resetEmailError,
      'expiresAt': expiresAt,
    };
  }

  /// Verifies the entered 6-digit OTP for the given email and role.
  static Future<Map<String, dynamic>> verifyOtp({
    required String email,
    required String enteredOtp,
    required String role,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    final cleanOtp = enteredOtp.trim().replaceAll(' ', '');
    final docId = cleanEmail.replaceAll('.', '_').replaceAll('@', '_at_');

    if (cleanOtp.length != 6) {
      throw Exception('Please enter all 6 digits of the verification code.');
    }

    final docSnap = await _firestore.collection('verification_otps').doc(docId).get();
    if (!docSnap.exists || docSnap.data() == null) {
      throw Exception('No active verification code found for $cleanEmail. Please request a new code.');
    }

    final data = docSnap.data()!;
    final storedOtp = data['otp']?.toString().trim() ?? '';
    final isUsed = data['isUsed'] == true;
    final expiresAtTimestamp = data['expiresAt'] as Timestamp?;
    final expiresAt = expiresAtTimestamp?.toDate() ?? DateTime.now().subtract(const Duration(minutes: 1));

    if (isUsed) {
      throw Exception('This verification code has already been used. Please request a fresh code.');
    }

    if (DateTime.now().isAfter(expiresAt)) {
      throw Exception('This verification code has expired. Please request a new code.');
    }

    if (storedOtp != cleanOtp) {
      try {
        await _firestore.collection('verification_otps').doc(docId).update({
          'attempts': FieldValue.increment(1),
        });
      } catch (_) {}
      throw Exception('Incorrect verification code. Please check your email and try again.');
    }

    // Mark as used
    await _firestore.collection('verification_otps').doc(docId).update({
      'isUsed': true,
      'verifiedAt': FieldValue.serverTimestamp(),
    });

    // Load teacher profile if teacher role
    TeacherModel? teacher;
    if (role == 'teacher') {
      final teacherId = data['teacherId'] as String?;
      if (teacherId != null && teacherId.isNotEmpty) {
        final tDoc = await _firestore.collection('teachers').doc(teacherId).get();
        if (tDoc.exists) {
          teacher = TeacherModel.fromFirestore(tDoc);
        }
      }
      if (teacher == null) {
        final tQuery = await _firestore.collection('teachers').where('email', isEqualTo: cleanEmail).limit(1).get();
        if (tQuery.docs.isNotEmpty) {
          teacher = TeacherModel.fromFirestore(tQuery.docs.first);
        }
      }
    }

    // Log successful verification in audit logs
    try {
      await AuditLogService.logAction(
        actorId: cleanEmail,
        actorName: data['userName'] ?? role,
        actorRole: role.toUpperCase(),
        action: 'PASSWORD_RECOVERY_OTP_VERIFIED',
        transactionId: docId,
        details: 'OTP verified successfully for $role ($cleanEmail). Access granted.',
      );
    } catch (_) {}

    return {
      'verified': true,
      'role': role,
      'email': cleanEmail,
      'userName': data['userName'] ?? (role == 'admin' ? 'Administrator' : 'Teacher'),
      'teacher': teacher,
    };
  }
}
