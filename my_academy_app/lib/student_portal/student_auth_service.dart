import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import '../models/student_model.dart';

/// Handles all student-specific authentication logic using Firestore.
/// Multi-tier lookup ensures students can log in reliably via QR code or Student ID.
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

  /// Performs robust student login with multi-tier lookup and fallback repair.
  static Future<String> loginStudent({
    required String studentCode,
    required String scannedQrToken,
  }) async {
    final rawCode = studentCode.trim();
    final cleanCode = rawCode.toUpperCase();
    final rawToken = scannedQrToken.trim();

    if (rawCode.isEmpty) {
      throw Exception('Please enter your Student ID.');
    }

    debugPrint('[StudentAuthService] Initiating login for Student Code: "$cleanCode"');

    String? studentId;
    Map<String, dynamic>? authData;

    // ── Tier 1: Search student_auth collection by studentCode field ──
    try {
      final queryByCode = await _firestore
          .collection('student_auth')
          .where('studentCode', isEqualTo: cleanCode)
          .limit(1)
          .get()
          .timeout(const Duration(seconds: 8));

      if (queryByCode.docs.isNotEmpty) {
        authData = queryByCode.docs.first.data();
        studentId = authData['studentId'] as String? ?? queryByCode.docs.first.id;
      } else {
        // Try original raw case if uppercase didn't match
        final queryRaw = await _firestore
            .collection('student_auth')
            .where('studentCode', isEqualTo: rawCode)
            .limit(1)
            .get()
            .timeout(const Duration(seconds: 8));
        if (queryRaw.docs.isNotEmpty) {
          authData = queryRaw.docs.first.data();
          studentId = authData['studentId'] as String? ?? queryRaw.docs.first.id;
        }
      }
    } catch (e) {
      debugPrint('[StudentAuthService] Tier 1 query failed: $e');
    }

    // ── Tier 2: Search student_auth collection by document ID ──
    if (studentId == null) {
      try {
        final docDirect = await _firestore
            .collection('student_auth')
            .doc(rawCode)
            .get()
            .timeout(const Duration(seconds: 8));
        if (docDirect.exists) {
          authData = docDirect.data();
          studentId = authData?['studentId'] as String? ?? docDirect.id;
        } else {
          final docUpper = await _firestore
              .collection('student_auth')
              .doc(cleanCode)
              .get()
              .timeout(const Duration(seconds: 8));
          if (docUpper.exists) {
            authData = docUpper.data();
            studentId = authData?['studentId'] as String? ?? docUpper.id;
          }
        }
      } catch (e) {
        debugPrint('[StudentAuthService] Tier 2 lookup failed: $e');
      }
    }

    // ── Tier 3: Search main students collection & auto-provision student_auth ──
    if (studentId == null) {
      try {
        // Query students by studentCode
        final studentQuery = await _firestore
            .collection('students')
            .where('studentCode', isEqualTo: cleanCode)
            .limit(1)
            .get()
            .timeout(const Duration(seconds: 8));

        DocumentSnapshot<Map<String, dynamic>>? matchedStudentDoc;

        if (studentQuery.docs.isNotEmpty) {
          matchedStudentDoc = studentQuery.docs.first;
        } else {
          // Direct doc ID check in students
          final directStudentDoc = await _firestore
              .collection('students')
              .doc(rawCode)
              .get()
              .timeout(const Duration(seconds: 8));
          if (directStudentDoc.exists) {
            matchedStudentDoc = directStudentDoc;
          }
        }

        if (matchedStudentDoc != null && matchedStudentDoc.exists) {
          studentId = matchedStudentDoc.id;
          final sData = matchedStudentDoc.data() ?? {};
          final sName = '${sData['firstName'] ?? sData['name'] ?? ''} ${sData['lastName'] ?? ''}'.trim();
          
          debugPrint('[StudentAuthService] Found student in main collection. Provisioning student_auth...');
          final createdAuth = await createStudentAuthRecord(
            studentId: studentId,
            studentCode: cleanCode,
            studentName: sName.isNotEmpty ? sName : 'Student',
          );
          authData = {
            'studentId': studentId,
            'studentCode': cleanCode,
            'qrToken': createdAuth['qrToken'],
            'qrTokenHash': createdAuth['qrTokenHash'],
            'accountStatus': 'active',
          };
        }
      } catch (e) {
        debugPrint('[StudentAuthService] Tier 3 lookup failed: $e');
      }
    }

    if (studentId == null || authData == null) {
      throw Exception('Student ID not found. Please verify your Student ID and try again.');
    }

    // ── Account Status Check ──
    final accountStatus = authData['accountStatus'] as String? ?? 'active';
    if (accountStatus.toLowerCase() != 'active') {
      throw Exception('This student account is inactive. Please contact the academy administration.');
    }

    // ── QR Token / Student ID Verification ──
    final storedTokenHash = authData['qrTokenHash'] as String? ?? '';
    final storedPlainToken = authData['qrToken'] as String? ?? '';
    final providedTokenHash = hashQrToken(rawToken);

    bool isTokenValid = false;
    if (storedTokenHash.isNotEmpty && storedTokenHash == providedTokenHash) {
      isTokenValid = true;
    } else if (storedPlainToken.isNotEmpty && storedPlainToken == rawToken) {
      isTokenValid = true;
    } else if (rawToken.toUpperCase() == cleanCode) {
      // Manual Student ID entry access
      isTokenValid = true;
    } else if (storedTokenHash.isEmpty && storedPlainToken.isEmpty) {
      // Uninitialized token fallback
      isTokenValid = true;
    }

    if (!isTokenValid) {
      throw Exception('Invalid QR Code or Student ID. Please scan your official academy QR code.');
    }

    // Ensure studentId matches document ID in main students collection
    try {
      final sDoc = await _firestore.collection('students').doc(studentId).get();
      if (!sDoc.exists) {
        final queryS = await _firestore
            .collection('students')
            .where('studentCode', isEqualTo: cleanCode)
            .limit(1)
            .get();
        if (queryS.docs.isNotEmpty) {
          studentId = queryS.docs.first.id;
        }
      }
    } catch (e) {
      debugPrint('[StudentAuthService] Final studentId verification error: $e');
    }

    // ── Save Session to Local Hive Storage ──
    final String validStudentId = studentId!;
    await _saveSession(studentId: validStudentId, studentCode: cleanCode);

    debugPrint('[StudentAuthService] Login successful for studentId: $validStudentId');
    return validStudentId;
  }

  // ── Session Management ──────────────────────────────────────────────────

  /// Fetches current [StudentModel] using local session info with fallback resolution logic.
  static Future<StudentModel?> fetchCurrentStudent({
    required String studentId,
    String? studentCode,
  }) async {
    // 1. Try direct lookup by studentId
    if (studentId.isNotEmpty) {
      try {
        final doc = await _firestore
            .collection('students')
            .doc(studentId)
            .get()
            .timeout(const Duration(seconds: 8));
        if (doc.exists && doc.data() != null) {
          return StudentModel.fromFirestore(doc);
        }
      } catch (e) {
        debugPrint('[StudentAuthService] Direct fetch failed for $studentId: $e');
      }
    }

    // 2. Query by studentCode if available or fallback
    final codeToQuery = (studentCode != null && studentCode.isNotEmpty)
        ? studentCode
        : studentId;

    if (codeToQuery.isNotEmpty) {
      try {
        final upperCode = codeToQuery.toUpperCase();
        final queryUpper = await _firestore
            .collection('students')
            .where('studentCode', isEqualTo: upperCode)
            .limit(1)
            .get()
            .timeout(const Duration(seconds: 8));

        if (queryUpper.docs.isNotEmpty) {
          final matchedDoc = queryUpper.docs.first;
          await _saveSession(studentId: matchedDoc.id, studentCode: upperCode);
          return StudentModel.fromFirestore(matchedDoc);
        }

        final queryRaw = await _firestore
            .collection('students')
            .where('studentCode', isEqualTo: codeToQuery)
            .limit(1)
            .get()
            .timeout(const Duration(seconds: 8));

        if (queryRaw.docs.isNotEmpty) {
          final matchedDoc = queryRaw.docs.first;
          await _saveSession(studentId: matchedDoc.id, studentCode: codeToQuery);
          return StudentModel.fromFirestore(matchedDoc);
        }
      } catch (e) {
        debugPrint('[StudentAuthService] Query student by code failed: $e');
      }
    }

    // 3. Fallback: full collection lookup by id field or doc ID
    try {
      final allDocs = await _firestore
          .collection('students')
          .get()
          .timeout(const Duration(seconds: 8));

      for (final doc in allDocs.docs) {
        final data = doc.data();
        final sCode = data['studentCode']?.toString().toUpperCase() ?? '';
        final sId = data['id']?.toString() ?? doc.id;
        if (doc.id == studentId || sId == studentId || (studentCode != null && sCode == studentCode.toUpperCase())) {
          await _saveSession(studentId: doc.id, studentCode: sCode.isNotEmpty ? sCode : codeToQuery);
          return StudentModel.fromFirestore(doc);
        }
      }
    } catch (e) {
      debugPrint('[StudentAuthService] Fallback student scan failed: $e');
    }

    return null;
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

  // ── Admin Utilities ──────────────────────────────────────────────────────

  static Future<Map<String, dynamic>?> getStudentAuthInfo(String studentId) async {
    try {
      final doc = await _firestore.collection('student_auth').doc(studentId).get();
      if (doc.exists) {
        return doc.data();
      }
    } catch (e) {
      debugPrint('[StudentAuthService] Error fetching auth info for $studentId: $e');
    }
    return null;
  }

  static Future<Map<String, String>> createStudentAuthRecord({
    required String studentId,
    required String studentCode,
    required String studentName,
  }) async {
    final plainToken = generateQrToken();
    final tokenHash = hashQrToken(plainToken);
    final cleanCode = studentCode.trim().toUpperCase();

    await _firestore.collection('student_auth').doc(studentId).set(
      {
        'studentId': studentId,
        'studentCode': cleanCode,
        'studentName': studentName,
        'qrToken': plainToken,
        'qrTokenHash': tokenHash,
        'qrTokenUpdatedAt': FieldValue.serverTimestamp(),
        'accountStatus': 'active',
        'createdAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    return {
      'studentId': studentId,
      'studentCode': cleanCode,
      'qrToken': plainToken,
      'qrTokenHash': tokenHash,
    };
  }

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

  static Future<void> resetDeviceBinding(String studentId) async {
    await _firestore.collection('student_auth').doc(studentId).set(
      {
        'linkedDeviceId': '',
        'deviceLinkedAt': null,
      },
      SetOptions(merge: true),
    );
  }
}
