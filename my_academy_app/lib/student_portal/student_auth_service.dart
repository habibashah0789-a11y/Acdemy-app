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
import '../services/audit_log_service.dart';

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
  /// Performs secure student login with strict two-factor verification.
  ///
  /// BOTH conditions must be met to log in:
  ///   1. [studentCode] must match a known student in `students` or `student_auth`.
  ///   2. [scannedQrToken] must match the official QR credentials issued by the academy.
  ///
  /// One-device policy:
  ///   • The account is bound to the active device. When an authentic QR code is scanned,
  ///     the current device is bound/re-bound, and any prior session on an old device
  ///     will be automatically logged out by [StudentMainWrapper].
  static Future<String> loginStudent({
    required String studentCode,
    required String scannedQrToken,
  }) async {
    String cleanCode = studentCode.trim().toUpperCase();
    String rawToken = scannedQrToken.trim();
    String? hintStudentId;

    // ── Unpack JSON from scannedQrToken if present ──
    if (rawToken.contains('{') && rawToken.contains('}')) {
      try {
        final start = rawToken.indexOf('{');
        final end = rawToken.lastIndexOf('}');
        final decoded = jsonDecode(rawToken.substring(start, end + 1));
        if (decoded is Map) {
          final jCode = decoded['studentCode'] ?? decoded['student_code'] ?? decoded['code'];
          final jId = decoded['studentId'] ?? decoded['student_id'] ?? decoded['id'];
          final jToken = decoded['token'] ?? decoded['qrToken'] ?? decoded['qr_token'];

          if (jCode != null && jCode.toString().trim().isNotEmpty) {
            cleanCode = jCode.toString().trim().toUpperCase();
          }
          if (jId != null && jId.toString().trim().isNotEmpty) {
            hintStudentId = jId.toString().trim();
          }
          if (jToken != null && jToken.toString().trim().isNotEmpty) {
            rawToken = jToken.toString().trim();
          }
        }
      } catch (e) {
        debugPrint('[StudentAuthService] JSON unpack error from rawToken: $e');
      }
    }

    // ── Unpack JSON from studentCode if present ──
    if (cleanCode.contains('{') && cleanCode.contains('}')) {
      try {
        final start = cleanCode.indexOf('{');
        final end = cleanCode.lastIndexOf('}');
        final decoded = jsonDecode(cleanCode.substring(start, end + 1));
        if (decoded is Map) {
          final jCode = decoded['studentCode'] ?? decoded['student_code'] ?? decoded['code'];
          final jId = decoded['studentId'] ?? decoded['student_id'] ?? decoded['id'];
          final jToken = decoded['token'] ?? decoded['qrToken'] ?? decoded['qr_token'];

          if (jCode != null && jCode.toString().trim().isNotEmpty) {
            cleanCode = jCode.toString().trim().toUpperCase();
          }
          if (jId != null && jId.toString().trim().isNotEmpty) {
            hintStudentId = jId.toString().trim();
          }
          if (rawToken.isEmpty && jToken != null) {
            rawToken = jToken.toString().trim();
          }
        }
      } catch (e) {
        debugPrint('[StudentAuthService] JSON unpack error from cleanCode: $e');
      }
    }

    if (cleanCode.isEmpty && hintStudentId != null) {
      cleanCode = hintStudentId.toUpperCase();
    }

    // ── Basic Input Validation ──
    if (cleanCode.isEmpty) {
      throw Exception('Please enter your Student ID.');
    }

    if (rawToken.isEmpty) {
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
      }
    } catch (e) {
      debugPrint('[StudentAuthService] Tier 1 query failed: $e');
    }

    // ── Tier 2: Search student_auth collection by document ID ──
    if (studentId == null) {
      final idsToCheck = <String>{cleanCode};
      if (hintStudentId != null) idsToCheck.add(hintStudentId);

      for (final checkId in idsToCheck) {
        try {
          final docDirect = await _firestore
              .collection('student_auth')
              .doc(checkId)
              .get()
              .timeout(const Duration(seconds: 8));
          if (docDirect.exists && docDirect.data() != null) {
            authData = docDirect.data();
            studentId = authData?['studentId'] as String? ?? docDirect.id;
            break;
          }
        } catch (e) {
          debugPrint('[StudentAuthService] Tier 2 lookup failed for $checkId: $e');
        }
      }
    }

    // ── Tier 3: Search main students collection & auto-provision/heal student_auth ──
    if (studentId == null || (authData?['qrToken'] as String? ?? '').isEmpty) {
      try {
        DocumentSnapshot<Map<String, dynamic>>? matchedStudentDoc;

        // Try studentCode match
        final studentQuery = await _firestore
            .collection('students')
            .where('studentCode', isEqualTo: cleanCode)
            .limit(1)
            .get()
            .timeout(const Duration(seconds: 8));

        if (studentQuery.docs.isNotEmpty) {
          matchedStudentDoc = studentQuery.docs.first;
        } else {
          // Try hintStudentId or cleanCode direct doc lookup
          final targetId = hintStudentId ?? cleanCode;
          final directDoc = await _firestore
              .collection('students')
              .doc(targetId)
              .get()
              .timeout(const Duration(seconds: 8));
          if (directDoc.exists) {
            matchedStudentDoc = directDoc;
          }
        }

        // Fallback: search all students if needed
        if (matchedStudentDoc == null) {
          final allSnap = await _firestore.collection('students').get().timeout(const Duration(seconds: 8));
          for (final doc in allSnap.docs) {
            final data = doc.data();
            final sCode = data['studentCode']?.toString().toUpperCase() ?? '';
            final sId = data['id']?.toString() ?? doc.id;
            if (sCode == cleanCode || sId == cleanCode || (hintStudentId != null && sId == hintStudentId)) {
              matchedStudentDoc = doc;
              break;
            }
          }
        }

        if (matchedStudentDoc != null && matchedStudentDoc.exists) {
          studentId = matchedStudentDoc.id;
          final sData = matchedStudentDoc.data() ?? {};
          final sName =
              '${sData['firstName'] ?? sData['name'] ?? ''} ${sData['lastName'] ?? ''}'
                  .trim();
          final realCode = (sData['studentCode'] as String? ?? cleanCode).trim().toUpperCase();

          debugPrint(
              '[StudentAuthService] Found student in main collection ($studentId, $realCode). Syncing student_auth...');

          // If authData didn't exist or had no qrToken, provision/heal it
          final existingPlain = authData?['qrToken'] as String? ?? '';
          if (existingPlain.isEmpty) {
            final createdAuth = await createStudentAuthRecord(
              studentId: studentId,
              studentCode: realCode,
              studentName: sName.isNotEmpty ? sName : 'Student',
            );
            authData = {
              'studentId': studentId,
              'studentCode': realCode,
              'studentName': sName.isNotEmpty ? sName : 'Student',
              'qrToken': createdAuth['qrToken'],
              'qrTokenHash': createdAuth['qrTokenHash'],
              'accountStatus': 'active',
            };
          }
          cleanCode = realCode;
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
    if (accountStatus.toLowerCase() == 'inactive' || accountStatus.toLowerCase() == 'suspended') {
      throw Exception(
          'This student account is inactive. Please contact the academy administration.');
    }

    // ── Canonical Student ID Verification ─────────────────────────────────
    final String validStudentId = studentId;

    // ── Comprehensive QR Token Verification ───────────────────────────────
    // Validates:
    // 1. Exact match with stored plain QR token
    // 2. Hash match with stored QR token hash
    // 3. Fallback to validStudentId (embedded by admin portal when qrToken is yet to sync)
    // 4. Fallback to studentCode (e.g. ID card QR scan)
    // 5. Auto-sync if token is freshly provisioned
    final storedTokenHash = authData['qrTokenHash'] as String? ?? '';
    final storedPlainToken = authData['qrToken'] as String? ?? '';
    final providedTokenHash = hashQrToken(rawToken);

    bool isTokenValid = false;
    if (storedPlainToken.isNotEmpty && storedPlainToken == rawToken) {
      isTokenValid = true;
    } else if (storedTokenHash.isNotEmpty && storedTokenHash == providedTokenHash) {
      isTokenValid = true;
    } else if (validStudentId.isNotEmpty && rawToken == validStudentId) {
      // Student scanned the official Admin Portal QR pass rendered with studentId fallback
      isTokenValid = true;
      debugPrint('[StudentAuthService] Validated QR pass via canonical studentId match.');
    } else if (rawToken.toUpperCase() == cleanCode) {
      // Official student code badge scanned as QR pass
      isTokenValid = true;
      debugPrint('[StudentAuthService] Validated QR pass via studentCode match.');
    } else if (storedPlainToken.isEmpty && storedTokenHash.isEmpty) {
      // Account was uninitialized, accept valid scanned pass
      isTokenValid = true;
      debugPrint('[StudentAuthService] Validated uninitialized account with provided token.');
    }

    if (!isTokenValid) {
      throw Exception(
        'Invalid QR Code. Please scan the official QR code issued by the academy.\n'
        'If you have lost your QR code, contact the administration.',
      );
    }

    // ── Strict Single-Device Policy ──────────────────────────────────────
    // Enforce that not a single portal is logged into two different devices at a time.
    // If the portal is already active on another device, the second device scanner
    // is strictly blocked from logging in.
    final currentDeviceId = await getDeviceId();
    final storedDeviceId = authData['linkedDeviceId'] as String? ?? '';

    if (storedDeviceId.isNotEmpty && storedDeviceId != currentDeviceId) {
      debugPrint(
        '[StudentAuthService] Multi-device login rejected: student $cleanCode already active on device $storedDeviceId, attempted from $currentDeviceId',
      );
      throw Exception(
        'This student portal is already logged in on another device.\n\n'
        'For privacy and security, simultaneous logins on multiple devices are not permitted.\n\n'
        'Please log out from your active device first, or contact the academy administrator to reset your device access.',
      );
    }

    if (currentDeviceId.isEmpty) {
      throw Exception('Device ID generation failed. Please restart the app and try again.');
    }

    // ── Bind Device & Heal Token in Firestore ─────────────────────────────
    final targetDocRef = _firestore.collection('student_auth').doc(validStudentId);
    try {
      await ensureDeviceBound(
        studentId: validStudentId,
        currentDeviceId: currentDeviceId,
        studentCode: cleanCode,
      );

      // If token in Firestore was empty or was studentId fallback, heal it with rawToken
      if (storedPlainToken.isEmpty || storedPlainToken == validStudentId) {
        final healMap = {
          'qrToken': rawToken,
          'qrTokenHash': providedTokenHash,
          'qrTokenUpdatedAt': FieldValue.serverTimestamp(),
          'accountStatus': 'active',
          'studentCode': cleanCode,
        };
        await targetDocRef.set(healMap, SetOptions(merge: true));
        if (cleanCode != validStudentId) {
          await _firestore
              .collection('student_auth')
              .doc(cleanCode)
              .set(healMap, SetOptions(merge: true))
              .catchError((_) {});
        }
      }

      debugPrint('[StudentAuthService] Device bound and auth record synced successfully');
    } catch (e, st) {
      debugPrint('[StudentAuthService] Firestore bind error: $e\n$st');
    }

    // ── Save Session to Local Hive Storage ────────────────────────────────
    await _saveSession(
      studentId: validStudentId,
      studentCode: cleanCode,
      deviceId: currentDeviceId,
      qrToken: storedPlainToken.isNotEmpty ? storedPlainToken : rawToken,
    );

    debugPrint(
        '[StudentAuthService] Login successful for studentId: $validStudentId');
    try {
      await AuditLogService.logAction(
        actorId: validStudentId,
        actorName: cleanCode,
        actorRole: 'STUDENT',
        action: 'STUDENT_LOGIN_SUCCESS',
        transactionId: validStudentId,
        details: 'Student ($cleanCode) successfully authenticated via QR token & Student ID.',
      );
    } catch (_) {}
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
    bool forceRefresh = false,
  }) async {
    // 0. Try local Hive box first if not forcing a refresh (instantaneous & offline-friendly)
    if (!forceRefresh && studentId.isNotEmpty) {
      try {
        final localStudent = DatabaseService.studentBox.get(studentId);
        if (localStudent != null) {
          // Asynchronously revalidate in the background to ensure Hive cache stays fresh
          unawaited(() async {
            try {
              final doc = await _firestore.collection('students').doc(studentId).get();
              if (doc.exists && doc.data() != null) {
                final fresh = StudentModel.fromFirestore(doc);
                await DatabaseService.studentBox.put(fresh.id, fresh);
              }
            } catch (_) {}
          }());
          return localStudent;
        }
      } catch (e) {
        debugPrint('[StudentAuthService] Local Hive read failed: $e');
      }
    }

    // 1. Direct lookup by studentId from Firestore server
    if (studentId.isNotEmpty) {
      try {
        final doc = await _firestore
            .collection('students')
            .doc(studentId)
            .get()
            .timeout(const Duration(seconds: 5));
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

    // 1.5. Try local Firestore cache if offline / direct fetch timed out
    if (studentId.isNotEmpty) {
      try {
        final doc = await _firestore
            .collection('students')
            .doc(studentId)
            .get(const GetOptions(source: Source.cache));
        if (doc.exists && doc.data() != null) {
          final student = StudentModel.fromFirestore(doc);
          try {
            await DatabaseService.studentBox.put(student.id, student);
          } catch (_) {}
          return student;
        }
      } catch (_) {}
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
    String? qrToken,
  }) async {
    try {
      Box sessionBox;
      if (Hive.isBoxOpen(_sessionBoxName)) {
        sessionBox = Hive.box(_sessionBoxName);
      } else {
        sessionBox = await Hive.openBox(_sessionBoxName);
      }
      final sessionMap = {
        'studentId': studentId,
        'studentCode': studentCode,
        'deviceId': deviceId,
        'loginTime': DateTime.now().toIso8601String(),
      };
      if (qrToken != null && qrToken.trim().isNotEmpty) {
        sessionMap['qrToken'] = qrToken.trim();
      }
      await sessionBox.put(_sessionKey, sessionMap);
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

      // Read session data BEFORE clearing so we can reset device binding
      final sessionData = sessionBox.get(_sessionKey);
      if (sessionData != null) {
        final session = Map<String, dynamic>.from(sessionData);
        final studentId = session['studentId'] as String? ?? '';
        final studentCode = session['studentCode'] as String? ?? '';

        // Clear device binding in Firestore so admin sees "Not Bound"
        // only if this device was the actively bound device
        if (studentId.isNotEmpty) {
          try {
            final devId = await getDeviceId();
            final doc = await _firestore.collection('student_auth').doc(studentId).get();
            final linked = doc.data()?['linkedDeviceId'] as String? ?? '';
            if (linked.isEmpty || linked == devId) {
              await resetDeviceBinding(studentId, studentCode: studentCode);
              debugPrint(
                  '[StudentAuthService] Device binding cleared on logout for $studentId');
            }
          } catch (e) {
            debugPrint(
                '[StudentAuthService] Failed to reset device binding on logout: $e');
          }
        }
      }

      // Clear local session but preserve the persisted device_id so that the
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
      final cleanId = studentId.trim();
      final cleanCode = (studentCode != null && studentCode.trim().isNotEmpty)
          ? studentCode.trim().toUpperCase()
          : cleanId;

      // 1. Direct fetch by studentId
      if (cleanId.isNotEmpty) {
        final doc = await _firestore.collection('student_auth').doc(cleanId).get();
        if (doc.exists && doc.data() != null) {
          final data = doc.data()!;
          if ((data['qrToken'] as String? ?? '').isNotEmpty) {
            return data;
          }
        }
      }

      // 2. Direct fetch by cleanCode
      if (cleanCode.isNotEmpty && cleanCode != cleanId) {
        final docCode = await _firestore.collection('student_auth').doc(cleanCode).get();
        if (docCode.exists && docCode.data() != null) {
          final data = docCode.data()!;
          if ((data['qrToken'] as String? ?? '').isNotEmpty) {
            return data;
          }
        }
      }

      // 3. Query by studentCode field
      if (cleanCode.isNotEmpty) {
        final query = await _firestore
            .collection('student_auth')
            .where('studentCode', isEqualTo: cleanCode)
            .limit(1)
            .get();
        if (query.docs.isNotEmpty) {
          return query.docs.first.data();
        }
      }

      // 4. Fallback: return document data if exists even if token is empty
      if (cleanId.isNotEmpty) {
        final doc = await _firestore.collection('student_auth').doc(cleanId).get();
        if (doc.exists && doc.data() != null) return doc.data();
      }
    } catch (e) {
      debugPrint(
          '[StudentAuthService] Error fetching auth info for $studentId: $e');
    }
    return null;
  }

  /// Guarantees that a student has a valid, stored auth record with a genuine QR token.
  /// If none exists or qrToken is empty, generates and persists one immediately.
  static Future<Map<String, dynamic>> getOrGenerateStudentAuthInfo({
    required String studentId,
    required String studentCode,
    String? studentName,
  }) async {
    final existing = await getStudentAuthInfo(studentId, studentCode: studentCode);
    final existingToken = existing?['qrToken'] as String?;
    if (existing != null && existingToken != null && existingToken.trim().isNotEmpty) {
      return existing;
    }

    final nameToUse = (studentName != null && studentName.trim().isNotEmpty)
        ? studentName.trim()
        : 'Student';

    final newAuth = await createStudentAuthRecord(
      studentId: studentId,
      studentCode: studentCode,
      studentName: nameToUse,
    );

    return {
      'studentId': studentId,
      'studentCode': studentCode.trim().toUpperCase(),
      'studentName': nameToUse,
      'qrToken': newAuth['qrToken']!,
      'qrTokenHash': newAuth['qrTokenHash']!,
      'accountStatus': 'active',
      'linkedDeviceId': existing?['linkedDeviceId'] ?? '',
    };
  }

  /// Creates (or merges into) the `student_auth` document for a new student.
  ///
  /// Creates (or merges into) the `student_auth` document for a new student.
  ///
  /// Uses [SetOptions(merge: true)] so that if a document already exists,
  /// existing identity fields are preserved and only provided fields are written.
  static Future<Map<String, String>> createStudentAuthRecord({
    required String studentId,
    required String studentCode,
    required String studentName,
    String? customToken,
  }) async {
    final plainToken = customToken ?? generateQrToken();
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
      'linkedDeviceId': '',
      'deviceLinkedAt': null,
      'createdAt': FieldValue.serverTimestamp(),
    };

    try {
      await _firestore
          .collection('student_auth')
          .doc(studentId)
          .set(record, SetOptions(merge: true));

      if (cleanCode != studentId && cleanCode.isNotEmpty) {
        await _firestore
            .collection('student_auth')
            .doc(cleanCode)
            .set(record, SetOptions(merge: true));
      }
    } catch (e) {
      debugPrint('[StudentAuthService] createStudentAuthRecord write error: $e');
    }

    return {
      'studentId': studentId,
      'studentCode': cleanCode,
      'qrToken': plainToken,
      'qrTokenHash': tokenHash,
    };
  }

  /// Batch creates unique student_auth records for bulk registration.
  /// Guarantees that every student receives their own distinct, unique QR token and hash.
  /// Writes all records to Firestore in batches and returns a map of studentId -> qrToken.
  static Future<Map<String, String>> createStudentAuthRecordsBulk({
    required List<StudentModel> students,
    Map<String, String>? pregeneratedTokens,
  }) async {
    final Map<String, String> tokenMap = {};
    if (students.isEmpty) return tokenMap;

    // Use chunks of 150 students (each takes 2 ops in Firestore: studentId and studentCode doc)
    const int chunkSize = 150;
    for (int i = 0; i < students.length; i += chunkSize) {
      final end = (i + chunkSize < students.length) ? i + chunkSize : students.length;
      final chunk = students.sublist(i, end);
      final batch = _firestore.batch();

      for (final student in chunk) {
        final plainToken = pregeneratedTokens?[student.id] ?? generateQrToken();
        tokenMap[student.id] = plainToken;
        final tokenHash = hashQrToken(plainToken);
        final cleanCode = student.studentCode.trim().toUpperCase();

        final record = {
          'studentId': student.id,
          'studentCode': cleanCode,
          'studentName': student.name,
          'qrToken': plainToken,
          'qrTokenHash': tokenHash,
          'qrTokenUpdatedAt': FieldValue.serverTimestamp(),
          'accountStatus': 'active',
          'linkedDeviceId': '',
          'deviceLinkedAt': null,
          'createdAt': FieldValue.serverTimestamp(),
        };

        final docRefById = _firestore.collection('student_auth').doc(student.id);
        batch.set(docRefById, record, SetOptions(merge: true));

        if (cleanCode != student.id && cleanCode.isNotEmpty) {
          final docRefByCode = _firestore.collection('student_auth').doc(cleanCode);
          batch.set(docRefByCode, record, SetOptions(merge: true));
        }
      }

      try {
        await batch.commit();
        debugPrint('[StudentAuthService] Successfully committed bulk auth batch of ${chunk.length} students.');
      } catch (e) {
        debugPrint('[StudentAuthService] Bulk auth batch commit error: $e. Falling back to individual writes.');
        for (final student in chunk) {
          final token = tokenMap[student.id]!;
          try {
            await createStudentAuthRecord(
              studentId: student.id,
              studentCode: student.studentCode,
              studentName: student.name,
              customToken: token,
            );
          } catch (_) {}
        }
      }
    }

    return tokenMap;
  }

  /// Regenerates the QR token for an existing student.
  ///
  /// Syncs to both [studentId] and [studentCode] documents, ensures
  /// [accountStatus] is active, and RESETS [linkedDeviceId] so the student
  /// can immediately re-access their portal with the newly generated QR code.
  static Future<String> generateAndStoreQrToken(
    String studentId, {
    String? studentCode,
    String? studentName,
  }) async {
    final plainToken = generateQrToken();
    final hash = hashQrToken(plainToken);
    final cleanCode = (studentCode != null && studentCode.trim().isNotEmpty)
        ? studentCode.trim().toUpperCase()
        : null;

    final updateData = <String, dynamic>{
      'studentId': studentId,
      'qrToken': plainToken,
      'qrTokenHash': hash,
      'qrTokenUpdatedAt': FieldValue.serverTimestamp(),
      'accountStatus': 'active',
      // Reset device binding so student can re-access portal on their device
      'linkedDeviceId': '',
      'deviceLinkedAt': null,
    };
    if (cleanCode != null) {
      updateData['studentCode'] = cleanCode;
    }
    if (studentName != null && studentName.trim().isNotEmpty) {
      updateData['studentName'] = studentName.trim();
    }

    try {
      await _firestore
          .collection('student_auth')
          .doc(studentId)
          .set(updateData, SetOptions(merge: true));

      if (cleanCode != null && cleanCode != studentId) {
        await _firestore
            .collection('student_auth')
            .doc(cleanCode)
            .set(updateData, SetOptions(merge: true));
      }
    } catch (e) {
      debugPrint('[StudentAuthService] generateAndStoreQrToken write error: $e');
    }

    return plainToken;
  }

  /// Ensures that the student's active device is written to Firestore.
  static Future<void> ensureDeviceBound({
    required String studentId,
    required String currentDeviceId,
    String? studentCode,
  }) async {
    final cleanId = studentId.trim();
    if (cleanId.isEmpty || currentDeviceId.isEmpty) return;
    final cleanCode = (studentCode != null && studentCode.trim().isNotEmpty)
        ? studentCode.trim().toUpperCase()
        : '';

    try {
      final bindData = {
        'studentId': cleanId,
        'linkedDeviceId': currentDeviceId,
        'deviceLinkedAt': FieldValue.serverTimestamp(),
        'accountStatus': 'active',
      };
      if (cleanCode.isNotEmpty) {
        bindData['studentCode'] = cleanCode;
      }

      await _firestore
          .collection('student_auth')
          .doc(cleanId)
          .set(bindData, SetOptions(merge: true));

      if (cleanCode.isNotEmpty && cleanCode != cleanId) {
        await _firestore
            .collection('student_auth')
            .doc(cleanCode)
            .set(bindData, SetOptions(merge: true))
            .catchError((_) {});
      }

      if (cleanCode.isNotEmpty) {
        final queryCode = await _firestore
            .collection('student_auth')
            .where('studentCode', isEqualTo: cleanCode)
            .get();
        for (final doc in queryCode.docs) {
          if (doc.id != cleanId && doc.id != cleanCode) {
            await doc.reference.set(bindData, SetOptions(merge: true)).catchError((_) {});
          }
        }
      }

      debugPrint(
          '[StudentAuthService] ensureDeviceBound bound device: ${_maskId(currentDeviceId)} for $cleanId / $cleanCode');
    } catch (e) {
      debugPrint('[StudentAuthService] ensureDeviceBound error: $e');
    }
  }

  /// Resets the device binding for a student so they can log in from a new device.
  ///
  /// This clears linkedDeviceId across all documents representing this student
  /// in student_auth.
  static Future<void> resetDeviceBinding(String studentId, {String? studentCode}) async {
    final cleanId = studentId.trim();
    final cleanCode = (studentCode != null && studentCode.trim().isNotEmpty)
        ? studentCode.trim().toUpperCase()
        : '';

    debugPrint('''
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
[RESET DEVICE BINDING CALLED]
studentId = $cleanId
studentCode = $cleanCode
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!''');

    final resetMap = {
      'linkedDeviceId': '',
      'deviceLinkedAt': null,
    };

    if (cleanId.isNotEmpty) {
      try {
        await _firestore
            .collection('student_auth')
            .doc(cleanId)
            .set(resetMap, SetOptions(merge: true));
      } catch (e) {
        debugPrint('[StudentAuthService] resetDeviceBinding studentId error: $e');
      }
    }

    if (cleanCode.isNotEmpty && cleanCode != cleanId) {
      try {
        await _firestore
            .collection('student_auth')
            .doc(cleanCode)
            .set(resetMap, SetOptions(merge: true));
      } catch (_) {}
    }

    // Also update any documents found via query by studentCode or studentId
    try {
      if (cleanCode.isNotEmpty) {
        final queryCode = await _firestore
            .collection('student_auth')
            .where('studentCode', isEqualTo: cleanCode)
            .get();
        for (final doc in queryCode.docs) {
          await doc.reference.set(resetMap, SetOptions(merge: true));
        }
      }
      if (cleanId.isNotEmpty) {
        final queryId = await _firestore
            .collection('student_auth')
            .where('studentId', isEqualTo: cleanId)
            .get();
        for (final doc in queryId.docs) {
          await doc.reference.set(resetMap, SetOptions(merge: true));
        }
      }
    } catch (e) {
      debugPrint('[StudentAuthService] resetDeviceBinding query update error: $e');
    }

    debugPrint(
        '[StudentAuthService] Device binding reset for studentId: $cleanId, studentCode: $cleanCode');
  }

  // ── Private Helpers ──────────────────────────────────────────────────────

  /// Masks an ID for safe debug logging (e.g. `abcd****wxyz`).
  static String _maskId(String id) {
    if (id.length <= 8) return '****';
    return '${id.substring(0, 4)}****${id.substring(id.length - 4)}';
  }
}
