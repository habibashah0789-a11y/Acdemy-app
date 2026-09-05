import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Plays custom notification sound + haptic feedback.
///
/// Uses [AudioPlayer] to play the soft chime notification sound from `assets/sound/notification_chime.mp3`.
///
/// Usage:
///   await SoundService.playNotification();          // standard alert
///   await SoundService.playImportantAlert();        // heavy + alert (urgent)
class SoundService {
  SoundService._();

  static AudioPlayer? _audioPlayer;

  static AudioPlayer _getPlayer() {
    _audioPlayer ??= AudioPlayer();
    return _audioPlayer!;
  }

  // ── Standard notification ─────────────────────────────────────────────────

  /// Plays the custom chime sound plus a light haptic tap.
  /// Use for everyday notifications (new student, fee update, attendance…).
  static Future<void> playNotification() async {
    try {
      await HapticFeedback.lightImpact();
      final player = _getPlayer();
      await player.stop();
      try {
        await player.play(AssetSource('sound/notification_chime.mp3'));
      } catch (_) {
        await player.play(AssetSource('sound/Soft_chime_new_messa_#2-1788553589976.mp3'));
      }
    } catch (e) {
      debugPrint('Notice playing custom notification sound: $e');
      try {
        await SystemSound.play(SystemSoundType.alert);
      } catch (_) {}
    }
  }

  // ── Important / urgent alert ──────────────────────────────────────────────

  /// Plays the custom chime sound with a medium haptic for high-priority events.
  static Future<void> playImportantAlert() async {
    try {
      await HapticFeedback.mediumImpact();
      final player = _getPlayer();
      await player.stop();
      try {
        await player.play(AssetSource('sound/notification_chime.mp3'));
      } catch (_) {
        await player.play(AssetSource('sound/Soft_chime_new_messa_#2-1788553589976.mp3'));
      }
    } catch (e) {
      debugPrint('Notice playing custom notification sound: $e');
      try {
        await SystemSound.play(SystemSoundType.alert);
      } catch (_) {}
    }
  }

  // ── Success confirmation ──────────────────────────────────────────────────

  /// Plays a single click sound for success / confirmation feedback.
  static Future<void> playSuccess() async {
    try {
      await Future.wait([
        SystemSound.play(SystemSoundType.click),
        HapticFeedback.selectionClick(),
      ]);
    } catch (_) {}
  }
}



