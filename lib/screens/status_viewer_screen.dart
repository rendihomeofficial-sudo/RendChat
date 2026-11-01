import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/chat_model.dart';
import '../models/message_model.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/chat_service.dart';
import '../widgets/universal_image.dart';
import '../widgets/user_avatar.dart';
import '../theme/whatsapp_theme.dart';
import 'chat_screen.dart';

class StatusViewerScreen extends StatefulWidget {
  final String statusId;
  final String userId;
  final String userName;
  final String? userAvatar;
  final String statusText;
  final String? mediaUrl;
  final String? musicUrl;
  final String? musicTitle;
  final Color backgroundColor;

  const StatusViewerScreen({
    super.key,
    this.statusId = '',
    this.userId = '',
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
  bool _isPaused = false;
  final TextEditingController _replyController = TextEditingController();

  final List<String> _quickEmojis = ['❤️', '😂', '😮', '😢', '👏', '🔥'];

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

    // 8 seconds progress bar like WhatsApp status
    _timer = Timer.periodic(const Duration(milliseconds: 80), (timer) {
      if (!mounted) return;
      if (_isPaused) return;

      setState(() {
        _progress += 0.01;
        if (_progress >= 1.0) {
          _timer?.cancel();
          _stopAudio();
          Navigator.pop(context);
        }
      });
    });
  }

  void _stopAudio() {
    try {
      _audioPlayer?.stop();
      _audioPlayer?.dispose();
      _audioPlayer = null;
    } catch (_) {}
  }

  void _pauseStatus() {
    setState(() => _isPaused = true);
    _audioPlayer?.pause();
  }

  void _resumeStatus() {
    setState(() => _isPaused = false);
    _audioPlayer?.resume();
  }

  Future<void> _sendReplyOrReaction(String content, {bool isReaction = false}) async {
    final auth = context.read<AuthService>();
    final chatService = context.read<ChatService>();
    final currentUser = auth.appUser;
    if (currentUser == null) return;

    if (widget.userId.isEmpty || widget.userId == currentUser.uid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak dapat membalas status milik sendiri.')),
      );
      return;
    }

    try {
      final otherUser = AppUser(
        uid: widget.userId,
        email: '',
        displayName: widget.userName,
        photoURL: widget.userAvatar,
        lastSeen: DateTime.now(),
        createdAt: DateTime.now(),
      );

      final chat = await chatService.getOrCreate1on1Chat(
        currentUser: currentUser,
        otherUser: otherUser,
      );

      final replySnippet = widget.statusText.isNotEmpty
          ? widget.statusText
          : (widget.mediaUrl != null ? '📷 Status' : 'Status');

      await chatService.sendMessage(
        chatId: chat.id,
        senderId: currentUser.uid,
        senderName: currentUser.displayName,
        text: isReaction ? content : 'Replying to status: "$content"',
        type: MessageType.text,
        replyToSenderName: widget.userName,
        replyToText: 'Story: $replySnippet',
      );

      HapticFeedback.lightImpact();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isReaction ? 'Reaksi $content terkirim!' : 'Balasan status terkirim!'),
            backgroundColor: WhatsAppTheme.primaryTeal,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error replying to status: $e');
    }
  }

  void _openReplyBottomSheet() {
    _pauseStatus();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1F2C34),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
          left: 16,
          right: 16,
          top: 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Quick Emojis
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: _quickEmojis.map((emoji) {
                return InkWell(
                  onTap: () {
                    Navigator.pop(ctx);
                    _sendReplyOrReaction(emoji, isReaction: true);
                    _resumeStatus();
                  },
                  borderRadius: BorderRadius.circular(24),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(emoji, style: const TextStyle(fontSize: 28)),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            // Text reply field
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _replyController,
                    autofocus: true,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Balas status ${widget.userName}...',
                      hintStyle: const TextStyle(color: Colors.white60),
                      filled: true,
                      fillColor: const Color(0xFF121B22),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: WhatsAppTheme.primaryTeal,
                  child: IconButton(
                    icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                    onPressed: () {
                      final text = _replyController.text.trim();
                      if (text.isNotEmpty) {
                        Navigator.pop(ctx);
                        _replyController.clear();
                        _sendReplyOrReaction(text, isReaction: false);
                        _resumeStatus();
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    ).then((_) => _resumeStatus());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _stopAudio();
    _replyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final isMyStatus = auth.currentUid == widget.userId || widget.userId.isEmpty;

    return GestureDetector(
      onLongPressStart: (_) => _pauseStatus(),
      onLongPressEnd: (_) => _resumeStatus(),
      child: Scaffold(
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
                        bottom: 84,
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

              // Bottom Reply Bar (WhatsApp Realtime Reply & Reactions)
              if (!isMyStatus)
                Positioned(
                  bottom: 12,
                  left: 16,
                  right: 16,
                  child: InkWell(
                    onTap: _openReplyBottomSheet,
                    borderRadius: BorderRadius.circular(28),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(color: Colors.white30),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.keyboard_arrow_up_rounded, color: Colors.white70),
                          SizedBox(width: 8),
                          Text(
                            'Balas status...',
                            style: TextStyle(color: Colors.white70, fontSize: 14),
                          ),
                          Spacer(),
                          Text('❤️  😂  🔥', style: TextStyle(fontSize: 16)),
                        ],
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
      ),
    );
  }
}
