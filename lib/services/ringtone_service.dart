import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Service handal untuk memutar nada dering panggilan masuk dan nada panggil keluar
class RingtoneService {
  RingtoneService._();
  static final RingtoneService instance = RingtoneService._();

  AudioPlayer? _player;
  Timer? _vibrationTimer;
  bool _isPlaying = false;

  // Google Sound Library: nada dering telepon yang sangat jernih dan berdering stabil
  static const String incomingRingtoneUrl =
      'https://actions.google.com/sounds/v1/alarms/phone_alerts_and_rings.ogg';

  // Nada panggil (ring-back tone saat menunggu diangkat)
  static const String outgoingCallingToneUrl =
      'https://actions.google.com/sounds/v1/alarms/beep_short.ogg';

  /// Memulai dering panggilan masuk berulang (looping) + getaran haptik
  Future<void> startIncomingRingtone() async {
    if (_isPlaying) return;
    _isPlaying = true;

    try {
      _player ??= AudioPlayer();
      await _player!.setReleaseMode(ReleaseMode.loop);
      await _player!.setVolume(1.0);
      await _player!.play(UrlSource(incomingRingtoneUrl));
    } catch (e) {
      debugPrint('Error starting incoming ringtone: $e');
    }

    _vibrationTimer?.cancel();
    _triggerHapticPattern();
    _vibrationTimer = Timer.periodic(const Duration(milliseconds: 1400), (_) {
      if (_isPlaying) {
        _triggerHapticPattern();
      }
    });
  }

  void _triggerHapticPattern() {
    try {
      HapticFeedback.heavyImpact();
      Future.delayed(const Duration(milliseconds: 200), () {
        HapticFeedback.heavyImpact();
      });
    } catch (_) {}
  }

  /// Menghentikan dering seketika saat dijawab atau ditolak
  Future<void> stopRingtone() async {
    _isPlaying = false;
    _vibrationTimer?.cancel();
    _vibrationTimer = null;

    try {
      if (_player != null) {
        await _player!.stop();
        await _player!.dispose();
        _player = null;
      }
    } catch (e) {
      debugPrint('Error stopping ringtone: $e');
    }
  }
}
