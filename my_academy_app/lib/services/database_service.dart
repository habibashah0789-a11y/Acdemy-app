import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:hive/hive.dart';
import '../models/student_model.dart';
import '../models/teacher_model.dart';

class DatabaseService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseStorage _storage = FirebaseStorage.instance;
  static late Box<StudentModel> _studentBox;
  static late Box<TeacherModel> _teacherBox;
  static late Box _settingsBox;

  static Future<void> init() async {
    _studentBox = await Hive.openBox<StudentModel>('students');
    _teacherBox = await Hive.openBox<TeacherModel>('teachers');
    _settingsBox = await Hive.openBox('settings');
  }

  // ── Student CRUD ──
  static List<StudentModel> getAllStudents() => _studentBox.values.toList();

  static Future<bool> addStudent(StudentModel student) async {
    await _studentBox.put(student.id, student);
    try {
      await _firestore.collection('students').doc(student.id).set(student.toMap()).timeout(const Duration(seconds: 4));
      return true;
    } catch (e) { return false; }
  }

  static Future<bool> updateStudent(StudentModel student) async {
    await _studentBox.put(student.id, student);
    try {
      await _firestore.collection('students').doc(student.id).update(student.toMap()).timeout(const Duration(seconds: 4));
      return true;
    } catch (e) { return false; }
  }

  static Future<bool> deleteStudent(String id) async {
    await _studentBox.delete(id);
    try {
      await _firestore.collection('students').doc(id).delete().timeout(const Duration(seconds: 4));
      return true;
    } catch (e) { return false; }
  }

  // ── Teacher CRUD ──
  static List<TeacherModel> getAllTeachers() => _teacherBox.values.toList();

  static Future<bool> addTeacher(TeacherModel teacher) async {
    await _teacherBox.put(teacher.id, teacher);
    try {
      await _firestore.collection('teachers').doc(teacher.id).set(teacher.toMap()).timeout(const Duration(seconds: 4));
      return true;
    } catch (e) { return false; }
  }

  static Future<bool> updateTeacher(TeacherModel teacher) async {
    await _teacherBox.put(teacher.id, teacher);
    try {
      await _firestore.collection('teachers').doc(teacher.id).update(teacher.toMap()).timeout(const Duration(seconds: 4));
      return true;
    } catch (e) { return false; }
  }

  static Future<bool> deleteTeacher(String id) async {
    await _teacherBox.delete(id);
    try {
      await _firestore.collection('teachers').doc(id).delete().timeout(const Duration(seconds: 4));
      return true;
    } catch (e) { return false; }
  }

  // ── Image Upload (works on Web + Mobile) ──
  static Future<String?> uploadImage(Uint8List imageBytes, String folder) async {
    try {
      String fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      Reference ref = _storage.ref().child('$folder/$fileName');
      await ref.putData(imageBytes, SettableMetadata(contentType: 'image/jpeg'));
      // FIXED: was ref.ref.getDownloadURL() — removed the extra .ref
      return await ref.getDownloadURL();
    } catch (e) { return null; }
  }

  // ── Image Delete ──
  static Future<void> deleteImage(String imageUrl) async {
    try { await _storage.refFromURL(imageUrl).delete(); } catch (e) {}
  }

  // ── Sync ──
  static Future<void> syncFromFirestore() async {
    try {
      var s = await _firestore.collection('students').get();
      await _studentBox.clear();
      for (var doc in s.docs) {
        await _studentBox.put(doc.id, StudentModel.fromMap(doc.data() as Map<String, dynamic>, doc.id));
      }
      var t = await _firestore.collection('teachers').get();
      await _teacherBox.clear();
      for (var doc in t.docs) {
        await _teacherBox.put(doc.id, TeacherModel.fromMap(doc.data() as Map<String, dynamic>, doc.id));
      }
    } catch (e) {}
  }

  static Future<void> syncToFirestore() async {
    try {
      for (var s in _studentBox.values) {
        await _firestore.collection('students').doc(s.id).set(s.toMap());
      }
      for (var t in _teacherBox.values) {
        await _firestore.collection('teachers').doc(t.id).set(t.toMap());
      }
    } catch (e) {}
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
  static int get totalTeachers => _teacherBox.length;
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
  static double get totalTeacherSalaries {
    double t = 0;
    for (var s in _teacherBox.values) { t += s.salary; }
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
        print('Firestore academy profile sync timed out/failed: $e');
      }
    }
  }

  // ── Backup & Restore ──
  static String exportBackup() {
    final students = _studentBox.values.map((s) => s.toMap()).toList();
    final teachers = _teacherBox.values.map((t) => t.toMap()).toList();
    final profile = getAcademyProfile();

    final data = {
      'students': students,
      'teachers': teachers,
      'academy_profile': profile,
      'backup_time': DateTime.now().toIso8601String(),
    };

    return jsonEncode(data);
  }

  static Future<bool> importBackup(String jsonStr) async {
    try {
      final data = jsonDecode(jsonStr) as Map<String, dynamic>;
      if (!data.containsKey('students') || !data.containsKey('teachers')) {
        return false;
      }

      await _studentBox.clear();
      await _teacherBox.clear();

      final studentsList = data['students'] as List;
      for (var sMap in studentsList) {
        final s = StudentModel.fromMap(Map<String, dynamic>.from(sMap), sMap['id']);
        await _studentBox.put(s.id, s);
      }

      final teachersList = data['teachers'] as List;
      for (var tMap in teachersList) {
        final t = TeacherModel.fromMap(Map<String, dynamic>.from(tMap), tMap['id']);
        await _teacherBox.put(t.id, t);
      }

      if (data.containsKey('academy_profile')) {
        await saveAcademyProfile(Map<String, dynamic>.from(data['academy_profile']));
      }

      // Async sync to Firestore
      syncToFirestore();
      return true;
    } catch (e) {
      return false;
    }
  }
}