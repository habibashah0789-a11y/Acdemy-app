import 'package:flutter/material.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';
import '../models/student_model.dart';

class SyncService extends ChangeNotifier {
  bool _initialized = false;
  // Stream subscription for Firestore updates.
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subscription;
  // Local cache of students (mirrors Hive content).
  List<StudentModel> _students = [];

  List<StudentModel> get students => List.unmodifiable(_students);

  // Initialize Hive box reference. Should be called after DatabaseService.init().
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    // Ensure Hive box is opened.
    final Box<StudentModel> studentBox = await Hive.openBox<StudentModel>('students');
    // Load existing cached students.
    _students = studentBox.values.toList();
    notifyListeners();
    // Start listening to Firestore changes.
    _subscribeToFirestore(studentBox);
  }

  void _subscribeToFirestore(Box<StudentModel> studentBox) {
    _subscription?.cancel();
    _subscription = FirebaseFirestore.instance
        .collection('students')
        .snapshots()
        .listen((snapshot) async {
      bool changed = false;
      for (var change in snapshot.docChanges) {
        if (change.doc.data() == null) continue;
        final student = StudentModel.fromFirestore(change.doc);
        switch (change.type) {
          case DocumentChangeType.added:
          case DocumentChangeType.modified:
            await studentBox.put(student.id, student);
            changed = true;
            break;
          case DocumentChangeType.removed:
            await studentBox.delete(student.id);
            changed = true;
            break;
        }
      }

      // Prune local students not present in the current Firestore collection (e.g. deleted while offline)
      final firestoreIds = snapshot.docs.map((doc) => doc.id).toSet();
      for (var key in studentBox.keys) {
        if (!firestoreIds.contains(key)) {
          await studentBox.delete(key);
          changed = true;
        }
      }

      if (changed || _students.length != studentBox.length) {
        _students = studentBox.values.toList();
        notifyListeners();
      }
    }, onError: (error) {
      debugPrint('Firestore sync error: $error');
    });
  }

  // Graceful shutdown.
  Future<void> disposeService() async {
    await _subscription?.cancel();
    _subscription = null;
  }
}
