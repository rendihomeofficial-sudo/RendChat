import 'dart:math';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import '../theme/whatsapp_theme.dart';

class VoiceNotePlayerWidget extends StatefulWidget {
  final String audioUrl;
  final int durationSeconds;
  final bool isMe;

  const VoiceNotePlayerWidget({
    super.key,
    required this.audioUrl,
    required this.durationSeconds,
    required this.isMe,
  });

  @override
  State<VoiceNotePlayerWidget> createState() => _VoiceNotePlayerWidgetState();
}

class _VoiceNotePlayerWidgetState extends State<VoiceNotePlayerWidget> {
  late final AudioPlayer _player;
  PlayerState _playerState = PlayerState.stopped;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  /// Kecepatan putar aktif (1x, 1.5x, 2x).
  double _playbackRate = 1.0;

  /// True setelah sumber audio berhasil dimuat (seek baru mungkin dilakukan).
  bool _sourceLoaded = false;

  static const List<double> _rateSteps = [1.0, 1.5, 2.0];

  /// Waveform visualizer amplitudes (bar height multipliers)
  late final List<double> _waveformBars;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _duration = Duration(seconds: widget.durationSeconds);

    // Generate unique organic waveform bars based on audioUrl hash
    final rand = Random(widget.audioUrl.hashCode);
    _waveformBars = List.generate(34, (i) {
      final base = (sin(i * 0.45) * 0.4 + 0.6);
      final jitter = (rand.nextDouble() * 0.4 - 0.2);
      return (base + jitter).clamp(0.2, 1.0);
    });

    _player.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() => _playerState = state);
    });

    _player.onPositionChanged.listen((pos) {
      if (mounted) setState(() => _position = pos);
    });

    _player.onDurationChanged.listen((dur) {
      if (mounted && dur.inSeconds > 0) setState(() => _duration = dur);
    });

    _player.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _playerState = PlayerState.stopped;
          _position = Duration.zero;
        });
      }
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    if (_playerState == PlayerState.playing) {
      await _player.pause();
    } else {
      if (_position >= _duration && _duration > Duration.zero) {
        await _player.seek(Duration.zero);
      }
      await _player.play(UrlSource(widget.audioUrl));
      if (!mounted) return;
      _sourceLoaded = true;
      await _player.setPlaybackRate(_playbackRate);
    }
  }

  /// Ganti kecepatan putar ke langkah berikutnya (1x -> 1.5x -> 2x -> 1x).
  Future<void> _cyclePlaybackRate() async {
    final idx = _rateSteps.indexOf(_playbackRate);
    final next = _rateSteps[(idx + 1) % _rateSteps.length];
    if (!mounted) return;
    setState(() => _playbackRate = next);
    try {
      await _player.setPlaybackRate(next);
    } catch (_) {
      // Sebagian perangkat tidak mendukung setPlaybackRate.
    }
  }

  /// Seek ke posisi tertentu (0..1).
  Future<void> _seekToFraction(double fraction) async {
    final total = _duration.inMilliseconds;
    if (total <= 0) return;
    if (!_sourceLoaded) return;
    final clamped = fraction.clamp(0.0, 1.0);
    final target = Duration(milliseconds: (total * clamped).round());
    try {
      await _player.seek(target);
    } catch (_) {
      return;
    }
    if (!mounted) return;
    setState(() => _position = target);
  }

  void _handleSeekUpdate(double value, double width) {
    if (width <= 0) return;
    _seekToFraction((value / width).clamp(0.0, 1.0));
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isPlaying = _playerState == PlayerState.playing;
    final totalSec = _duration.inSeconds > 0 ? _duration.inSeconds : (widget.durationSeconds > 0 ? widget.durationSeconds : 1);
    final currentSec = _position.inSeconds.clamp(0, totalSec);
    final progress = (currentSec / totalSec).clamp(0.0, 1.0);

    return Container(
      width: 250,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: WhatsAppTheme.primaryTeal,
            child: IconButton(
              icon: Icon(
                isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: Colors.white,
                size: 22,
              ),
              onPressed: _togglePlay,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Waveform Audio Notations Bars (WhatsApp Voice Note Visualizer)
                LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;
                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapDown: (details) => _handleSeekUpdate(details.localPosition.dx, width),
                      onHorizontalDragStart: (details) =>
                          _handleSeekUpdate(details.localPosition.dx, width),
                      onHorizontalDragUpdate: (details) =>
                          _handleSeekUpdate(details.localPosition.dx, width),
                      child: SizedBox(
                        height: 28,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: List.generate(_waveformBars.length, (idx) {
                            final barFraction = (idx + 1) / _waveformBars.length;
                            final isPassed = barFraction <= progress;
                            final barHeight = 26.0 * _waveformBars[idx];

                            return Container(
                              width: 3.0,
                              height: barHeight.clamp(4.0, 26.0),
                              decoration: BoxDecoration(
                                color: isPassed
                                    ? (widget.isMe ? Colors.white : WhatsAppTheme.primaryTeal)
                                    : Colors.white24,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            );
                          }),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isPlaying ? _formatDuration(_position) : _formatDuration(_duration),
                      style: const TextStyle(fontSize: 11, color: WhatsAppTheme.darkTextSecondary),
                    ),
                    GestureDetector(
                      onTap: _cyclePlaybackRate,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${_playbackRate.toStringAsFixed(_playbackRate % 1 == 0 ? 0 : 1)}x',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: widget.isMe ? Colors.white : WhatsAppTheme.primaryTeal,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
