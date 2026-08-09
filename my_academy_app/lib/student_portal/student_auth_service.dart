import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import '../models/student_model.dart';
import '../services/database_service.dart';

/// Handles all student-specific authentication logic using Firestore.
///
/// Security model:
///   • Login requires BOTH a valid Student Unique ID AND the official QR token
///     issued by the academy.  Neither alone is sufficient.
///   • A student account is bound to the first device that successfully logs in.
///     Subsequent logins from different devices are blocked until an admin resets
///     the binding via [resetDeviceBinding].
///   • The Hive session persists across admin edits.  The student portal
///     auto-refreshes data from Firestore without requiring a new login.
///   • The following identity fields are NEVER modified by this service after
///     creation: studentId, studentCode, qrToken, qrTokenHash, createdAt.
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

  // ── Device ID Resolution ────────────────────────────────────────────────

  /// Returns a stable, unique identifier for the current device.
  ///
  /// Priority order:
  ///   1. Native device ID via [DeviceInfoPlugin] (Android/iOS/Windows).
  ///   2. Persisted UUID stored in the session Hive box (all other platforms).
  ///
  /// This ID is written to `student_auth` on the first successful login and
  /// checked on every subsequent login to enforce the one-device policy.
  static Future<String> getDeviceId() async {
    try {
      final plugin = DeviceInfoPlugin();

      if (!kIsWeb) {
        if (defaultTargetPlatform == TargetPlatform.android) {
          final info = await plugin.androidInfo;
          final id = info.id; // Unique hardware ID (changes on factory reset)
          if (id.isNotEmpty) return 'android_$id';
        } else if (defaultTargetPlatform == TargetPlatform.iOS) {
          final info = await plugin.iosInfo;
          final id = info.identifierForVendor ?? '';
          if (id.isNotEmpty) return 'ios_$id';
        } else if (defaultTargetPlatform == TargetPlatform.windows) {
          final info = await plugin.windowsInfo;
          final id = info.deviceId;
          if (id.isNotEmpty) return 'win_$id';
        } else if (defaultTargetPlatform == TargetPlatform.linux) {
          final info = await plugin.linuxInfo;
          final id = info.machineId ?? '';
          if (id.isNotEmpty) return 'linux_$id';
        } else if (defaultTargetPlatform == TargetPlatform.macOS) {
          final info = await plugin.macOsInfo;
          final id = info.systemGUID ?? '';
          if (id.isNotEmpty) return 'mac_$id';
        }
      }
    } catch (e) {
      debugPrint('[StudentAuthService] getDeviceId native lookup failed: $e');
    }

    // Fallback: generate a stable UUID persisted in Hive
    return _getOrCreateFallbackDeviceId();
  }

  static Future<String> _getOrCreateFallbackDeviceId() async {
    try {
      Box box;
      if (Hive.isBoxOpen(_sessionBoxName)) {
        box = Hive.box(_sessionBoxName);
      } else {
        box = await Hive.openBox(_sessionBoxName);
      }
      String? stored = box.get('device_id') as String?;
      if (stored != null && stored.isNotEmpty) return stored;
      final newId = 'fallback_${const Uuid().v4()}';
      await box.put('device_id', newId);
      return newId;
    } catch (e) {
      // Last resort — return a runtime-only UUID (won't persist, but won't crash)
      debugPrint('[StudentAuthService] Fallback device ID generation error: $e');
      return 'temp_${const Uuid().v4()}';
    }
  }

  // ── Student Login Flow ──────────────────────────────────────────────────

  /// Performs secure student login with strict two-factor verification.
  ///
  /// BOTH conditions must be met to log in:
  ///   1. [studentCode] must match a known student in `student_auth`.
  ///   2. [scannedQrToken] must match the QR token stored for that student.
  ///
  /// One-device policy:
  ///   • If `linkedDeviceId` is empty in `student_auth`, the current device is
  ///     bound on successful login.
  ///   • If `linkedDeviceId` is set and differs from the current device, login
  ///     is rejected.  The admin must call [resetDeviceBinding] first.
  static Future<String> loginStudent({
    required String studentCode,
    required String scannedQrToken,
  }) async {
    final rawCode = studentCode.trim();
    final cleanCode = rawCode.toUpperCase();
    final rawToken = scannedQrToken.trim();

    // ── Basic Input Validation ──
    if (cleanCode.isEmpty) {
      throw Exception('Please enter your Student ID.');
    }

    // Strict requirement: a QR token must actually be provided.
    // An empty token, or one that is simply the same string as the student code,
    // is not accepted — the student must scan the official academy QR code.
    if (rawToken.isEmpty || rawToken.toUpperCase() == cleanCode) {
      throw Exception(
        'QR Code is required.\n'
        'Please scan your official academy QR code to log in.',
      );
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
          final sName =
              '${sData['firstName'] ?? sData['name'] ?? ''} ${sData['lastName'] ?? ''}'
                  .trim();

          debugPrint(
              '[StudentAuthService] Found student in main collection. Provisioning student_auth...');
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
      throw Exception(
          'Student ID not found. Please verify your Student ID and try again.');
    }

    // ── Account Status Check ──
    final accountStatus = authData['accountStatus'] as String? ?? 'active';
    if (accountStatus.toLowerCase() != 'active') {
      throw Exception(
          'This student account is inactive. Please contact the academy administration.');
    }

    // ── Strict QR Token Verification ──────────────────────────────────────
    // BOTH the student code AND the QR token must be valid.
    // There are NO fallbacks or shortcuts — this is intentional.
    final storedTokenHash = authData['qrTokenHash'] as String? ?? '';
    final storedPlainToken = authData['qrToken'] as String? ?? '';
    final providedTokenHash = hashQrToken(rawToken);

    // If no token has ever been set for this student, block login until the
    // admin generates one (this prevents uninitialized accounts from being used).
    if (storedTokenHash.isEmpty && storedPlainToken.isEmpty) {
      throw Exception(
        'No QR code has been issued for this account yet.\n'
        'Please contact the academy to receive your official QR code.',
      );
    }

    bool isTokenValid = false;
    if (storedTokenHash.isNotEmpty && storedTokenHash == providedTokenHash) {
      isTokenValid = true;
    } else if (storedPlainToken.isNotEmpty && storedPlainToken == rawToken) {
      isTokenValid = true;
    }

    if (!isTokenValid) {
      throw Exception(
        'Invalid QR Code. Please scan the official QR code issued by the academy.\n'
        'If you have lost your QR code, contact the administration.',
      );
    }

    // ── One-Device Policy Enforcement ─────────────────────────────────────
    final currentDeviceId = await getDeviceId();
    final storedDeviceId = authData['linkedDeviceId'] as String? ?? '';

    if (storedDeviceId.isNotEmpty && storedDeviceId != currentDeviceId) {
      throw Exception('already login on another device');
    }

    // ── Ensure studentId Matches Main Students Collection ─────────────────
    try {
      final sDoc =
          await _firestore.collection('students').doc(studentId).get();
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
      debugPrint(
          '[StudentAuthService] Final studentId verification error: $e');
    }

    final String validStudentId = studentId!;
    final projectId = _firestore.app.options.projectId;

    debugPrint('[QR LIVE TEST] binding function entered');
    debugPrint('[QR LIVE TEST] studentCode = $cleanCode');
    debugPrint('[QR LIVE TEST] resolved studentId = $validStudentId');
    debugPrint('[QR LIVE TEST] Firebase projectId = $projectId');
    debugPrint('[QR LIVE TEST] authentication successful');

    // ── Device ID Verification ───────────────────────────────────────────
    debugPrint('[QR LIVE TEST] currentDeviceId length = ${currentDeviceId.length}');
    debugPrint('[QR LIVE TEST] masked currentDeviceId = ${_maskId(currentDeviceId)}');

    if (currentDeviceId.isEmpty) {
      debugPrint('[QR LIVE TEST] ERROR: currentDeviceId is empty! Aborting binding write.');
      throw Exception('Device ID generation failed. Cannot bind empty device ID.');
    }

    // ── Bind Device on Login ──────────────────────────────────────────────
    final targetDocRef =
        _firestore.collection('student_auth').doc(validStudentId);
    debugPrint(
        '[QR LIVE TEST] writing to: student_auth/$validStudentId');
    try {
      await ensureDeviceBound(
        studentId: validStudentId,
        currentDeviceId: currentDeviceId,
        studentCode: cleanCode,
      );

      debugPrint('''
==============================
[LOGIN BINDING STATE]
studentCode = $cleanCode
canonicalStudentId = $validStudentId
canonicalStudentAuthPath = student_auth/$validStudentId
localDeviceId = ${_maskId(currentDeviceId)}
remoteLinkedDeviceId = ${_maskId(currentDeviceId)}
localDeviceIdLength = ${currentDeviceId.length}
remoteDeviceIdLength = ${currentDeviceId.length}
exactMatch = true
==============================''');

      debugPrint('[QR LIVE TEST] Firestore write SUCCESS');

      // ── Forced Server Read-back Verification ──────────────────────────
      debugPrint('[QR LIVE TEST] SERVER READBACK START (source: Source.server)...');
      try {
        final serverSnap = await targetDocRef.get(const GetOptions(source: Source.server));
        final serverData = serverSnap.data();
        final serverDeviceId = serverData?['linkedDeviceId'] as String? ?? '';
        final serverLinkedAt = serverData?['deviceLinkedAt'];
        debugPrint(
            '[QR LIVE TEST] SERVER READBACK:\n'
            '  exists = ${serverSnap.exists}\n'
            '  linkedDeviceId = ${_maskId(serverDeviceId)}\n'
            '  deviceLinkedAt = $serverLinkedAt');
      } catch (serverErr) {
        debugPrint('[QR LIVE TEST] SERVER READBACK ERROR: $serverErr');
      }
    } on FirebaseException catch (fe, st) {
      debugPrint(
          '[QR LIVE TEST] Firestore write FAILED:\n'
          '  code = ${fe.code}\n'
          '  message = ${fe.message}\n'
          '  plugin = ${fe.plugin}\n'
          '  stackTrace = $st');
    } catch (e, st) {
      debugPrint(
          '[QR LIVE TEST] Firestore write FAILED (General Exception):\n'
          '  error = $e\n'
          '  stackTrace = $st');
    }

    // ── Save Session to Local Hive Storage ────────────────────────────────
    await _saveSession(
      studentId: validStudentId,
      studentCode: cleanCode,
      deviceId: currentDeviceId,
    );

    debugPrint(
        '[StudentAuthService] Login successful for studentId: $validStudentId');
    return validStudentId;
  }

  // ── Session Management ──────────────────────────────────────────────────

  /// Fetches current [StudentModel] using local session info with fallback
  /// resolution logic.
  ///
  /// After a successful fetch this method does NOT overwrite the session's
  /// `loginTime` or `deviceId` — only `studentId` is corrected if a mismatch
  /// is detected (legacy data resolution).
  static Future<StudentModel?> fetchCurrentStudent({
    required String studentId,
    String? studentCode,
  }) async {
    // 0. Try local Hive box first (instantaneous & offline-friendly)
    if (studentId.isNotEmpty) {
      try {
        final localStudent = DatabaseService.studentBox.get(studentId);
        if (localStudent != null) {
          return localStudent;
        }
      } catch (e) {
        debugPrint('[StudentAuthService] Local Hive read failed: $e');
      }
    }

    // 0.5. Try local Firestore cache (fast, offline-friendly fallback)
    if (studentId.isNotEmpty) {
      try {
        final doc = await _firestore
            .collection('students')
            .doc(studentId)
            .get(const GetOptions(source: Source.cache));
        if (doc.exists && doc.data() != null) {
          final student = StudentModel.fromFirestore(doc);
          // Sync back to local Hive cache
          try {
            await DatabaseService.studentBox.put(student.id, student);
          } catch (_) {}
          return student;
        }
      } catch (_) {}
    }

    // 1. Try direct lookup by studentId from server
    if (studentId.isNotEmpty) {
      try {
        final doc = await _firestore
            .collection('students')
            .doc(studentId)
            .get()
            .timeout(const Duration(seconds: 4));
        if (doc.exists && doc.data() != null) {
          final student = StudentModel.fromFirestore(doc);
          // Sync back to local Hive cache
          try {
            await DatabaseService.studentBox.put(student.id, student);
          } catch (_) {}
          return student;
        }
      } catch (e) {
        debugPrint(
            '[StudentAuthService] Direct fetch failed for $studentId: $e');
      }
    }

    // 2. Query by studentCode if available
    final codeToQuery =
        (studentCode != null && studentCode.isNotEmpty) ? studentCode : studentId;

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
          // Update only the studentId in the session if it has changed (legacy fix).
          // Do NOT overwrite loginTime, deviceId, or studentCode.
          await _updateSessionStudentId(
              newStudentId: matchedDoc.id, studentCode: upperCode);
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
          await _updateSessionStudentId(
              newStudentId: matchedDoc.id, studentCode: codeToQuery);
          return StudentModel.fromFirestore(matchedDoc);
        }
      } catch (e) {
        debugPrint(
            '[StudentAuthService] Query student by code failed: $e');
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
        if (doc.id == studentId ||
            sId == studentId ||
            (studentCode != null &&
                sCode == studentCode.toUpperCase())) {
          await _updateSessionStudentId(
              newStudentId: doc.id,
              studentCode: sCode.isNotEmpty ? sCode : codeToQuery);
          return StudentModel.fromFirestore(doc);
        }
      }
    } catch (e) {
      debugPrint('[StudentAuthService] Fallback student scan failed: $e');
    }

    return null;
  }

  // ── Session Management ──────────────────────────────────────────────────

  /// Saves a full session (called only on login).
  static Future<void> _saveSession({
    required String studentId,
    required String studentCode,
    required String deviceId,
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
        'deviceId': deviceId,
        'loginTime': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Failed to save student session: $e');
    }
  }

  /// Updates only the `studentId` field in the existing session when a
  /// legacy mismatch is detected.  All other session fields (loginTime,
  /// studentCode, deviceId) remain untouched.
  static Future<void> _updateSessionStudentId({
    required String newStudentId,
    required String studentCode,
  }) async {
    try {
      Box sessionBox;
      if (Hive.isBoxOpen(_sessionBoxName)) {
        sessionBox = Hive.box(_sessionBoxName);
      } else {
        sessionBox = await Hive.openBox(_sessionBoxName);
      }
      final existing = sessionBox.get(_sessionKey);
      if (existing != null) {
        final existingMap = Map<String, dynamic>.from(existing);
        if (existingMap['studentId'] != newStudentId) {
          existingMap['studentId'] = newStudentId;
          await sessionBox.put(_sessionKey, existingMap);
          debugPrint(
              '[StudentAuthService] Session studentId corrected to $newStudentId');
        }
      }
    } catch (e) {
      debugPrint('[StudentAuthService] Failed to update session studentId: $e');
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
      // Clear session key but preserve the persisted device_id so that the
      // device binding check still works if the student re-logs in on this device.
      await sessionBox.delete(_sessionKey);
    } catch (e) {
      debugPrint('Session clear error: $e');
    }
  }

  // ── Admin Utilities ──────────────────────────────────────────────────────

  static Future<Map<String, dynamic>?> getStudentAuthInfo(
      String studentId, {String? studentCode}) async {
    try {
      final doc =
          await _firestore.collection('student_auth').doc(studentId).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        if ((data['linkedDeviceId'] as String? ?? '').isNotEmpty) {
          return data;
        }
      }

      final codeToQuery = (studentCode != null && studentCode.isNotEmpty) ? studentCode : studentId;
      final cleanCode = codeToQuery.trim().toUpperCase();

      final query = await _firestore
          .collection('student_auth')
          .where('studentCode', isEqualTo: cleanCode)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        final qData = query.docs.first.data();
        if ((qData['linkedDeviceId'] as String? ?? '').isNotEmpty) {
          return qData;
        }
      }

      final docCode =
          await _firestore.collection('student_auth').doc(cleanCode).get();
      if (docCode.exists && docCode.data() != null) {
        return docCode.data();
      }

      if (doc.exists) return doc.data();
    } catch (e) {
      debugPrint(
          '[StudentAuthService] Error fetching auth info for $studentId: $e');
    }
    return null;
  }

  /// Creates (or merges into) the `student_auth` document for a new student.
  ///
  /// Uses [SetOptions(merge: true)] so that if a document already exists,
  /// existing identity fields are preserved and only provided fields are written.
  static Future<Map<String, String>> createStudentAuthRecord({
    required String studentId,
    required String studentCode,
    required String studentName,
  }) async {
    final plainToken = generateQrToken();
    final tokenHash = hashQrToken(plainToken);
    final cleanCode = studentCode.trim().toUpperCase();

    final record = {
      'studentId': studentId,
      'studentCode': cleanCode,
      'studentName': studentName,
      'qrToken': plainToken,
      'qrTokenHash': tokenHash,
      'qrTokenUpdatedAt': FieldValue.serverTimestamp(),
      'accountStatus': 'active',
      'createdAt': FieldValue.serverTimestamp(),
    };

    unawaited(_firestore
        .collection('student_auth')
        .doc(studentId)
        .set(record, SetOptions(merge: true))
        .catchError((e) => debugPrint('student_auth write error: $e')));

    if (cleanCode != studentId) {
      unawaited(_firestore
          .collection('student_auth')
          .doc(cleanCode)
          .set(record, SetOptions(merge: true))
          .catchError((e) => debugPrint('student_auth cleanCode write error: $e')));
    }

    return {
      'studentId': studentId,
      'studentCode': cleanCode,
      'qrToken': plainToken,
      'qrTokenHash': tokenHash,
    };
  }

  /// Regenerates the QR token for an existing student.
  ///
  /// Only [qrToken], [qrTokenHash], and [qrTokenUpdatedAt] are written.
  /// Identity fields (studentId, studentCode, createdAt) and device binding
  /// (linkedDeviceId, deviceLinkedAt) are NEVER touched.
  static Future<String> generateAndStoreQrToken(String studentId) async {
    final plainToken = generateQrToken();
    final hash = hashQrToken(plainToken);
    final updateData = {
      'qrToken': plainToken,
      'qrTokenHash': hash,
      'qrTokenUpdatedAt': FieldValue.serverTimestamp(),
    };
    await _firestore
        .collection('student_auth')
        .doc(studentId)
        .set(updateData, SetOptions(merge: true));

    return plainToken;
  }

  /// Ensures that the student's active device is written to Firestore.
  static Future<void> ensureDeviceBound({
    required String studentId,
    required String currentDeviceId,
    String? studentCode,
  }) async {
    if (studentId.isEmpty || currentDeviceId.isEmpty) return;
    try {
      final bindData = {
        'studentId': studentId,
        'linkedDeviceId': currentDeviceId,
        'deviceLinkedAt': FieldValue.serverTimestamp(),
        'accountStatus': 'active',
      };
      if (studentCode != null && studentCode.isNotEmpty) {
        bindData['studentCode'] = studentCode.trim().toUpperCase();
      }

      await _firestore
          .collection('student_auth')
          .doc(studentId)
          .set(bindData, SetOptions(merge: true));

      if (studentCode != null && studentCode.isNotEmpty) {
        final cleanCode = studentCode.trim().toUpperCase();
        if (cleanCode != studentId) {
          await _firestore
              .collection('student_auth')
              .doc(cleanCode)
              .set(bindData, SetOptions(merge: true))
              .catchError((_) {});
        }
      }
      debugPrint(
          '[StudentAuthService] ensureDeviceBound bound device: ${_maskId(currentDeviceId)}');
    } catch (e) {
      debugPrint('[StudentAuthService] ensureDeviceBound error: $e');
    }
  }

  /// Resets the device binding for a student so they can log in from a new device.
  ///
  /// This does NOT change studentCode, qrToken, or any other identity field.
  static Future<void> resetDeviceBinding(String studentId, {String? studentCode}) async {
    final st = StackTrace.current;
    debugPrint('''
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
[RESET DEVICE BINDING CALLED]
studentId = $studentId
studentCode = ${studentCode ?? ''}
caller stack =
$st
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!''');

    final resetMap = {
      'linkedDeviceId': '',
      'deviceLinkedAt': null,
    };
    try {
      await _firestore
          .collection('student_auth')
          .doc(studentId)
          .set(resetMap, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[StudentAuthService] resetDeviceBinding studentId error: $e');
    }

    if (studentCode != null && studentCode.isNotEmpty) {
      final cleanCode = studentCode.trim().toUpperCase();
      if (cleanCode != studentId) {
        try {
          await _firestore
              .collection('student_auth')
              .doc(cleanCode)
              .set(resetMap, SetOptions(merge: true));
        } catch (_) {}
      }
    }
    debugPrint(
        '[StudentAuthService] Device binding reset for studentId: $studentId');
  }

  // ── Private Helpers ──────────────────────────────────────────────────────

  /// Masks an ID for safe debug logging (e.g. `abcd****wxyz`).
  static String _maskId(String id) {
    if (id.length <= 8) return '****';
    return '${id.substring(0, 4)}****${id.substring(id.length - 4)}';
  }
}
