import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import '../widgets/universal_image.dart';
import '../widgets/user_avatar.dart';
import '../theme/whatsapp_theme.dart';

class StatusViewerScreen extends StatefulWidget {
  final String userName;
  final String? userAvatar;
  final String statusText;
  final String? mediaUrl;
  final String? musicUrl;
  final String? musicTitle;
  final Color backgroundColor;

  const StatusViewerScreen({
    super.key,
    required this.userName,
    this.userAvatar,
    required this.statusText,
    this.mediaUrl,
    this.musicUrl,
    this.musicTitle,
    this.backgroundColor = const Color(0xFF005C4B),
  });

  @override
  State<StatusViewerScreen> createState() => _StatusViewerScreenState();
}

class _StatusViewerScreenState extends State<StatusViewerScreen> {
  double _progress = 0.0;
  Timer? _timer;
  AudioPlayer? _audioPlayer;
  bool _isPlayingMusic = false;

  @override
  void initState() {
    super.initState();
    _startPlayback();
  }

  void _startPlayback() async {
    // If status contains music, play the audio in background!
    if (widget.musicUrl != null && widget.musicUrl!.isNotEmpty) {
      try {
        _audioPlayer = AudioPlayer();
        await _audioPlayer?.play(UrlSource(widget.musicUrl!));
        if (mounted) setState(() => _isPlayingMusic = true);
      } catch (e) {
        debugPrint('Error playing status music: $e');
      }
    }

    // 6 seconds progress bar like WhatsApp status
    _timer = Timer.periodic(const Duration(milliseconds: 60), (timer) {
      if (mounted) {
        setState(() {
          _progress += 0.01;
          if (_progress >= 1.0) {
            _timer?.cancel();
            _stopAudio();
            Navigator.pop(context);
          }
        });
      }
    });
  }

  void _stopAudio() {
    try {
      _audioPlayer?.stop();
      _audioPlayer?.dispose();
      _audioPlayer = null;
    } catch (_) {}
  }

  @override
  void dispose() {
    _timer?.cancel();
    _stopAudio();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: widget.mediaUrl != null ? Colors.black : widget.backgroundColor,
      body: SafeArea(
        child: Stack(
          children: [
            // Media or Text
            if (widget.mediaUrl != null && widget.mediaUrl!.isNotEmpty)
              Positioned.fill(
                child: UniversalImage(
                  imageUrl: widget.mediaUrl!,
                  fit: BoxFit.contain,
                  placeholder: const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                  errorWidget: const Center(
                    child: Icon(Icons.broken_image, color: Colors.white54, size: 48),
                  ),
                ),
              ),

            // Music Sticker Badge if Status has song attached (WhatsApp-style)
            if (widget.musicTitle != null && widget.musicTitle!.isNotEmpty)
              Positioned(
                top: 70,
                left: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: WhatsAppTheme.primaryTeal.withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.music_note_rounded, color: WhatsAppTheme.primaryTeal, size: 16),
                      const SizedBox(width: 6),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 220),
                        child: Text(
                          widget.musicTitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Caption or Centered Status Text
            if (widget.statusText.isNotEmpty)
              widget.mediaUrl != null
                  ? Positioned(
                      bottom: 72,
                      left: 16,
                      right: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          widget.statusText,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    )
                  : Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32.0),
                        child: Text(
                          widget.statusText,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),

            // Top Status Bar Header
            Positioned(
              top: 8,
              left: 12,
              right: 12,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LinearProgressIndicator(
                    value: _progress,
                    backgroundColor: Colors.white30,
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                    minHeight: 2.5,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () {
                          _stopAudio();
                          Navigator.pop(context);
                        },
                      ),
                      UserAvatar(
                        name: widget.userName,
                        photoUrl: widget.userAvatar,
                        radius: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.userName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const Text(
                              'Just now',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.more_vert, color: Colors.white),
                        onPressed: () {},
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
