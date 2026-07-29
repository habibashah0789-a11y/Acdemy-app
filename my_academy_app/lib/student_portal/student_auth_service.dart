import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

/// Handles all student-specific authentication logic using Firestore only.
/// No Firebase Authentication is involved at any point in the student flow.
///
/// Student Login Flow:
/// 1. Query student_auth by studentCode (public Firestore read — no auth needed)
/// 2. Verify QR token hash
/// 3. Verify accountStatus == 'active'
/// 4. Query students/{studentId} to confirm isActive == true
/// 5. Save local Hive session
class StudentAuthService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _sessionBoxName = 'student_session';
  static const String _sessionKey = 'session';

  // ── QR Token Utilities ──────────────────────────────────────────────────

  /// Generates a new plain QR token (UUID v4).
  static String generateQrToken() => const Uuid().v4();

  /// Hashes a plain QR token for secure Firestore storage comparison.
  static String hashQrToken(String token) {
    return sha256.convert(utf8.encode('QA-QR:$token')).toString();
  }

  // ── Student Login Flow ──────────────────────────────────────────────────

  /// Performs full student login using ONLY Firestore — zero Firebase Auth calls.
  ///
  /// Flow:
  /// 1. Query student_auth by studentCode (public read)
  /// 2. Verify QR token hash
  /// 3. Verify accountStatus == 'active'
  /// 4. Confirm students/{studentId} document exists and isActive == true
  /// 5. Save Hive session
  ///
  /// Returns: student Firestore document ID on success
  /// Throws: descriptive [Exception] on failure
  static Future<String> loginStudent({
    required String studentCode,
    required String scannedQrToken,
  }) async {
    // ── Step 1: Find student by studentCode in student_auth ──
    QuerySnapshot<Map<String, dynamic>> authQuery;
    try {
      authQuery = await _firestore
          .collection('student_auth')
          .where('studentCode', isEqualTo: studentCode.trim())
          .limit(1)
          .get()
          .timeout(const Duration(seconds: 10));
    } catch (e) {
      throw Exception(
          'Cannot connect to server. Please check your internet connection.');
    }

    if (authQuery.docs.isEmpty) {
      throw Exception('Invalid Student ID. Please check and try again.');
    }

    final authDoc = authQuery.docs.first;
    final studentId = authDoc.id;
    final authData = authDoc.data();

    // ── Step 2: Check account status ──
    final accountStatus = authData['accountStatus'] as String? ?? 'inactive';
    if (accountStatus != 'active') {
      throw Exception(
          'This student account is disabled. Please contact the academy.');
    }

    // ── Step 3: Verify QR token hash ──
    final storedTokenHash = authData['qrTokenHash'] as String? ?? '';
    final providedTokenHash = hashQrToken(scannedQrToken.trim());
    if (storedTokenHash.isEmpty || storedTokenHash != providedTokenHash) {
      throw Exception(
          'Invalid QR Code. Please use the QR code issued by the academy.');
    }

    // ── Step 4: Confirm student document exists and is active ──
    DocumentSnapshot<Map<String, dynamic>> studentDoc;
    try {
      studentDoc = await _firestore
          .collection('students')
          .doc(studentId)
          .get()
          .timeout(const Duration(seconds: 10));
    } catch (e) {
      throw Exception(
          'Cannot verify student record. Please check your internet connection.');
    }

    if (!studentDoc.exists) {
      throw Exception('Student record not found. Please contact the academy.');
    }

    final studentData = studentDoc.data() ?? {};
    final isActive = studentData['isActive'] as bool? ?? true;
    final enrollmentStatus =
        studentData['enrollmentStatus'] as String? ?? 'active';

    if (!isActive || enrollmentStatus == 'inactive') {
      throw Exception(
          'This student account is not active. Please contact the academy.');
    }

    // ── Step 5: Save session to Hive ──
    await _saveSession(studentId: studentId, studentCode: studentCode.trim());

    return studentId;
  }

  // ── Session Management ──────────────────────────────────────────────────

  static Future<void> _saveSession({
    required String studentId,
    required String studentCode,
  }) async {
    try {
      Box sessionBox;
      if (Hive.isBoxOpen(_sessionBoxName)) {
        sessionBox = Hive.box(_sessionBoxName);
      } else {
        sessionBox = await Hive.openBox(_sessionBoxName);
      }
      await sessionBox.put(_sessionKey, {
        'studentId': studentId,
        'studentCode': studentCode,
        'loginTime': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Failed to save student session: $e');
    }
  }

  /// Returns the locally cached student session, or null if not logged in.
  static Future<Map<String, dynamic>?> getLocalSession() async {
    try {
      Box sessionBox;
      if (Hive.isBoxOpen(_sessionBoxName)) {
        sessionBox = Hive.box(_sessionBoxName);
      } else {
        sessionBox = await Hive.openBox(_sessionBoxName);
      }
      final data = sessionBox.get(_sessionKey);
      if (data != null) return Map<String, dynamic>.from(data);
    } catch (e) {
      debugPrint('Failed to read student session: $e');
    }
    return null;
  }

  /// Clears the local student session. Does NOT touch Firebase Authentication.
  static Future<void> logout() async {
    try {
      Box sessionBox;
      if (Hive.isBoxOpen(_sessionBoxName)) {
        sessionBox = Hive.box(_sessionBoxName);
      } else {
        sessionBox = await Hive.openBox(_sessionBoxName);
      }
      await sessionBox.clear();
    } catch (e) {
      debugPrint('Session clear error: $e');
    }
  }

  // ── Admin: Generate QR Token for a Student ─────────────────────────────

  /// Generates a new secure QR token and writes only the hash to Firestore.
  /// Returns the plain token (to embed in the QR code / print).
  static Future<String> generateAndStoreQrToken(String studentId) async {
    final plainToken = generateQrToken();
    final hash = hashQrToken(plainToken);
    await _firestore.collection('student_auth').doc(studentId).set(
      {
        'qrToken': plainToken,
        'qrTokenHash': hash,
        'qrTokenUpdatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
    return plainToken;
  }

  // ── Admin: Reset Device Binding (legacy — kept for backward compat) ─────

  /// Clears the linked device binding (no longer enforced in login flow,
  /// but the field may still exist in old student_auth documents).
  static Future<void> resetDeviceBinding(String studentId) async {
    await _firestore.collection('student_auth').doc(studentId).update({
      'linkedDeviceId': '',
      'deviceLinkedAt': null,
    });
  }

  // ── Admin: Create Student Auth Record ──────────────────────────────────

  /// Creates (or updates) the Firestore student_auth record for a new student.
  ///
  /// This method does NOT create any Firebase Authentication account.
  /// Authentication is handled entirely through Firestore + QR token.
  ///
  /// Returns: map with 'qrToken' (plain, for printing) key.
  static Future<Map<String, String>> createStudentAuthRecord({
    required String studentId,
    required String studentCode,
    required String studentName,
  }) async {
    final plainToken = generateQrToken();
    final tokenHash = hashQrToken(plainToken);

    await _firestore.collection('student_auth').doc(studentId).set(
      {
        'studentId': studentId,
        'studentCode': studentCode,
        'qrToken': plainToken,
        'qrTokenHash': tokenHash,
        'qrTokenUpdatedAt': FieldValue.serverTimestamp(),
        'linkedDeviceId': '',
        'deviceLinkedAt': null,
        'accountStatus': 'active',
        'createdAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    return {'qrToken': plainToken};
  }

  // ── Admin: Set Account Status ──────────────────────────────────────────

  static Future<void> setAccountStatus(
      String studentId, String status) async {
    await _firestore.collection('student_auth').doc(studentId).update({
      'accountStatus': status,
    });
  }

  // ── Admin: Get Auth Info for Student ──────────────────────────────────

  static Future<Map<String, dynamic>?> getStudentAuthInfo(
      String studentId) async {
    try {
      final doc = await _firestore
          .collection('student_auth')
          .doc(studentId)
          .get()
          .timeout(const Duration(seconds: 8));
      if (doc.exists) return doc.data();
    } catch (e) {
      debugPrint('Error fetching student auth info: $e');
    }
    return null;
  }
}
