import 'package:flutter/services.dart';

/// Plays a system-level notification sound + haptic feedback.
///
/// Uses only Flutter built-ins ([SystemSound] and [HapticFeedback]),
/// so no extra packages or asset files are required.
///
/// Usage:
///   await SoundService.playNotification();          // standard alert
///   await SoundService.playImportantAlert();        // heavy + alert (urgent)
class SoundService {
  SoundService._();

  // ── Standard notification ─────────────────────────────────────────────────

  /// Plays the platform's built-in alert click sound plus a light haptic tap.
  /// Use for everyday notifications (new student, fee update, attendance…).
  static Future<void> playNotification() async {
    await Future.wait([
      SystemSound.play(SystemSoundType.click),
      HapticFeedback.lightImpact(),
    ]);
  }

  // ── Important / urgent alert ──────────────────────────────────────────────

  /// Plays the alert sound twice with a medium haptic for high-priority events.
  static Future<void> playImportantAlert() async {
    await HapticFeedback.mediumImpact();
    await SystemSound.play(SystemSoundType.click);
    await Future.delayed(const Duration(milliseconds: 180));
    await SystemSound.play(SystemSoundType.click);
  }

  // ── Success confirmation ──────────────────────────────────────────────────

  /// Plays a single click sound for success / confirmation feedback.
  static Future<void> playSuccess() async {
    await Future.wait([
      SystemSound.play(SystemSoundType.click),
      HapticFeedback.selectionClick(),
    ]);
  }
}
