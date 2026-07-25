import 'dart:io' as io;
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';

class ImageUtils {
  /// Gets the predictable local path for a student's profile picture.
  static Future<String> getLocalProfilePath(String studentId) async {
    if (kIsWeb) return '';
    final directory = await getApplicationDocumentsDirectory();
    final profileDir = io.Directory('${directory.path}/profiles');
    if (!await profileDir.exists()) {
      await profileDir.create(recursive: true);
    }
    return '${profileDir.path}/student_$studentId.jpg';
  }

  /// Saves the given image bytes to the local profile picture path.
  static Future<void> saveImageLocally(String studentId, Uint8List bytes) async {
    if (kIsWeb) return;
    try {
      final path = await getLocalProfilePath(studentId);
      final file = io.File(path);
      await file.writeAsBytes(bytes);
      debugPrint('Image saved locally for student $studentId at: $path');
    } catch (e) {
      debugPrint('Error saving image locally: $e');
    }
  }

  /// Checks if a local profile picture exists for the given student.
  static Future<bool> localImageExists(String studentId) async {
    if (kIsWeb) return false;
    try {
      final path = await getLocalProfilePath(studentId);
      return await io.File(path).exists();
    } catch (e) {
      return false;
    }
  }

  /// Deletes the local profile picture for the given student.
  static Future<void> deleteLocalImage(String studentId) async {
    if (kIsWeb) return;
    try {
      final path = await getLocalProfilePath(studentId);
      final file = io.File(path);
      if (await file.exists()) {
        await file.delete();
        debugPrint('Local image deleted for student $studentId');
      }
    } catch (e) {
      debugPrint('Error deleting local image: $e');
    }
  }
}
