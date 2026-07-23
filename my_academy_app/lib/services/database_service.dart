import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:hive/hive.dart';
import '../models/student_model.dart';
import '../models/recycled_student.dart';

class DatabaseService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseStorage _storage = FirebaseStorage.instance;
  static late Box<StudentModel> _studentBox;
  static Box<StudentModel> get studentBox => _studentBox;
  static late Box<RecycledStudent> _recycledStudentBox;
  static Box<RecycledStudent> get recycledStudentBox => _recycledStudentBox;
  static late Box _settingsBox;

  static Future<void> init() async {
    _studentBox = await Hive.openBox<StudentModel>('students');
    _recycledStudentBox = await Hive.openBox<RecycledStudent>('recycled_students');
    _settingsBox = await Hive.openBox('settings');
  }

  // ── Student CRUD (Local + Cloud) ──
  static List<StudentModel> getAllStudentsLocal() => _studentBox.values.toList();

  static Future<bool> addStudent(StudentModel student) async {
    await _studentBox.put(student.id, student);
    if (FirebaseAuth.instance.currentUser != null) {
      try {
        await _firestore
            .collection('students')
            .doc(student.id)
            .set(student.toMap())
            .timeout(const Duration(seconds: 4));
      } catch (e) {
        debugPrint('Firestore add student failed: $e');
      }
    }
    return true;
  }

  static Future<bool> updateStudent(StudentModel student) async {
    await _studentBox.put(student.id, student);
    if (FirebaseAuth.instance.currentUser != null) {
      try {
        await _firestore
            .collection('students')
            .doc(student.id)
            .update(student.toMap())
            .timeout(const Duration(seconds: 4));
      } catch (e) {
        debugPrint('Firestore update student failed: $e');
      }
    }
    return true;
  }

  static Future<bool> deleteStudent(String id) async {
    await _studentBox.delete(id);
    if (FirebaseAuth.instance.currentUser != null) {
      try {
        await _firestore
            .collection('students')
            .doc(id)
            .delete()
            .timeout(const Duration(seconds: 4));
      } catch (e) {
        debugPrint('Firestore delete student failed: $e');
      }
    }
    return true;
  }

  // ── REAL-TIME STREAM for StudentListScreen (FIRESTORE ONLY WHEN AUTHENTICATED) ──
  static Stream<QuerySnapshot> getStudentsStream() {
    if (FirebaseAuth.instance.currentUser == null) {
      return const Stream.empty();
    }
    return _firestore
        .collection('students')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // ── Get all students from Firestore (one-time fetch) ──
  static Future<List<StudentModel>> getAllStudentsFromFirestore() async {
    if (FirebaseAuth.instance.currentUser == null) {
      return getAllStudentsLocal();
    }
    try {
      final snapshot = await _firestore.collection('students').get();
      return snapshot.docs
          .map((doc) => StudentModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      return getAllStudentsLocal();
    }
  }

  static Future<StudentModel?> getStudentById(String studentId) async {
    if (FirebaseAuth.instance.currentUser != null) {
      try {
        final doc = await _firestore.collection('students').doc(studentId).get();
        if (doc.exists) {
          return StudentModel.fromFirestore(doc);
        }
      } catch (e) {
        debugPrint('Error getting student from Firestore: $e');
      }
    }
    // Fallback to local Hive
    return _studentBox.get(studentId);
  }

  // ── Image Upload (works on Web + Mobile + Windows) ──
  static Future<String?> uploadImage(Uint8List imageBytes, String folder) async {
    if (FirebaseAuth.instance.currentUser == null) return null;
    try {
      String fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      Reference ref = _storage.ref().child('$folder/$fileName');
      await ref.putData(imageBytes, SettableMetadata(contentType: 'image/jpeg'))
          .timeout(const Duration(seconds: 5));
      return await ref.getDownloadURL().timeout(const Duration(seconds: 5));
    } catch (e) { return null; }
  }

  // ── Image Delete ──
  static Future<void> deleteImage(String imageUrl) async {
    if (FirebaseAuth.instance.currentUser == null) return;
    try { await _storage.refFromURL(imageUrl).delete(); } catch (e) {
      // Ignore if image does not exist or deletion fails.
    }
  }

  // ── Sync ──
  static Future<void> syncFromFirestore() async {
    if (FirebaseAuth.instance.currentUser == null) return;
    try {
      var s = await _firestore.collection('students').get();
      await _studentBox.clear();
      for (var doc in s.docs) {
        await _studentBox.put(doc.id, StudentModel.fromFirestore(doc));
      }
    } catch (e) {
      debugPrint('Sync from Firestore failed: $e');
    }
  }

  static Future<void> syncToFirestore() async {
    if (FirebaseAuth.instance.currentUser == null) return;
    try {
      for (var s in _studentBox.values) {
        await _firestore.collection('students').doc(s.id).set(s.toMap());
      }
    } catch (e) {
      debugPrint('Sync to Firestore failed: $e');
    }
  }

  // ── Student Filtering (for Teacher Folder hierarchy) ──
  static List<StudentModel> getStudentsByClass({
    required String classType,
    required String subject,
    required String grade,
  }) {
    return _studentBox.values.where((s) =>
      s.classType == classType &&
      s.subject == subject &&
      s.grade == grade
    ).toList();
  }

  // ── Dashboard Stats ──
  static int get totalStudents => _studentBox.length;
  static double get totalFeesCollected {
    double t = 0;
    for (var s in _studentBox.values) { t += s.feeSubmitted; }
    return t;
  }
  static double get totalPendingFees {
    double t = 0;
    for (var s in _studentBox.values) { t += s.feeRemaining; }
    return t;
  }

  // ── Academy Profile ──
  static Map<String, dynamic> getAcademyProfile() {
    final profile = _settingsBox.get('academy_profile');
    if (profile != null) {
      return Map<String, dynamic>.from(profile);
    }
    return {
      'name': '',
      'address': '',
      'phone': '',
    };
  }

  static Future<void> saveAcademyProfile(Map<String, dynamic> profile) async {
    await _settingsBox.put('academy_profile', profile);
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      try {
        await _firestore.collection('academy_profile').doc(uid).set(profile).timeout(const Duration(seconds: 4));
      } catch (e) {
        debugPrint('Firestore academy profile sync timed out/failed: $e');
      }
    }
  }

  // ── Backup & Restore ──
  static String exportBackup() {
    final students = _studentBox.values.map((s) => s.toMap()).toList();
    final profile = getAcademyProfile();

    final data = {
      'students': students,
      'academy_profile': profile,
      'backup_time': DateTime.now().toIso8601String(),
    };

    return jsonEncode(data);
  }

  static Future<bool> importBackup(String jsonStr) async {
    try {
      final data = jsonDecode(jsonStr) as Map<String, dynamic>;
      if (!data.containsKey('students')) {
        return false;
      }

      await _studentBox.clear();

      final studentsList = data['students'] as List;
      for (var sMap in studentsList) {
        final s = StudentModel.fromMap(Map<String, dynamic>.from(sMap), sMap['id']);
        await _studentBox.put(s.id, s);
      }

      if (data.containsKey('academy_profile')) {
        await saveAcademyProfile(Map<String, dynamic>.from(data['academy_profile']));
      }

      // Async sync to Firestore
      if (FirebaseAuth.instance.currentUser != null) {
        syncToFirestore();
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  // ── Recycle Bin ──
  static Future<bool> restoreStudent(RecycledStudent recycled) async {
    await _studentBox.put(recycled.id, recycled);
    await _recycledStudentBox.delete(recycled.id);

    if (FirebaseAuth.instance.currentUser != null) {
      try {
        await _firestore.collection('students').doc(recycled.id).set(recycled.toMap());
        await _firestore.collection('recycled_students').doc(recycled.id).delete();
      } catch (e) {
        debugPrint('Restore student cloud sync failed: $e');
      }
    }
    return true;
  }

  static Future<void> emptyRecycleBin() async {
    await _recycledStudentBox.clear();
    if (FirebaseAuth.instance.currentUser != null) {
      try {
        final querySnapshot = await _firestore.collection('recycled_students').get();
        for (var doc in querySnapshot.docs) {
          await doc.reference.delete();
        }
      } catch (e) {
        debugPrint('Error emptying recycle bin in cloud: $e');
      }
    }
  }

  static Stream<QuerySnapshot> getRecycledStudentsStream() {
    if (FirebaseAuth.instance.currentUser == null) {
      return const Stream.empty();
    }
    return _firestore.collection('recycled_students').snapshots();
  }

  static List<RecycledStudent> getRecycledStudents() {
    return _recycledStudentBox.values.toList();
  }

  static Future<bool> recycleStudent(StudentModel student) async {
    final recycled = RecycledStudent(
      id: student.id,
      firstName: student.firstName,
      lastName: student.lastName,
      fatherName: student.fatherName,
      phone: student.phone,
      email: student.email,
      schedule: student.schedule,
      feeSubmitted: student.feeSubmitted,
      feeRemaining: student.feeRemaining,
      biologyFee: student.biologyFee,
      physicsFee: student.physicsFee,
      chemistryFee: student.chemistryFee,
      englishFee: student.englishFee,
      profilePicUrl: student.profilePicUrl,
      enrollmentStatus: student.enrollmentStatus,
      classType: student.classType,
      grade: student.grade,
      subject: student.subject,
      mathFee: student.mathFee,
      createdAt: student.createdAt,
      updatedAt: student.updatedAt,
      isActive: student.isActive,
      deletedAt: DateTime.now(),
    );

    await _recycledStudentBox.put(recycled.id, recycled);
    await _studentBox.delete(student.id);

    if (FirebaseAuth.instance.currentUser != null) {
      try {
        await _firestore.collection('recycled_students').doc(recycled.id).set(recycled.toRecycleMap());
        await _firestore.collection('students').doc(student.id).delete();
      } catch (e) {
        debugPrint('Recycle student cloud sync failed: $e');
      }
    }
    return true;
  }

  static Future<bool> deleteRecycledStudent(String id) async {
    await _recycledStudentBox.delete(id);
    if (FirebaseAuth.instance.currentUser != null) {
      try {
        await _firestore.collection('recycled_students').doc(id).delete().timeout(const Duration(seconds: 4));
      } catch (e) {
        debugPrint('Delete recycled student cloud sync failed: $e');
      }
    }
    return true;
  }
}