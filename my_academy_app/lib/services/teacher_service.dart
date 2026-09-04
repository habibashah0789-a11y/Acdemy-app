import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import '../models/teacher_model.dart';
import '../models/student_model.dart';
import '../utils/image_utils.dart';

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
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;

    if (_cachedCurrentTeacher != null && _cachedCurrentTeacher!.id == uid) {
      return _cachedCurrentTeacher;
    }

    try {
      // 1. Try local cache first for instant loading (< 20ms)
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

      // 2. Fetch from server with 2s timeout
      final doc = await _firestore
          .collection('teachers')
          .doc(uid)
          .get()
          .timeout(const Duration(seconds: 2));
      if (doc.exists) {
        _cachedCurrentTeacher = TeacherModel.fromFirestore(doc);
        return _cachedCurrentTeacher;
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

  // ── ADMIN: Create teacher Firestore record (Firebase Auth created separately) ──
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
  }

  // ── ADMIN: Update teacher ──
  static Future<void> updateTeacher(TeacherModel teacher) async {
    await _firestore
        .collection('teachers')
        .doc(teacher.id)
        .update(teacher.toUpdateMap());
  }

  // ── ADMIN: Set teacher active/inactive ──
  static Future<void> setTeacherActive(String teacherId, bool isActive) async {
    await _firestore.collection('teachers').doc(teacherId).update({
      'isActive': isActive,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ── ADMIN: Delete teacher (removes Firestore doc + role doc) ──
  static Future<void> deleteTeacher(String teacherId) async {
    final batch = _firestore.batch();
    batch.delete(_firestore.collection('teachers').doc(teacherId));
    batch.delete(_firestore.collection('roles').doc(teacherId));
    await batch.commit();
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
        targetWidth: 512,
        targetHeight: 512,
      );
      final ref = _storage
          .ref()
          .child('teacher_profiles/${teacherId}_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await ref
          .putData(compressed,
              SettableMetadata(contentType: 'image/jpeg'))
          .timeout(const Duration(seconds: 15));
      return await ref.getDownloadURL().timeout(const Duration(seconds: 10));
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
    if (FirebaseAuth.instance.currentUser == null) return null;
    try {
      Uint8List bytesToUpload = fileBytes;
      String extension = 'bin';
      String contentType = 'application/octet-stream';

      if (mediaType == 'image') {
        extension = 'jpg';
        contentType = 'image/jpeg';
        // Compress announcement images to crisp 800x800 (~80KB-120KB instead of 10MB+) for 2-3s ultra-fast upload
        bytesToUpload = await ImageUtils.compressAndResizeImage(
          fileBytes,
          targetWidth: 800,
          targetHeight: 800,
        );
      } else if (mediaType == 'pdf') {
        extension = 'pdf';
        contentType = 'application/pdf';
      } else if (mediaType == 'audio') {
        extension = 'mp3';
        contentType = 'audio/mpeg';
        if (fileName.endsWith('.wav')) {
          extension = 'wav';
          contentType = 'audio/wav';
        } else if (fileName.endsWith('.m4a')) {
          extension = 'm4a';
          contentType = 'audio/mp4';
        }
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final path = 'announcements/announcement_${timestamp}_$fileName';
      final ref = _storage.ref().child(path);

      await ref
          .putData(
            bytesToUpload,
            SettableMetadata(contentType: contentType),
          )
          .timeout(const Duration(seconds: 20));

      return await ref.getDownloadURL().timeout(const Duration(seconds: 10));
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
    String mediaType = 'none', // 'none' | 'image' | 'pdf' | 'audio'
    String targetClass = 'All',
  }) async {
    final notifDocRef = _firestore.collection('notifications').doc();

    final data = {
      'id': notifDocRef.id,
      'title': title,
      'body': message,
      'message': message,
      'registeredBy': teacher.name,
      'senderId': teacher.id,
      'subject': teacher.subject,
      'targetSubject': teacher.subject,
      'targetSection': teacher.section,
      'class': targetClass == 'All' ? teacher.section : targetClass,
      'timestamp': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
      'type': 'announcement',
      'notificationType': 'teacher_announcement',
      'isRead': false,
      'mediaUrl': mediaUrl,
      'attachmentUrl': mediaUrl,
      'mediaType': mediaType,
      'attachmentType': mediaType,
    };

    await notifDocRef.set(data);
  }
}

