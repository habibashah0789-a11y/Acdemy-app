import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import '../models/teacher_model.dart';
import '../models/student_model.dart';
import '../services/notification_service.dart';
import '../services/supabase_service.dart';
import '../services/teacher_payout_service.dart';
import '../utils/image_utils.dart';
import '../services/audit_log_service.dart';

class TeacherStats {
  final int totalStudents;
  final int activeStudents;
  final double feesCollected;
  final double feesPending;
  final int newRegistrations; // last 30 days

  const TeacherStats({
    this.totalStudents = 0,
    this.activeStudents = 0,
    this.feesCollected = 0,
    this.feesPending = 0,
    this.newRegistrations = 0,
  });
}

class TeacherService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseStorage _storage = FirebaseStorage.instance;

  static TeacherModel? _cachedCurrentTeacher;

  // ── Get the currently authenticated teacher's Firestore document ──
  static Future<TeacherModel?> getCurrentTeacher() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    final uid = user.uid;
    final email = user.email?.trim().toLowerCase() ?? '';

    if (_cachedCurrentTeacher != null &&
        (_cachedCurrentTeacher!.id == uid ||
            _cachedCurrentTeacher!.email.toLowerCase() == email)) {
      return _cachedCurrentTeacher;
    }

    try {
      // 1. Try local cache by UID
      try {
        final cacheDoc = await _firestore
            .collection('teachers')
            .doc(uid)
            .get(const GetOptions(source: Source.cache));
        if (cacheDoc.exists && cacheDoc.data() != null) {
          _cachedCurrentTeacher = TeacherModel.fromFirestore(cacheDoc);
          _refreshCurrentTeacherInBackground(uid);
          return _cachedCurrentTeacher;
        }
      } catch (_) {}

      // 2. Fetch doc by UID from server
      try {
        final doc = await _firestore
            .collection('teachers')
            .doc(uid)
            .get()
            .timeout(const Duration(seconds: 3));
        if (doc.exists && doc.data() != null) {
          _cachedCurrentTeacher = TeacherModel.fromFirestore(doc);
          return _cachedCurrentTeacher;
        }
      } catch (e) {
        debugPrint('[TeacherService] doc(uid) fetch error: $e');
      }

      // 3. Fallback: Search teacher by email if doc(uid) wasn't found directly
      if (email.isNotEmpty) {
        final query = await _firestore
            .collection('teachers')
            .where('email', isEqualTo: user.email?.trim())
            .limit(1)
            .get()
            .timeout(const Duration(seconds: 4));

        if (query.docs.isNotEmpty) {
          final teacherDoc = query.docs.first;
          final teacher = TeacherModel.fromFirestore(teacherDoc);
          _cachedCurrentTeacher = teacher;

          // Self-heal: ensure doc(uid) and roles(uid) are linked properly
          try {
            await _firestore
                .collection('teachers')
                .doc(uid)
                .set(teacher.toMap(), SetOptions(merge: true));
            await _firestore
                .collection('roles')
                .doc(uid)
                .set({'role': 'teacher'}, SetOptions(merge: true));
          } catch (_) {}

          return _cachedCurrentTeacher;
        }
      }

      return null;
    } catch (e) {
      debugPrint('[TeacherService] getCurrentTeacher error: $e');
      return null;
    }
  }

  static void _refreshCurrentTeacherInBackground(String uid) {
    _firestore.collection('teachers').doc(uid).get().then((doc) {
      if (doc.exists) {
        _cachedCurrentTeacher = TeacherModel.fromFirestore(doc);
      }
    }).catchError((_) {});
  }

  // ── Stream of the current teacher doc (auto-refresh on Firestore changes) ──
  static Stream<TeacherModel?> getCurrentTeacherStream() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return Stream.value(null);
    return _firestore
        .collection('teachers')
        .doc(uid)
        .snapshots()
        .map((doc) => doc.exists ? TeacherModel.fromFirestore(doc) : null);
  }

  // ── Real-time stream of students belonging to this teacher ──
  static Stream<List<StudentModel>> getTeacherStudentsStream(
      TeacherModel teacher) {
    if (teacher.subject.isEmpty || teacher.section.isEmpty) {
      return Stream.value([]);
    }

    // Query students by classType (section) - Firestore can't do array-contains
    // on a comma-separated string, so we filter by classType and then do
    // client-side subject filtering.
    return _firestore
        .collection('students')
        .where('classType', isEqualTo: teacher.section)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
      final students = snapshot.docs
          .map((doc) => StudentModel.fromFirestore(doc))
          .where((s) => _studentBelongsToTeacher(s, teacher))
          .toList();

      // Sort: by class then name
      students.sort((a, b) {
        final classCompare = a.grade.compareTo(b.grade);
        if (classCompare != 0) return classCompare;
        return a.name.compareTo(b.name);
      });

      return students;
    });
  }

  // ── One-time fetch of teacher's students ──
  static Future<List<StudentModel>> getTeacherStudentsOnce(
      TeacherModel teacher) async {
    if (teacher.subject.isEmpty || teacher.section.isEmpty) return [];
    try {
      final snapshot = await _firestore
          .collection('students')
          .where('classType', isEqualTo: teacher.section)
          .where('isActive', isEqualTo: true)
          .get();

      final students = snapshot.docs
          .map((doc) => StudentModel.fromFirestore(doc))
          .where((s) => _studentBelongsToTeacher(s, teacher))
          .toList();

      students.sort((a, b) {
        final classCompare = a.grade.compareTo(b.grade);
        if (classCompare != 0) return classCompare;
        return a.name.compareTo(b.name);
      });

      return students;
    } catch (e) {
      debugPrint('[TeacherService] getTeacherStudentsOnce error: $e');
      return [];
    }
  }

  // ── Check if a student belongs to this teacher ──
  static bool _studentBelongsToTeacher(
      StudentModel student, TeacherModel teacher) {
    // Subject check: student.subject is comma-separated
    final studentSubjects = student.subject
        .split(',')
        .map((s) => s.trim().toLowerCase())
        .toList();
    final teacherSubject = teacher.subject.trim().toLowerCase();
    if (!studentSubjects.contains(teacherSubject)) return false;

    // Grade check: if teacher has specific assigned classes, filter by them
    if (teacher.assignedClasses.isNotEmpty) {
      final studentGrade = student.grade.trim().toLowerCase();
      final assignedLower =
          teacher.assignedClasses.map((c) => c.trim().toLowerCase()).toList();
      return assignedLower.contains(studentGrade);
    }

    return true;
  }

  // ── Compute subject-specific stats for dashboard ──
  static Future<TeacherStats> getSubjectStats(TeacherModel teacher) async {
    try {
      final students = await getTeacherStudentsOnce(teacher);
      final subject = teacher.subject;
      final now = DateTime.now();
      final thirtyDaysAgo = now.subtract(const Duration(days: 30));

      double feesCollected = 0;
      double feesPending = 0;
      int newRegistrations = 0;

      for (final s in students) {
        final paid = s.getSubjectPaid(subject);
        final total = s.getSubjectTotalFee(subject);
        final remaining = (total - paid).clamp(0.0, double.infinity);

        feesCollected += paid;
        feesPending += remaining;

        if (s.createdAt.isAfter(thirtyDaysAgo)) {
          newRegistrations++;
        }
      }

      return TeacherStats(
        totalStudents: students.length,
        activeStudents: students.where((s) => s.isActive).length,
        feesCollected: feesCollected,
        feesPending: feesPending,
        newRegistrations: newRegistrations,
      );
    } catch (e) {
      debugPrint('[TeacherService] getSubjectStats error: $e');
      return const TeacherStats();
    }
  }

  // ── Compute subject-specific stats stream for dashboard ──
  static Stream<TeacherStats> getSubjectStatsStream(TeacherModel teacher) {
    return getTeacherStudentsStream(teacher).map((students) {
      final subject = teacher.subject;
      final now = DateTime.now();
      final thirtyDaysAgo = now.subtract(const Duration(days: 30));

      double feesCollected = 0;
      double feesPending = 0;
      int newRegistrations = 0;

      for (final s in students) {
        final paid = s.getSubjectPaid(subject);
        final total = s.getSubjectTotalFee(subject);
        final remaining = (total - paid).clamp(0.0, double.infinity);

        feesCollected += paid;
        feesPending += remaining;

        if (s.createdAt.isAfter(thirtyDaysAgo)) {
          newRegistrations++;
        }
      }

      return TeacherStats(
        totalStudents: students.length,
        activeStudents: students.where((s) => s.isActive).length,
        feesCollected: feesCollected,
        feesPending: feesPending,
        newRegistrations: newRegistrations,
      );
    });
  }

  // ── Group students by their grade ──
  static Map<String, List<StudentModel>> groupStudentsByClass(
      List<StudentModel> students, TeacherModel teacher) {
    final Map<String, List<StudentModel>> grouped = {};

    // Preserve the order of assigned classes
    for (final cls in teacher.assignedClasses) {
      grouped[cls] = [];
    }

    for (final student in students) {
      final grade = student.grade;
      if (grouped.containsKey(grade)) {
        grouped[grade]!.add(student);
      } else {
        // If grade isn't in assigned classes exactly, try case-insensitive match
        bool found = false;
        for (final key in grouped.keys) {
          if (key.trim().toLowerCase() == grade.trim().toLowerCase()) {
            grouped[key]!.add(student);
            found = true;
            break;
          }
        }
        if (!found) {
          grouped[grade] = [student];
        }
      }
    }

    return grouped;
  }

  // ── ADMIN: Get all teachers as a real-time stream ──
  static Stream<List<TeacherModel>> getAllTeachersStream() {
    return _firestore
        .collection('teachers')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => TeacherModel.fromFirestore(d)).toList());
  }

  // ── ADMIN: Get all teachers once ──
  static Future<List<TeacherModel>> getAllTeachersOnce() async {
    try {
      final snap = await _firestore.collection('teachers').get();
      return snap.docs.map((d) => TeacherModel.fromFirestore(d)).toList();
    } catch (e) {
      debugPrint('[TeacherService] getAllTeachersOnce error: $e');
      return [];
    }
  }

  // ── ADMIN: Register Teacher with Firebase Auth & Firestore (Password set by Admin) ──
  static Future<String> registerTeacherWithAuth({
    required String email,
    required String password,
    required TeacherModel teacher,
  }) async {
    FirebaseApp? tempApp;
    try {
      final appName = 'TeacherAuthCreation_${DateTime.now().millisecondsSinceEpoch}';
      tempApp = await Firebase.initializeApp(
        name: appName,
        options: Firebase.app().options,
      );
      final tempAuth = FirebaseAuth.instanceFor(app: tempApp);
      final userCred = await tempAuth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final uid = userCred.user!.uid;

      // Create teacher record in Firestore with this Auth UID
      final finalTeacher = teacher.copyWith(id: uid);
      await createTeacherRecord(uid: uid, teacher: finalTeacher);

      return uid;
    } finally {
      if (tempApp != null) {
        try {
          await tempApp.delete();
        } catch (_) {}
      }
    }
  }

  // ── ADMIN: Create teacher Firestore record ──
  static Future<void> createTeacherRecord({
    required String uid,
    required TeacherModel teacher,
  }) async {
    final batch = _firestore.batch();

    // Write teacher document
    batch.set(
      _firestore.collection('teachers').doc(uid),
      teacher.toMap(),
    );

    // Write role document
    batch.set(
      _firestore.collection('roles').doc(uid),
      {
        'role': 'teacher',
        'createdAt': FieldValue.serverTimestamp(),
      },
    );

    await batch.commit();

    // Background Supabase Sync
    unawaited(() async {
      try {
        await SupabaseService.syncTeacherToSupabase(teacher.toSupabaseMap());
      } catch (e) {
        debugPrint('[SUPABASE SYNC] createTeacherRecord error: $e');
      }
    }());

    try {
      await AuditLogService.logAction(
        actorId: 'ADMIN',
        actorName: 'Administrator',
        actorRole: 'ADMIN',
        action: 'TEACHER_RECORD_CREATED',
        transactionId: uid,
        details: 'Created teacher profile for ${teacher.name} (${teacher.subject} - ${teacher.section}).',
      );
    } catch (_) {}
  }

  // ── ADMIN: Update teacher ──
  static Future<void> updateTeacher(TeacherModel teacher) async {
    await _firestore
        .collection('teachers')
        .doc(teacher.id)
        .update(teacher.toUpdateMap());

    // Background Supabase Sync
    unawaited(() async {
      try {
        await SupabaseService.syncTeacherToSupabase(teacher.toSupabaseMap());
      } catch (e) {
        debugPrint('[SUPABASE SYNC] updateTeacher error: $e');
      }
    }());

    try {
      await AuditLogService.logAction(
        actorId: 'ADMIN',
        actorName: 'Administrator',
        actorRole: 'ADMIN',
        action: 'TEACHER_RECORD_UPDATED',
        transactionId: teacher.id,
        details: 'Updated teacher profile for ${teacher.name} (${teacher.id}).',
      );
    } catch (_) {}
  }

  // ── ADMIN: Set teacher active/inactive ──
  static Future<void> setTeacherActive(String teacherId, bool isActive) async {
    await _firestore.collection('teachers').doc(teacherId).update({
      'isActive': isActive,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Background Supabase Sync
    unawaited(() async {
      try {
        if (SupabaseService.isConfigured) {
          await SupabaseService.client.from('teachers').update({'is_active': isActive, 'status': isActive ? 'active' : 'inactive'}).eq('id', teacherId);
        }
      } catch (_) {}
    }());

    try {
      await AuditLogService.logAction(
        actorId: 'ADMIN',
        actorName: 'Administrator',
        actorRole: 'ADMIN',
        action: isActive ? 'TEACHER_ACTIVATED' : 'TEACHER_DEACTIVATED',
        transactionId: teacherId,
        details: '${isActive ? "Activated" : "Deactivated"} teacher account ($teacherId).',
      );
    } catch (_) {}
  }

  // ── ADMIN: Delete teacher and all associated payouts, finance, notices, and devices ──
  static Future<void> deleteTeacher(String teacherId, {TeacherModel? teacher}) async {
    try {
      TeacherModel? targetTeacher = teacher;
      if (targetTeacher == null) {
        try {
          final doc = await _firestore.collection('teachers').doc(teacherId).get();
          if (doc.exists && doc.data() != null) {
            targetTeacher = TeacherModel.fromFirestore(doc);
          }
        } catch (_) {}
      }

      if (targetTeacher == null) {
        try {
          final q = await _firestore
              .collection('teachers')
              .where('teacherId', isEqualTo: teacherId)
              .limit(1)
              .get();
          if (q.docs.isNotEmpty) {
            targetTeacher = TeacherModel.fromFirestore(q.docs.first);
          }
        } catch (_) {}
      }

      final docId = targetTeacher?.id.trim() ?? teacherId.trim();
      final customId = targetTeacher?.teacherId.trim() ?? '';
      final email = targetTeacher?.email.trim().toLowerCase() ?? '';
      final name = targetTeacher?.name.trim() ?? '';
      final subject = targetTeacher?.subject.trim() ?? '';
      final section = targetTeacher?.section.trim() ?? '';
      final picUrl = targetTeacher?.profilePicUrl ?? '';

      // 1. Delete all teacher payouts & payout notifications for this specific teacher
      final deletedPayoutsCount = await TeacherPayoutService.deletePayoutsForTeacher(
        teacherDocId: docId,
        customTeacherId: customId,
        teacherEmail: email,
        teacherName: name,
        teacherSubject: subject,
        teacherSection: section,
      );

      // 2. Delete all notifications & announcements authored by or targeted to this teacher
      try {
        final notifSnap = await _firestore.collection('notifications').get();
        final notifBatch = _firestore.batch();
        int notifCount = 0;

        for (final doc in notifSnap.docs) {
          final data = doc.data();
          final sId = (data['senderId'] ?? '').toString().trim();
          final tId = (data['teacherId'] ?? '').toString().trim();
          final notifType = (data['notificationType'] ?? data['type'] ?? '').toString();
          final tName = (data['teacherName'] ?? '').toString().trim().toLowerCase();
          final tSub = (data['teacherSubject'] ?? data['subject'] ?? '').toString().trim().toLowerCase();

          bool shouldDelete = false;

          // Match by IDs/email
          if (docId.isNotEmpty && (sId == docId || tId == docId)) shouldDelete = true;
          if (customId.isNotEmpty && (sId == customId || tId == customId)) shouldDelete = true;
          if (email.isNotEmpty && (sId.toLowerCase() == email || tId.toLowerCase() == email)) shouldDelete = true;

          // Match by teacher announcement metadata
          if (!shouldDelete && notifType == 'teacher_announcement') {
            if (name.isNotEmpty && subject.isNotEmpty) {
              if (tName == name.toLowerCase() && tSub == subject.toLowerCase()) {
                shouldDelete = true;
              }
            }
          }

          if (shouldDelete) {
            notifBatch.delete(doc.reference);
            notifCount++;
          }
        }

        if (notifCount > 0) {
          await notifBatch.commit();
        }
      } catch (e) {
        debugPrint('[TeacherService] Error deleting teacher notifications: $e');
      }

      // Also clean announcements and notices collections
      try {
        for (final col in ['announcements', 'notices']) {
          final snap = await _firestore.collection(col).get();
          final b = _firestore.batch();
          int c = 0;
          for (final doc in snap.docs) {
            final data = doc.data();
            final sId = (data['senderId'] ?? '').toString().trim();
            final tId = (data['teacherId'] ?? '').toString().trim();
            if ((docId.isNotEmpty && (sId == docId || tId == docId)) ||
                (customId.isNotEmpty && (sId == customId || tId == customId)) ||
                (email.isNotEmpty && (sId.toLowerCase() == email || tId.toLowerCase() == email))) {
              b.delete(doc.reference);
              c++;
            }
          }
          if (c > 0) await b.commit();
        }
      } catch (_) {}

      // 3. Delete registered FCM devices for this teacher
      try {
        final devicesSnap = await _firestore.collection('devices').get();
        final devBatch = _firestore.batch();
        int devCount = 0;
        for (final doc in devicesSnap.docs) {
          final uId = (doc.data()['userId'] ?? '').toString().trim();
          if ((docId.isNotEmpty && uId == docId) ||
              (customId.isNotEmpty && uId == customId) ||
              (email.isNotEmpty && uId.toLowerCase() == email)) {
            devBatch.delete(doc.reference);
            devCount++;
          }
        }
        if (devCount > 0) {
          await devBatch.commit();
        }
      } catch (e) {
        debugPrint('[TeacherService] Error deleting teacher devices: $e');
      }

      // 4. Delete Firestore Teacher Doc & Role Doc
      final mainBatch = _firestore.batch();
      if (docId.isNotEmpty) {
        mainBatch.delete(_firestore.collection('teachers').doc(docId));
        mainBatch.delete(_firestore.collection('roles').doc(docId));
      }
      if (customId.isNotEmpty && customId != docId) {
        mainBatch.delete(_firestore.collection('teachers').doc(customId));
        mainBatch.delete(_firestore.collection('roles').doc(customId));
      }
      await mainBatch.commit();

      // 5. Delete profile picture from Storage if present
      if (picUrl.isNotEmpty && picUrl.contains('firebase')) {
        try {
          await _storage.refFromURL(picUrl).delete();
        } catch (_) {}
      }

      // 6. Clear in-memory cache
      if (_cachedCurrentTeacher != null) {
        if (_cachedCurrentTeacher!.id == docId ||
            (customId.isNotEmpty && _cachedCurrentTeacher!.teacherId == customId) ||
            (email.isNotEmpty && _cachedCurrentTeacher!.email.toLowerCase() == email)) {
          _cachedCurrentTeacher = null;
        }
      }

      // 7. Audit log
      try {
        await AuditLogService.logAction(
          actorId: 'ADMIN',
          actorName: 'Administrator',
          actorRole: 'ADMIN',
          action: 'TEACHER_RECORD_DELETED',
          transactionId: docId,
          details: 'Deleted teacher ${name.isNotEmpty ? name : docId}'
              '${subject.isNotEmpty ? " ($subject - $section)" : ""}. '
              'Purged $deletedPayoutsCount payout/finance records and all associated notices and devices.',
        );
      } catch (_) {}
    } catch (e) {
      debugPrint('[TeacherService] deleteTeacher error: $e');
      rethrow;
    }
  }

  // ── ADMIN: Generate next available teacher ID ──
  static Future<String> generateTeacherId({
    required String section,
    required String subject,
  }) async {
    try {
      final sectionCode =
          section.length >= 3 ? section.substring(0, 3).toUpperCase() : section.toUpperCase();
      final subjectCode =
          subject.length >= 3 ? subject.substring(0, 3).toUpperCase() : subject.toUpperCase();
      final prefix = 'T-$subjectCode-$sectionCode-';

      final existing = await getAllTeachersOnce();
      int maxSeq = 0;
      for (final t in existing) {
        if (t.teacherId.startsWith(prefix)) {
          final seqStr = t.teacherId.substring(prefix.length);
          final seq = int.tryParse(seqStr) ?? 0;
          if (seq > maxSeq) maxSeq = seq;
        }
      }
      return '$prefix${(maxSeq + 1).toString().padLeft(3, '0')}';
    } catch (e) {
      return 'T-001';
    }
  }

  // ── Upload teacher profile image ──
  static Future<String?> uploadTeacherProfileImage(
      Uint8List imageBytes, String teacherId) async {
    if (FirebaseAuth.instance.currentUser == null) return null;
    try {
      final compressed = await ImageUtils.compressAndResizeImage(
        imageBytes,
        targetWidth: 360,
        targetHeight: 360,
        quality: 75,
      );
      final ref = _storage
          .ref()
          .child('teacher_profiles/${teacherId}_${DateTime.now().millisecondsSinceEpoch}.png');
      await ref
          .putData(compressed, SettableMetadata(contentType: 'image/png'))
          .timeout(const Duration(seconds: 8));
      return await ref.getDownloadURL().timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint('[TeacherService] uploadTeacherProfileImage error: $e');
      return null;
    }
  }

  // ── Upload Announcement Media (Picture, PDF, Voice Note) ──
  static Future<String?> uploadAnnouncementAttachment({
    required Uint8List fileBytes,
    required String fileName,
    required String mediaType, // 'image' | 'pdf' | 'audio'
  }) async {
    try {
      Uint8List bytesToUpload = fileBytes;
      String contentType = 'application/octet-stream';

      if (mediaType == 'image') {
        contentType = 'image/jpeg';
        // Compress announcement images to crisp 480x480 (~20KB-35KB) for sub-second (<0.3s) ultra-fast upload
        try {
          bytesToUpload = await ImageUtils.compressAndResizeImage(
            fileBytes,
            targetWidth: 480,
            targetHeight: 480,
            quality: 75,
          );
        } catch (_) {}
      } else if (mediaType == 'pdf') {
        contentType = 'application/pdf';
      } else if (mediaType == 'audio') {
        contentType = 'audio/mpeg';
        if (fileName.endsWith('.wav')) {
          contentType = 'audio/wav';
        } else if (fileName.endsWith('.m4a')) {
          contentType = 'audio/mp4';
        }
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final path = 'announcements/announcement_${timestamp}_$fileName';

      // 1. Try Firebase Storage (Lightning sub-second upload for ~25KB payload)
      try {
        final ref = _storage.ref().child(path);
        await ref.putData(
          bytesToUpload,
          SettableMetadata(contentType: contentType),
        );

        final downloadUrl = await ref.getDownloadURL();
        if (downloadUrl.isNotEmpty) return downloadUrl;
      } catch (e) {
        debugPrint('[TeacherService] Firebase Storage upload note: $e');
      }

      // 2. Fallback to Supabase Storage if available
      try {
        final supabaseUrl = await SupabaseService.uploadAnnouncementAttachment(
          fileBytes: bytesToUpload,
          fileName: fileName,
        );
        if (supabaseUrl != null && supabaseUrl.isNotEmpty) return supabaseUrl;
      } catch (e) {
        debugPrint('[TeacherService] Supabase Storage fallback note: $e');
      }

      return null;
    } catch (e) {
      debugPrint('[TeacherService] uploadAnnouncementAttachment error: $e');
      return null;
    }
  }

  // ── Create and Publish Teacher Announcement ──
  static Future<void> createTeacherAnnouncement({
    required TeacherModel teacher,
    required String title,
    required String message,
    String mediaUrl = '',
    String mediaType = 'none', // 'none' | 'image'
    String targetClass = 'All',
    String targetHour = 'All',
  }) async {
    final notifDocRef = _firestore.collection('notifications').doc();

    final formattedTeacherName = teacher.name.trim();
    final formattedTeacherSubject = teacher.subject.trim();
    final displayClass = (targetClass.isNotEmpty && targetClass != 'All')
        ? targetClass
        : (teacher.section.isNotEmpty && teacher.section != 'All'
            ? teacher.section
            : 'All Classes');

    final hasSpecificHour = targetHour.isNotEmpty &&
        targetHour != 'All' &&
        targetHour != 'All Hours';
    final displayClassInfo = hasSpecificHour
        ? '$displayClass • $targetHour Batch'
        : displayClass;

    final authorLabel = formattedTeacherSubject.isNotEmpty
        ? '$formattedTeacherName ($formattedTeacherSubject Teacher • $displayClassInfo)'
        : '$formattedTeacherName (Teacher • $displayClassInfo)';

    final data = {
      'id': notifDocRef.id,
      'title': title,
      'body': message,
      'message': message,
      'registeredBy': authorLabel,
      'teacherName': formattedTeacherName,
      'teacherSubject': formattedTeacherSubject,
      'teacherSection': teacher.section,
      'teacherId': teacher.id,
      'teacherCode': teacher.teacherId,
      'senderId': teacher.id,
      'subject': formattedTeacherSubject,
      'targetSubject': formattedTeacherSubject,
      'targetSection': teacher.section,
      'class': displayClass,
      'className': displayClass,
      'targetClass': displayClass,
      'targetHour': targetHour,
      'targetTime': targetHour,
      'scheduleSlot': targetHour,
      'targetSchedule': targetHour,
      'timestamp': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
      'type': 'teacher_announcement',
      'notificationType': 'teacher_announcement',
      'isRead': false,
      'mediaUrl': mediaUrl,
      'attachmentUrl': mediaUrl,
      'mediaType': mediaType,
      'attachmentType': mediaType,
    };

    // Save directly to notifications, announcements, notices, and teacher_announcements collections
    await _firestore.collection('notifications').doc(notifDocRef.id).set(data);
    try {
      await _firestore.collection('announcements').doc(notifDocRef.id).set(data);
    } catch (_) {}
    try {
      await _firestore.collection('notices').doc(notifDocRef.id).set(data);
    } catch (_) {}
    try {
      await _firestore.collection('teacher_announcements').doc(notifDocRef.id).set(data);
    } catch (_) {}

    // Trigger push notification to student devices mapped to this teacher's class, subject, and hour
    try {
      final safeClass = displayClass
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9]'), '_');
      final safeSubject = formattedTeacherSubject
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9]'), '_');

      String topic = 'class_${safeClass}_subject_$safeSubject';
      if (hasSpecificHour) {
        final safeHour = targetHour.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');
        topic = 'class_${safeClass}_subject_${safeSubject}_hour_$safeHour';
      }

      await NotificationService.triggerPushNotification(
        targetTopic: topic,
        title: '📢 $authorLabel',
        body: '$title\n$message',
        payload: {
          'type': 'teacher_announcement',
          'screen': 'notifications',
          'teacherName': formattedTeacherName,
          'teacherSubject': formattedTeacherSubject,
          'subject': formattedTeacherSubject,
          'targetClass': displayClass,
          'targetHour': targetHour,
        },
      );
    } catch (e) {
      debugPrint('[TeacherService] push trigger error: $e');
    }
  }
}

