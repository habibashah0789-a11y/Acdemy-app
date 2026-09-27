import 'package:flutter/material.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive/hive.dart';
import '../models/student_model.dart';

class SyncService extends ChangeNotifier {
  bool _initialized = false;
  // Stream subscription for Firestore updates.
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subscription;
  // Stream subscription for Firebase Auth state updates.
  StreamSubscription<User?>? _authSubscription;
  // Local cache of students (mirrors Hive content).
  List<StudentModel> _students = [];

  List<StudentModel> get students => List.unmodifiable(_students);

  // Initialize Hive box reference and setup auth-aware synchronization.
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    // Ensure Hive box is opened.
    final Box<StudentModel> studentBox = Hive.isBoxOpen('students')
        ? Hive.box<StudentModel>('students')
        : await Hive.openBox<StudentModel>('students');
    // Load existing cached students from Hive immediately.
    _students = studentBox.values.toList();
    notifyListeners();

    // Listen for authentication state changes so synchronization only runs when logged in
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) {
        _subscribeToFirestore(studentBox);
      } else {
        _cancelFirestoreSubscription();
      }
    });

    // Check current auth status on initial setup
    if (FirebaseAuth.instance.currentUser != null) {
      _subscribeToFirestore(studentBox);
    }
  }

  void _subscribeToFirestore(Box<StudentModel> studentBox) {
    if (FirebaseAuth.instance.currentUser == null) return;

    _subscription?.cancel();
    _subscription = FirebaseFirestore.instance
        .collection('students')
        .snapshots()
        .listen((snapshot) async {
      bool changed = false;
      for (var change in snapshot.docChanges) {
        switch (change.type) {
          case DocumentChangeType.added:
          case DocumentChangeType.modified:
            if (change.doc.data() == null) continue;
            final student = StudentModel.fromFirestore(change.doc);
            await studentBox.put(student.id, student);
            changed = true;
            break;
          case DocumentChangeType.removed:
            // Always process removals — data may be null for deleted docs
            await studentBox.delete(change.doc.id);
            changed = true;
            break;
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

  void _cancelFirestoreSubscription() {
    _subscription?.cancel();
    _subscription = null;
  }

  // Graceful shutdown.
  Future<void> disposeService() async {
    await _authSubscription?.cancel();
    _cancelFirestoreSubscription();
  }

  @override
  void dispose() {
    disposeService();
    super.dispose();
  }
}
