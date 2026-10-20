import 'dart:async';
// ignore: avoid_web_libraries_in_flutter
import 'dart:io' if (dart.library.html) 'package:my_academy_app/utils/io_stub.dart' as io;
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';

class ImageUtils {
  /// Compresses and resizes raw image bytes into lightweight PNG format.
  /// Enables instant UI rendering and sub-second uploads to Firebase & Supabase.
  static Future<Uint8List> compressAndResizeImage(
    Uint8List bytes, {
    int targetWidth = 360,
    int targetHeight = 360,
    int quality = 75,
  }) async {
    if (bytes.isEmpty) return bytes;
    try {
      final codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: targetWidth,
        targetHeight: targetHeight,
      );
      final frame = await codec.getNextFrame();
      final image = frame.image;
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      codec.dispose();

      if (byteData != null) {
        final result = byteData.buffer.asUint8List(
          byteData.offsetInBytes,
          byteData.lengthInBytes,
        );
        debugPrint('Image processed: ${bytes.length} bytes -> ${result.length} bytes');
        return result;
      }
      return bytes;
    } catch (e) {
      debugPrint('Error compressing image: $e');
      return bytes;
    }
  }

  /// Gets the predictable local path for a student's profile picture.
  static Future<String> getLocalProfilePath(String studentId) async {
    if (kIsWeb) return '';
    final directory = await getApplicationDocumentsDirectory();
    final profileDir = io.Directory('${directory.path}/profiles');
    if (!await profileDir.exists()) {
      await profileDir.create(recursive: true);
    }
    return '${profileDir.path}/student_$studentId.png';
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
      if (io.File(path).existsSync()) return true;
      // Also check legacy .jpg
      final directory = await getApplicationDocumentsDirectory();
      final legacyPath = '${directory.path}/profiles/student_$studentId.jpg';
      return io.File(legacyPath).existsSync();
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
      if (file.existsSync()) {
        await file.delete();
      }
      final directory = await getApplicationDocumentsDirectory();
      final legacyFile = io.File('${directory.path}/profiles/student_$studentId.jpg');
      if (legacyFile.existsSync()) {
        await legacyFile.delete();
      }
      debugPrint('Local image deleted for student $studentId');
    } catch (e) {
      debugPrint('Error deleting local image: $e');
    }
  }
}

