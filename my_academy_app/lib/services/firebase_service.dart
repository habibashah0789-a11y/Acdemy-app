import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

/// Centralized service for Firebase Core, Authentication, Cloud Storage, and FCM.
class FirebaseService {
  static FirebaseAuth get auth => FirebaseAuth.instance;
  static FirebaseStorage get storage => FirebaseStorage.instance;
  static FirebaseMessaging get messaging => FirebaseMessaging.instance;

  static User? get currentUser => auth.currentUser;
  static bool get isAuthenticated => currentUser != null;
  static String? get currentUserId => currentUser?.uid;

  /// Check connection and authentication status
  static Future<bool> checkConnection() async {
    try {
      if (Firebase.apps.isEmpty) return false;
      return true;
    } catch (e) {
      debugPrint('[FIREBASE SERVICE] Connection check error: $e');
      return false;
    }
  }

  // ── Authentication ──
  static Future<UserCredential?> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      return await auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } catch (e) {
      debugPrint('[FIREBASE SERVICE] Sign in error: $e');
      rethrow;
    }
  }

  static Future<void> signOut() async {
    try {
      await auth.signOut();
    } catch (e) {
      debugPrint('[FIREBASE SERVICE] Sign out error: $e');
    }
  }

  // ── Storage Operations ──
  static Future<String?> uploadFile({
    required Uint8List bytes,
    required String path,
    String contentType = 'image/png',
    Duration timeout = const Duration(seconds: 8),
  }) async {
    try {
      final ref = storage.ref().child(path);
      await ref
          .putData(bytes, SettableMetadata(contentType: contentType))
          .timeout(timeout);
      return await ref.getDownloadURL().timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint('[FIREBASE SERVICE] Storage upload error ($path): $e');
      return null;
    }
  }

  static Future<void> deleteFile(String url) async {
    try {
      if (url.startsWith('http')) {
        await storage.refFromURL(url).delete();
      }
    } catch (e) {
      debugPrint('[FIREBASE SERVICE] Storage delete error: $e');
    }
  }

  // ── FCM Push Notifications ──
  static Future<String?> getFCMToken() async {
    try {
      return await messaging.getToken();
    } catch (e) {
      debugPrint('[FIREBASE SERVICE] FCM token error: $e');
      return null;
    }
  }
}
