import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

/// Handles all student-specific authentication logic:
/// - QR token verification
/// - Device binding (one student = one device)
/// - Session storage
class StudentAuthService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static const String _sessionBoxName = 'student_session';
  static const String _sessionKey = 'session';

  // ── Device Fingerprint ──────────────────────────────────────────────────

  /// Returns a stable device fingerprint hash.
  /// Uses Android ID on Android, identifierForVendor on iOS.
  static Future<String> getDeviceFingerprint() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      String rawId = '';
      if (defaultTargetPlatform == TargetPlatform.android) {
        final info = await deviceInfo.androidInfo;
        rawId = info.id; // Android ID — stable unless factory reset
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        final info = await deviceInfo.iosInfo;
        rawId = info.identifierForVendor ?? 'ios-unknown';
      } else {
        // Fallback for other platforms (web, desktop)
        rawId = 'platform-${defaultTargetPlatform.name}';
      }
      // Hash it so we never store raw device IDs
      return sha256.convert(utf8.encode('QA-DEVICE:$rawId')).toString();
    } catch (e) {
      debugPrint('Device fingerprint error: $e');
      return sha256.convert(utf8.encode('QA-FALLBACK-DEVICE')).toString();
    }
  }

  // ── QR Token Utilities ──────────────────────────────────────────────────

  /// Hashes a plain QR token for secure Firestore storage.
  static String generateQrToken() => const Uuid().v4();

  /// Hashes a plain QR token for secure Firestore storage.
  static String hashQrToken(String token) {
    return sha256.convert(utf8.encode('QA-QR:$token')).toString();
  }

  // ── Student Login Flow ──────────────────────────────────────────────────

  /// Performs full student login:
  /// 1. Verifies studentCode + scanned QR token against Firestore
  /// 2. Checks accountStatus == 'active'
  /// 3. Verifies or binds device
  /// 4. Signs into Firebase Auth with student's linked email/password
  /// 5. Writes session to Hive
  ///
  /// Returns: student Firestore ID (doc ID) on success
  /// Throws: descriptive [Exception] on failure
  static Future<String> loginStudent({
    required String studentCode,
    required String scannedQrToken,
  }) async {
 // Step 0: Ensure an authenticated context (anonymous sign‑in)
    await _auth.signInAnonymously();

    // Step 1: Find student by studentCode in Firestore
    QuerySnapshot<Map<String, dynamic>> studentQuery;
    try {
      studentQuery = await _firestore
          .collection('students')
          .where('id', isEqualTo: studentCode.trim())
          .limit(1)
          .get()
          .timeout(const Duration(seconds: 10));
    } catch (e) {
      await _auth.signOut();
      throw Exception(
          'Cannot connect to server. Please check your internet connection.');
    }

    if (studentQuery.docs.isEmpty) {
      throw Exception('Invalid Student ID. Please check and try again.');
    }

    final studentDoc = studentQuery.docs.first;
    final studentId = studentDoc.id;

    // Step 2: Fetch student_auth record
    DocumentSnapshot<Map<String, dynamic>> authDoc;
    try {
      authDoc = await _firestore
          .collection('student_auth')
          .doc(studentId)
          .get()
          .timeout(const Duration(seconds: 10));
    } catch (e) {
      await _auth.signOut();
      throw Exception('Cannot verify credentials. Please try again.');
    }

    if (!authDoc.exists || authDoc.data() == null) {
      throw Exception(
          'Student account is not configured. Please contact the academy.');
    }

    final authData = authDoc.data()!;

    // Step 3: Check account status
    final accountStatus = authData['accountStatus'] as String? ?? 'inactive';
    if (accountStatus != 'active') {
      throw Exception(
          'This student account is disabled. Please contact the academy.');
    }

    // Step 4: Verify QR token hash
    final storedTokenHash = authData['qrTokenHash'] as String? ?? '';
    final providedTokenHash = hashQrToken(scannedQrToken.trim());
    if (storedTokenHash.isEmpty || storedTokenHash != providedTokenHash) {
      throw Exception(
          'Invalid QR Code. Please use the QR code issued by the academy.');
    }

    // Step 5: Device binding check
    final deviceFingerprint = await getDeviceFingerprint();
    final linkedDeviceId = authData['linkedDeviceId'] as String? ?? '';

    if (linkedDeviceId.isEmpty) {
      // First-time login on a device — bind this device
      await _firestore.collection('student_auth').doc(studentId).update({
        'linkedDeviceId': deviceFingerprint,
        'deviceLinkedAt': FieldValue.serverTimestamp(),
      });
    } else if (linkedDeviceId != deviceFingerprint) {
      throw Exception(
          'This student account is already active on another device. '
          'Please contact the academy administration to reset your device.');
    }

    // Step 6: Sign into Firebase Auth using student's linked credentials
    final authEmail = authData['authEmail'] as String? ?? '';
    final authPassword = authData['authPassword'] as String? ?? '';

    if (authEmail.isEmpty || authPassword.isEmpty) {
      throw Exception(
          'Student account credentials are not configured. Contact the academy.');
    }

    try {
      await _auth.signInWithEmailAndPassword(
        email: authEmail,
        password: authPassword,
      );
    } on FirebaseException catch (e) {
      await _auth.signOut();
      if (e.code == 'user-disabled') {
        throw Exception('This student account has been disabled.');
      }
      throw Exception('Login failed. Please contact the academy.');
    } catch (e) {
      throw Exception('Login failed. Please contact the academy.');
    }

    // Step 7: Save session to Hive
    await _saveSession(studentId: studentId, studentCode: studentCode);

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

  /// Clears student local session and signs out of Firebase Auth.
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
    await _auth.signOut();
  }

  // ── Admin: Generate QR Token for a Student ─────────────────────────────

  /// Generates a new secure QR token and writes the hash to Firestore.
  /// Returns the plain token (to show in the QR code / print).
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

  // ── Admin: Reset Device Binding ─────────────────────────────────────────

  /// Clears the device binding so a student can log in on a new device.
  static Future<void> resetDeviceBinding(String studentId) async {
    await _firestore.collection('student_auth').doc(studentId).update({
      'linkedDeviceId': '',
      'deviceLinkedAt': null,
    });
  }

  // ── Admin: Create Student Auth Record ──────────────────────────────────

  /// Creates the Firestore student_auth record when registering a new student.
  /// Also creates a Firebase Auth account for the student.
  /// Uses a secondary Firebase App to prevent changing the admin session.
  ///
  /// Returns the plain QR token (to print/show in QR code).
  static Future<Map<String, String>> createStudentAuthRecord({
    required String studentId,
    required String studentCode,
    required String studentName,
  }) async {
    // Generate credentials
    final plainToken = generateQrToken();
    final tokenHash = hashQrToken(plainToken);
    // Use student code as email + a fixed domain
    final authEmail =
        '${studentCode.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '')}@quaid-student.app';
    // Password = sha256 of studentId+token (first 16 chars) + fixed suffix
    final authPassword =
        '${sha256.convert(utf8.encode(studentId + plainToken)).toString().substring(0, 12)}Qa!';

    // Create Firebase Auth account using a secondary Firebase App instance
    // so that the current admin user session is not disturbed.
    FirebaseApp? secondaryApp;
    UserCredential cred;
    try {
      // Try to get existing secondary app first to avoid duplicate app error
      try {
        secondaryApp = Firebase.app('StudentCreateApp');
      } catch (_) {
        secondaryApp = await Firebase.initializeApp(
          name: 'StudentCreateApp',
          options: Firebase.app().options,
        );
      }
      final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);
      cred = await secondaryAuth.createUserWithEmailAndPassword(
        email: authEmail,
        password: authPassword,
      );
      await cred.user?.updateDisplayName(studentName);
      await secondaryAuth.signOut();
    } on FirebaseException catch (e) {
      if (e.code == 'email-already-in-use') {
        // Account already exists — regenerate token only
        debugPrint('Student auth account already exists for $studentCode');
        // Still write the new token hash
        await _firestore.collection('student_auth').doc(studentId).set(
          {
            'qrToken': plainToken,
            'qrTokenHash': tokenHash,
            'qrTokenUpdatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
        return {'qrToken': plainToken, 'authEmail': authEmail};
      }
      throw Exception('Failed to create student account: ${e.message}');
    } catch (e) {
      throw Exception('Failed to create student account: $e');
    } finally {
      if (secondaryApp != null) {
        try {
          await secondaryApp.delete();
        } catch (_) {
          // Ignore cleanup errors
        }
      }
    }

    final authUid = cred.user!.uid;
    final batch = _firestore.batch();

    // Write student_auth document
    batch.set(
      _firestore.collection('student_auth').doc(studentId),
      {
        'studentId': studentId,
        'studentCode': studentCode,
        'qrToken': plainToken,
        'qrTokenHash': tokenHash,
        'qrTokenUpdatedAt': FieldValue.serverTimestamp(),
        'linkedDeviceId': '',
        'deviceLinkedAt': null,
        'accountStatus': 'active',
        'authUid': authUid,
        'authEmail': authEmail,
        'authPassword': authPassword, // Stored for admin reset
        'createdAt': FieldValue.serverTimestamp(),
      },
    );

    // Write roles document
    batch.set(
      _firestore.collection('roles').doc(authUid),
      {
        'role': 'student',
        'studentId': studentId,
        'createdAt': FieldValue.serverTimestamp(),
      },
    );

    await batch.commit();

    return {'qrToken': plainToken, 'authEmail': authEmail};
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
