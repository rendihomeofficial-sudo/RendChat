import 'dart:async';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/chat_model.dart';
import '../models/message_model.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/chat_service.dart';
import '../services/settings_service.dart';
import '../services/storage_service.dart';
import '../theme/whatsapp_theme.dart';
import '../widgets/chat_feedback_widgets.dart';
import '../widgets/poll_creator_dialog.dart';
import '../widgets/user_avatar.dart';
import '../widgets/voice_note_player_widget.dart';
import '../widgets/universal_image.dart';
import 'call_screen.dart';
import 'contact_info_screen.dart';
import 'media_gallery_screen.dart';

class ChatScreen extends StatefulWidget {
  final Chat chat;

  const ChatScreen({super.key, required this.chat});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  final _picker = ImagePicker();
  Timer? _typingDebounce;
  bool _isTyping = false;
  bool _isUploading = false;
  String _uploadStatus = '';
  bool _hasInputText = false;
  bool _isViewOnceSelected = false;

  /// True selagi pesan sedang dikirim (menonaktifkan tombol kirim).
  bool _isSending = false;

  /// True saat pengguna menggulir jauh dari pesan terbaru.
  bool _showScrollToBottom = false;

  /// Jumlah pesan terakhir yang dirender, dipakai untuk deteksi pesan baru.
  int _lastMessageCount = 0;

  // Swipe-to-Reply quoted message state
  Message? _replyingToMessage;

  // Search state
  bool _isSearching = false;
  final _searchController = TextEditingController();
  String _searchQuery = '';

  // Real Audio Recorder & Voice Note Preview System
  late final AudioRecorder _audioRecorder;
  AudioPlayer? _previewPlayer;
  bool _isRecordingVoice = false;
  bool _isRecordingPaused = false;
  bool _isPreviewPlaying = false;
  int _recordDurationSeconds = 0;
  Timer? _recordTimer;
  String? _recordedFilePath;

  // Cached persistent streams to prevent stream re-creation & reload during typing
  Stream<List<Message>>? _messagesStream;
  Stream<Chat?>? _chatStream;
  Stream<List<String>>? _typingStream;
  Stream<AppUser?>? _otherUserStream;
  Stream<bool>? _isBlockedStream;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _audioRecorder = AudioRecorder();
    final auth = context.read<AuthService>();
    final chatService = context.read<ChatService>();
    final myUid = auth.currentUid;
    if (myUid != null) {
      chatService.markChatAsRead(widget.chat.id, myUid);
      _messagesStream = chatService.streamMessages(widget.chat.id);
      _chatStream = chatService.streamChat(widget.chat.id);
      _typingStream = chatService.streamTypingUsers(widget.chat.id, myUid);
      final otherUid = widget.chat.getOtherUserId(myUid);
      if (otherUid != null) {
        _otherUserStream = chatService.streamUserProfile(otherUid);
        _isBlockedStream = chatService.streamIsUserBlocked(currentUserId: myUid, targetUserId: otherUid);
      }
    }

    _scrollController.addListener(_onScrollChanged);
  }

  void _onScrollChanged() {
    if (!_scrollController.hasClients) return;
    // ListView memakai reverse: true, jadi offset 0 = pesan terbaru.
    final farFromBottom = _scrollController.offset > 120;
    if (farFromBottom != _showScrollToBottom) {
      setState(() => _showScrollToBottom = farFromBottom);
    }
  }

  void _scrollToLatest() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      _clearTypingStatus();
    }
  }

  void _clearTypingStatus() {
    _typingDebounce?.cancel();
    if (_isTyping) {
      _isTyping = false;
      try {
        final auth = context.read<AuthService>();
        final myUid = auth.currentUid;
        final myName = auth.appUser?.displayName ?? 'Seseorang';
        if (myUid != null) {
          context.read<ChatService>().setTypingStatus(
            chatId: widget.chat.id,
            userId: myUid,
            userName: myName,
            isTyping: false,
          );
        }
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _clearTypingStatus();
    _recordTimer?.cancel();
    _audioRecorder.dispose();
    _previewPlayer?.dispose();
    _typingDebounce?.cancel();
    _scrollController.removeListener(_onScrollChanged);
    _textController.dispose();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final tempDir = await getTemporaryDirectory();
        final path = '${tempDir.path}/vn_${DateTime.now().millisecondsSinceEpoch}.m4a';
        await _audioRecorder.start(
          const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 128000),
          path: path,
        );
        setState(() {
          _isRecordingVoice = true;
          _isRecordingPaused = false;
          _isPreviewPlaying = false;
          _recordDurationSeconds = 0;
          _recordedFilePath = path;
        });
        _recordTimer?.cancel();
        _recordTimer = Timer.periodic(const Duration(seconds: 1), (t) {
          if (mounted && !_isRecordingPaused) {
            setState(() => _recordDurationSeconds++);
          }
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Izin mikrofon diperlukan untuk merekam suara.')),
          );
        }
      }
    } catch (e) {
      debugPrint('Error starting recording: $e');
    }
  }

  Future<void> _pauseRecording() async {
    try {
      _recordTimer?.cancel();
      final path = await _audioRecorder.stop();
      if (path != null) {
        _recordedFilePath = path;
      }
      setState(() {
        _isRecordingPaused = true;
      });
    } catch (e) {
      debugPrint('Error pausing recording: $e');
    }
  }

  Future<void> _togglePreviewPlayback() async {
    final path = _recordedFilePath;
    if (path == null) return;

    _previewPlayer ??= AudioPlayer();

    if (_isPreviewPlaying) {
      await _previewPlayer?.pause();
      setState(() => _isPreviewPlaying = false);
    } else {
      await _previewPlayer?.play(DeviceFileSource(path));
      setState(() => _isPreviewPlaying = true);

      _previewPlayer?.onPlayerComplete.listen((_) {
        if (mounted) {
          setState(() => _isPreviewPlaying = false);
        }
      });
    }
  }

  Future<void> _stopAndSendRecording() async {
    _recordTimer?.cancel();
    if (_previewPlayer != null) {
      await _previewPlayer?.stop();
    }

    try {
      String? finalPath = _recordedFilePath;
      if (!_isRecordingPaused) {
        final path = await _audioRecorder.stop();
        if (path != null) finalPath = path;
      }

      final sec = _recordDurationSeconds;
      setState(() {
        _isRecordingVoice = false;
        _isRecordingPaused = false;
        _isPreviewPlaying = false;
        _recordDurationSeconds = 0;
      });

      if (finalPath == null) return;

      final file = File(finalPath);
      if (!await file.exists()) return;
      final bytes = await file.readAsBytes();

      if (bytes.isEmpty || sec < 1) {
        return;
      }

      setState(() {
        _isUploading = true;
        _uploadStatus = 'Mengirim pesan suara...';
      });

      final auth = context.read<AuthService>();
      final chatService = context.read<ChatService>();
      final storageService = context.read<StorageService>();
      final user = auth.appUser;
      if (user == null) return;

      final url = await storageService.uploadChatFile(
        chatId: widget.chat.id,
        filePath: finalPath,
        fileBytes: bytes,
        originalFileName: 'Voice_Note.m4a',
      );

      if (url != null) {
        await chatService.sendMessage(
          chatId: widget.chat.id,
          senderId: user.uid,
          senderName: user.displayName,
          text: 'Pesan Suara (${sec}d)',
          type: MessageType.voice,
          durationSeconds: sec,
          mediaUrl: url,
        );
      }
    } catch (e) {
      debugPrint('Error stopping recording: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
          _uploadStatus = '';
        });
      }
    }
  }

  Future<void> _cancelRecording() async {
    _recordTimer?.cancel();
    if (_previewPlayer != null) {
      await _previewPlayer?.stop();
    }
    if (!_isRecordingPaused) {
      await _audioRecorder.cancel();
    }
    setState(() {
      _isRecordingVoice = false;
      _isRecordingPaused = false;
      _isPreviewPlaying = false;
      _recordDurationSeconds = 0;
    });
  }


  void _onTextChanged(String text) {
    final hasText = text.trim().isNotEmpty;
    // Hanya panggil setState jika nilai hasText benar-benar berubah,
    // untuk mencegah re-render/reload pada setiap penekanan tombol keyboard.
    if (_hasInputText != hasText) {
      setState(() {
        _hasInputText = hasText;
      });
    }

    final auth = context.read<AuthService>();
    final chatService = context.read<ChatService>();
    final myUid = auth.currentUid;
    final myName = auth.appUser?.displayName ?? 'Someone';
    if (myUid == null) return;

    if (hasText && !_isTyping) {
      _isTyping = true;
      chatService.setTypingStatus(
        chatId: widget.chat.id,
        userId: myUid,
        userName: myName,
        isTyping: true,
      );
    }

    _typingDebounce?.cancel();
    _typingDebounce = Timer(const Duration(seconds: 3), () {
      if (_isTyping) {
        _isTyping = false;
        chatService.setTypingStatus(
          chatId: widget.chat.id,
          userId: myUid,
          userName: myName,
          isTyping: false,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    final auth = context.read<AuthService>();
    final chatService = context.read<ChatService>();
    final user = auth.appUser;
    if (user == null) return;

    final reply = _replyingToMessage;
    _textController.clear();
    _clearTypingStatus();
    _onTextChanged('');
    setState(() {
      _replyingToMessage = null;
      _isSending = true;
    });

    HapticFeedback.lightImpact();

    try {
      await chatService.sendMessage(
        chatId: widget.chat.id,
        senderId: user.uid,
        senderName: user.displayName,
        text: text,
        type: MessageType.text,
        replyToId: reply?.id,
        replyToSenderName: reply?.senderName,
        replyToText: reply != null ? _getReplyPreviewText(reply) : null,
        replyToType: reply?.type,
      );
      HapticFeedback.mediumImpact();
      _scrollToLatest();
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  String _getReplyPreviewText(Message msg) {
    if (msg.type == MessageType.image) return '📷 Photo';
    if (msg.type == MessageType.voice) return '🎤 Voice note';
    if (msg.type == MessageType.file) return '📎 ${msg.fileName ?? "File"}';
    if (msg.type == MessageType.poll) return '📊 ${msg.pollQuestion ?? "Poll"}';
    return msg.text;
  }

  Future<void> _pickAndSendImage({bool fromCamera = false}) async {
    final auth = context.read<AuthService>();
    final chatService = context.read<ChatService>();
    final storageService = context.read<StorageService>();
    final user = auth.appUser;
    if (user == null) return;

    try {
      final picked = await _picker.pickImage(
        source: fromCamera ? ImageSource.camera : ImageSource.gallery,
        maxWidth: 1440,
        maxHeight: 1440,
        imageQuality: 75,
      );
      if (picked == null) return;

      // WhatsApp-Style Media Preview with View-Once (1x) toggle
      final bool? shouldSendViewOnce = await _showMediaConfirmationDialog(
        context: context,
        filePath: picked.path,
        isVideo: false,
        title: 'Kirim Foto',
      );
      if (shouldSendViewOnce == null) return; // User cancelled

      setState(() {
        _isUploading = true;
        _uploadStatus = 'Mengunggah foto...';
      });

      final bytes = await picked.readAsBytes();
      final url = await storageService.uploadChatFile(
        chatId: widget.chat.id,
        filePath: picked.path,
        fileBytes: bytes,
        originalFileName: picked.name,
      );

      if (url != null) {
        final reply = _replyingToMessage;
        setState(() {
          _replyingToMessage = null;
          _isViewOnceSelected = false;
        });

        await chatService.sendMessage(
          chatId: widget.chat.id,
          senderId: user.uid,
          senderName: user.displayName,
          text: 'Photo',
          type: MessageType.image,
          mediaUrl: url,
          fileName: picked.name,
          isViewOnce: shouldSendViewOnce,
          replyToId: reply?.id,
          replyToSenderName: reply?.senderName,
          replyToText: reply != null ? _getReplyPreviewText(reply) : null,
          replyToType: reply?.type,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload photo: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
          _uploadStatus = '';
        });
      }
    }
  }

  Future<void> _pickAndSendAnyFile({bool documentOnly = false}) async {
    final auth = context.read<AuthService>();
    final chatService = context.read<ChatService>();
    final storageService = context.read<StorageService>();
    final user = auth.appUser;
    if (user == null) return;

    try {
      final files = documentOnly
          ? await FilePicker.pickFiles(
              type: FileType.custom,
              allowedExtensions: [
                'pdf',
                'doc',
                'docx',
                'xls',
                'xlsx',
                'ppt',
                'pptx',
                'txt',
                'csv',
                'zip',
                'rar',
                '7z',
              ],
            )
          : await FilePicker.pickFiles(type: FileType.any);
      if (files.isEmpty) return;

      final file = files.first;
      final fileName = file.name;

      setState(() {
        _isUploading = true;
        _uploadStatus = 'Mengunggah $fileName...';
      });

      final bytes = await file.xFile.readAsBytes();
      final size = await file.xFile.length();

      final url = await storageService.uploadChatFile(
        chatId: widget.chat.id,
        filePath: file.path,
        fileBytes: bytes,
        originalFileName: fileName,
      );

      if (url != null) {
        final ext = fileName.contains('.') ? fileName.split('.').last.toLowerCase() : '';
        final isImage = ['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(ext);
        final reply = _replyingToMessage;
        setState(() {
          _replyingToMessage = null;
        });

        await chatService.sendMessage(
          chatId: widget.chat.id,
          senderId: user.uid,
          senderName: user.displayName,
          text: fileName,
          type: isImage ? MessageType.image : MessageType.file,
          mediaUrl: url,
          fileName: fileName,
          fileSize: size,
          replyToId: reply?.id,
          replyToSenderName: reply?.senderName,
          replyToText: reply != null ? _getReplyPreviewText(reply) : null,
          replyToType: reply?.type,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload file: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
          _uploadStatus = '';
        });
      }
    }
  }

  Future<void> _pickAndSendVideo({bool fromCamera = false}) async {
    final auth = context.read<AuthService>();
    final chatService = context.read<ChatService>();
    final storageService = context.read<StorageService>();
    final user = auth.appUser;
    if (user == null) return;

    try {
      final picked = await _picker.pickVideo(
        source: fromCamera ? ImageSource.camera : ImageSource.gallery,
        maxDuration: const Duration(minutes: 5),
      );
      if (picked == null) return;

      // WhatsApp-Style Media Preview with View-Once (1x) toggle
      final bool? shouldSendViewOnce = await _showMediaConfirmationDialog(
        context: context,
        filePath: picked.path,
        isVideo: true,
        title: 'Kirim Video',
      );
      if (shouldSendViewOnce == null) return; // User cancelled

      setState(() {
        _isUploading = true;
        _uploadStatus = 'Mengunggah video...';
      });

      final bytes = await picked.readAsBytes();
      final size = await picked.length();
      final url = await storageService.uploadChatFile(
        chatId: widget.chat.id,
        filePath: picked.path,
        fileBytes: bytes,
        originalFileName: picked.name,
      );

      if (url != null) {
        final reply = _replyingToMessage;
        setState(() {
          _replyingToMessage = null;
        });

        await chatService.sendMessage(
          chatId: widget.chat.id,
          senderId: user.uid,
          senderName: user.displayName,
          text: shouldSendViewOnce ? 'Video (Sekali Lihat)' : '📹 Video: ${picked.name}',
          type: MessageType.file,
          mediaUrl: url,
          fileName: picked.name,
          fileSize: size,
          isViewOnce: shouldSendViewOnce,
          replyToId: reply?.id,
          replyToSenderName: reply?.senderName,
          replyToText: reply != null ? _getReplyPreviewText(reply) : null,
          replyToType: reply?.type,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengunggah video: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
          _uploadStatus = '';
        });
      }
    }
  }

  Future<bool?> _showMediaConfirmationDialog({
    required BuildContext context,
    required String filePath,
    required bool isVideo,
    required String title,
  }) async {
    bool isViewOnce = false;

    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setSheetState) {
            return SafeArea(
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.88,
                child: Column(
                  children: [
                    // Top Appbar with Cancel
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                            onPressed: () => Navigator.pop(ctx, null),
                          ),
                          const Spacer(),
                          Text(
                            title,
                            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const Spacer(),
                          const SizedBox(width: 48), // spacer
                        ],
                      ),
                    ),
                    // Media preview area
                    Expanded(
                      child: Center(
                        child: isVideo
                            ? Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(24),
                                    decoration: BoxDecoration(
                                      color: Colors.white12,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.videocam_rounded, size: 72, color: WhatsAppTheme.primaryTeal),
                                  ),
                                  const SizedBox(height: 16),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 24),
                                    child: Text(
                                      filePath.split(Platform.pathSeparator).last,
                                      maxLines: 2,
                                      textAlign: TextAlign.center,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(color: Colors.white70, fontSize: 14),
                                    ),
                                  ),
                                ],
                              )
                            : Image.file(
                                File(filePath),
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 64, color: Colors.grey),
                              ),
                      ),
                    ),
                    // Bottom control bar with WhatsApp View-Once (1x) button & Send button
                    Container(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                      color: const Color(0xFF111B21),
                      child: Row(
                        children: [
                          // WhatsApp View Once Toggle (1x Circle Button)
                          InkWell(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setSheetState(() {
                                isViewOnce = !isViewOnce;
                              });
                            },
                            borderRadius: BorderRadius.circular(24),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: isViewOnce
                                    ? WhatsAppTheme.primaryTeal
                                    : Colors.white.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isViewOnce ? WhatsAppTheme.primaryTeal : Colors.white24,
                                  width: 1.5,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 22,
                                    height: 22,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isViewOnce ? Colors.black : Colors.white,
                                        width: 1.8,
                                      ),
                                    ),
                                    child: Center(
                                      child: Text(
                                        '1',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                          color: isViewOnce ? Colors.black : Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    isViewOnce ? 'Sekali Lihat Aktif' : 'Sekali Lihat',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: isViewOnce ? Colors.black : Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const Spacer(),
                          // Send button
                          FloatingActionButton(
                            heroTag: 'send_media_confirmation',
                            backgroundColor: WhatsAppTheme.primaryTeal,
                            elevation: 2,
                            onPressed: () {
                              Navigator.pop(ctx, isViewOnce);
                            },
                            child: const Icon(Icons.send_rounded, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _pickAndSendAudioFile() async {
    final auth = context.read<AuthService>();
    final chatService = context.read<ChatService>();
    final storageService = context.read<StorageService>();
    final user = auth.appUser;
    if (user == null) return;

    try {
      final res = await FilePicker.pickFiles(type: FileType.audio);
      if (res.isEmpty) return;

      final file = res.first;
      final fileName = file.name;

      setState(() {
        _isUploading = true;
        _uploadStatus = 'Mengunggah audio $fileName...';
      });

      final bytes = await file.xFile.readAsBytes();
      final size = await file.xFile.length();

      final url = await storageService.uploadChatFile(
        chatId: widget.chat.id,
        filePath: file.path,
        fileBytes: bytes,
        originalFileName: fileName,
      );

      if (url != null) {
        final reply = _replyingToMessage;
        setState(() {
          _replyingToMessage = null;
        });

        await chatService.sendMessage(
          chatId: widget.chat.id,
          senderId: user.uid,
          senderName: user.displayName,
          text: '🎵 Audio: $fileName',
          type: MessageType.file,
          mediaUrl: url,
          fileName: fileName,
          fileSize: size,
          replyToId: reply?.id,
          replyToSenderName: reply?.senderName,
          replyToText: reply != null ? _getReplyPreviewText(reply) : null,
          replyToType: reply?.type,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengunggah audio: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
          _uploadStatus = '';
        });
      }
    }
  }

  void _sendSimulatedVoiceNote() async {
    final auth = context.read<AuthService>();
    final chatService = context.read<ChatService>();
    final user = auth.appUser;
    if (user == null) return;

    await chatService.sendMessage(
      chatId: widget.chat.id,
      senderId: user.uid,
      senderName: user.displayName,
      text: 'Voice note (0:08)',
      type: MessageType.voice,
      durationSeconds: 8,
      mediaUrl: 'https://actions.google.com/sounds/v1/alarms/beep_short.ogg',
    );
  }

  Future<void> _openContactInfo(BuildContext context, String title, String? avatarUrl) async {
    final action = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ContactInfoScreen(
          chat: widget.chat,
          title: title,
          avatarUrl: avatarUrl,
          currentUserId: context.read<AuthService>().currentUid ?? '',
        ),
      ),
    );
    if (!mounted) return;
    if (action == 'media') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MediaGalleryScreen(chatId: widget.chat.id, title: title),
        ),
      );
    } else if (action == 'search') {
      setState(() => _isSearching = true);
    }
  }

  void _showChatWallpaperPicker(BuildContext context) {
    final settings = context.read<SettingsService>();
    final options = [
      'Default Doodle',
      'Solid Emerald',
      'Deep Navy',
      'Charcoal Grey',
      'Sunset Violet'
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: WhatsAppTheme.darkSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (bCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Wallpaper Obrolan', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(bCtx),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: WhatsAppTheme.primaryTeal.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.photo_library_rounded, color: WhatsAppTheme.primaryTeal),
                ),
                title: const Text('Pilih Foto dari Galeri Pribadi', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Gunakan foto favorit Anda sebagai wallpaper obrolan', style: TextStyle(fontSize: 12, color: WhatsAppTheme.darkTextSecondary)),
                onTap: () async {
                  Navigator.pop(bCtx);
                  try {
                    final picked = await _picker.pickImage(
                      source: ImageSource.gallery,
                      maxWidth: 1920,
                      maxHeight: 1920,
                      imageQuality: 90,
                    );
                    if (picked != null) {
                      await settings.setCustomWallpaperPath(picked.path);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Wallpaper foto pribadi berhasil diterapkan!')),
                        );
                      }
                    }
                  } catch (e) {
                    debugPrint('Error picking wallpaper image: $e');
                  }
                },
              ),
              const Divider(height: 16),
              const Text('Warna Baku Solid', style: TextStyle(fontSize: 13, color: WhatsAppTheme.darkTextSecondary, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: options.map((opt) {
                  final isSelected = settings.chatWallpaper == opt;
                  return ChoiceChip(
                    label: Text(opt),
                    selected: isSelected,
                    selectedColor: WhatsAppTheme.primaryTeal.withValues(alpha: 0.3),
                    onSelected: (_) async {
                      await settings.setCustomWallpaperPath(null);
                      await settings.setChatWallpaper(opt);
                      if (mounted) Navigator.pop(bCtx);
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  void _showMuteChatDialog(BuildContext context, ChatService chatService, String currentUid) {
    final isCurrentlyMuted = widget.chat.isMutedFor(currentUid);
    if (isCurrentlyMuted) {
      showDialog(
        context: context,
        builder: (dCtx) => AlertDialog(
          backgroundColor: WhatsAppTheme.darkSurface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Bunyikan Notifikasi?'),
          content: const Text(
            'Notifikasi untuk obrolan ini saat ini dibisukan. Apakah Anda ingin mengaktifkan kembali bunyinya?',
            style: TextStyle(color: WhatsAppTheme.darkTextSecondary, fontSize: 13.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dCtx),
              child: const Text('Batal', style: TextStyle(color: WhatsAppTheme.darkTextSecondary)),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: WhatsAppTheme.primaryTeal),
              onPressed: () async {
                Navigator.pop(dCtx);
                await chatService.unmuteChat(chatId: widget.chat.id, userId: currentUid);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Notifikasi obrolan diaktifkan kembali')),
                  );
                }
              },
              child: const Text('Bunyikan'),
            ),
          ],
        ),
      );
      return;
    }

    int selectedDurationHours = 8;
    showDialog(
      context: context,
      builder: (dCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: WhatsAppTheme.darkSurface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Bisukan Notifikasi'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Peserta lain tidak akan tahu bahwa Anda telah membisukan obrolan ini.',
                style: TextStyle(color: WhatsAppTheme.darkTextSecondary, fontSize: 13.5),
              ),
              const SizedBox(height: 12),
              RadioListTile<int>(
                title: const Text('8 Jam'),
                value: 8,
                groupValue: selectedDurationHours,
                activeColor: WhatsAppTheme.primaryTeal,
                contentPadding: EdgeInsets.zero,
                onChanged: (val) => setDialogState(() => selectedDurationHours = val!),
              ),
              RadioListTile<int>(
                title: const Text('1 Minggu'),
                value: 168,
                groupValue: selectedDurationHours,
                activeColor: WhatsAppTheme.primaryTeal,
                contentPadding: EdgeInsets.zero,
                onChanged: (val) => setDialogState(() => selectedDurationHours = val!),
              ),
              RadioListTile<int>(
                title: const Text('Selalu'),
                value: 876000, // 100 tahun
                groupValue: selectedDurationHours,
                activeColor: WhatsAppTheme.primaryTeal,
                contentPadding: EdgeInsets.zero,
                onChanged: (val) => setDialogState(() => selectedDurationHours = val!),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dCtx),
              child: const Text('Batal', style: TextStyle(color: WhatsAppTheme.darkTextSecondary)),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: WhatsAppTheme.primaryTeal),
              onPressed: () async {
                Navigator.pop(dCtx);
                await chatService.muteChat(
                  chatId: widget.chat.id,
                  userId: currentUid,
                  duration: Duration(hours: selectedDurationHours),
                );
                if (mounted) {
                  final label = selectedDurationHours == 8
                      ? '8 jam'
                      : (selectedDurationHours == 168 ? '1 minggu' : 'selalu');
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Notifikasi dibisukan untuk $label')),
                  );
                }
              },
              child: const Text('Oke'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDisappearingMessagesPicker(BuildContext context, ChatService chatService) {
    int currentDuration = widget.chat.disappearingDuration ?? 0;

    showModalBottomSheet(
      context: context,
      backgroundColor: WhatsAppTheme.darkSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (bCtx) => StatefulBuilder(
        builder: (ctx, setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Pesan Sementara',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(bCtx),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Untuk privasi dan penyimpanan yang lebih terjaga, pesan baru akan terhapus otomatis setelah durasi yang dipilih.',
                  style: TextStyle(color: WhatsAppTheme.darkTextSecondary, fontSize: 13),
                ),
                const SizedBox(height: 12),
                RadioListTile<int>(
                  title: const Text('24 Jam'),
                  value: 86400,
                  groupValue: currentDuration,
                  activeColor: WhatsAppTheme.primaryTeal,
                  onChanged: (val) async {
                    setSheetState(() => currentDuration = val!);
                    Navigator.pop(bCtx);
                    await chatService.setDisappearingMessages(
                      chatId: widget.chat.id,
                      durationInSeconds: 86400,
                    );
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Pesan sementara disetel ke 24 jam')),
                      );
                    }
                  },
                ),
                RadioListTile<int>(
                  title: const Text('7 Hari'),
                  value: 604800,
                  groupValue: currentDuration,
                  activeColor: WhatsAppTheme.primaryTeal,
                  onChanged: (val) async {
                    setSheetState(() => currentDuration = val!);
                    Navigator.pop(bCtx);
                    await chatService.setDisappearingMessages(
                      chatId: widget.chat.id,
                      durationInSeconds: 604800,
                    );
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Pesan sementara disetel ke 7 hari')),
                      );
                    }
                  },
                ),
                RadioListTile<int>(
                  title: const Text('90 Hari'),
                  value: 7776000,
                  groupValue: currentDuration,
                  activeColor: WhatsAppTheme.primaryTeal,
                  onChanged: (val) async {
                    setSheetState(() => currentDuration = val!);
                    Navigator.pop(bCtx);
                    await chatService.setDisappearingMessages(
                      chatId: widget.chat.id,
                      durationInSeconds: 7776000,
                    );
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Pesan sementara disetel ke 90 hari')),
                      );
                    }
                  },
                ),
                RadioListTile<int>(
                  title: const Text('Mati (Nonaktif)'),
                  value: 0,
                  groupValue: currentDuration,
                  activeColor: WhatsAppTheme.primaryTeal,
                  onChanged: (val) async {
                    setSheetState(() => currentDuration = 0);
                    Navigator.pop(bCtx);
                    await chatService.setDisappearingMessages(
                      chatId: widget.chat.id,
                      durationInSeconds: 0,
                    );
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Pesan sementara dinonaktifkan')),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _handleMenuAction(BuildContext context, String action, String title, String? otherUid, [bool isBlocked = false]) {
    final auth = context.read<AuthService>();
    final chatService = context.read<ChatService>();
    final currentUid = auth.currentUid ?? '';
    final avatar = otherUid != null ? widget.chat.getDisplayAvatar(currentUid) : null;
    switch (action) {
      case 'block':
        if (otherUid != null) {
          _showBlockConfirmDialog(context, chatService, currentUid, otherUid, title);
        }
        break;
      case 'unblock':
        if (otherUid != null) {
          _showUnblockConfirmDialog(context, chatService, currentUid, otherUid, title);
        }
        break;
      case 'contact_info':
        _openContactInfo(context, title, avatar);
        break;
      case 'media':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MediaGalleryScreen(chatId: widget.chat.id, title: title),
          ),
        );
        break;
      case 'search':
        setState(() => _isSearching = true);
        break;
      case 'mute':
        _showMuteChatDialog(context, chatService, currentUid);
        break;
      case 'disappearing':
        _showDisappearingMessagesPicker(context, chatService);
        break;
      case 'wallpaper':
        _showChatWallpaperPicker(context);
        break;
      case 'clear':
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: WhatsAppTheme.darkSurface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(
              children: [
                Icon(Icons.delete_sweep_rounded, color: Colors.redAccent),
                SizedBox(width: 8),
                Text('Bersihkan Obrolan Ini?'),
              ],
            ),
            content: const Text(
              'Seluruh riwayat pesan di obrolan ini akan dihapus dari perangkat Anda. Pesan pada lawan bicara Anda tidak akan terpengaruh.',
              style: TextStyle(color: WhatsAppTheme.darkTextSecondary, fontSize: 13.5, height: 1.35),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Batal', style: TextStyle(color: WhatsAppTheme.darkTextSecondary)),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () async {
                  Navigator.pop(ctx);
                  try {
                    await context.read<ChatService>().clearChat(
                          widget.chat.id,
                          userId: currentUid,
                        );
                    if (mounted) {
                      showPremiumNotificationToast(
                        context,
                        title: 'Obrolan Dibersihkan',
                        message: 'Semua pesan dalam percakapan ini telah dibersihkan dari perangkat Anda.',
                        icon: Icons.check_circle_rounded,
                        accentColor: WhatsAppTheme.primaryTeal,
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      showPremiumNotificationToast(
                        context,
                        title: 'Gagal Membersihkan',
                        message: e.toString().replaceAll('Exception: ', ''),
                        icon: Icons.error_outline_rounded,
                        accentColor: Colors.redAccent,
                      );
                    }
                  }
                },
                child: const Text('Bersihkan'),
              ),
            ],
          ),
        );
        break;
    }
  }

  void _showEmojiPickerBottomSheet(BuildContext context) {
    final emojis = [
      '😀', '😃', '😄', '😁', '😆', '😅', '😂', '🤣', '😊', '😇',
      '🙂', '🙃', '😉', '😌', '😍', '🥰', '😘', '😗', '😙', '😚',
      '😋', '😛', '😜', '🤪', '😝', '🤑', '🤗', '🤭', '🤫', '🤔',
      '🤐', '🤨', '😐', '😑', '😶', '😏', '😒', '🙄', '😬', '🤥',
      '😌', '😔', '😪', '🤤', '😴', '😷', '🤒', '🤕', '🤢', '🤮',
      '🤧', '🥵', '🥶', '🥴', '😵', '🤯', '🤠', '🥳', '😎', '🤓',
      '🧐', '😕', '😟', '🙁', '😮', '😯', '😲', '😳', '🥺', '😦',
      '👍', '👎', '👌', '✌️', '🤞', '🤟', '🤘', '🤙', '👈', '👉',
      '👆', '🖕', '👇', '☝️', '✋', '🤚', '🖐', '🖖', '👋', '🤙',
      '❤️', '🧡', '💛', '💚', '💙', '💜', '🖤', '🤍', '🤎', '💔',
      '🔥', '✨', '🎉', '💯', '👏', '🙏', '💪', '🚀', '🎯', '⭐'
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: WhatsAppTheme.darkSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Container(
          height: 280,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('Emojis', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.backspace_outlined, size: 20),
                    onPressed: () {
                      final text = _textController.text;
                      if (text.isNotEmpty) {
                        _textController.text = text.characters.skipLast(1).toString();
                        _onTextChanged(_textController.text);
                      }
                    },
                  ),
                ],
              ),
              const Divider(height: 12),
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: emojis.length,
                  itemBuilder: (context, idx) {
                    final em = emojis[idx];
                    return InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () {
                        HapticFeedback.selectionClick();
                        _textController.text += em;
                        _onTextChanged(_textController.text);
                      },
                      child: Center(
                        child: Text(em, style: const TextStyle(fontSize: 24)),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _openPollCreator(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PollCreatorDialog(
          onCreated: (question, options) async {
            final auth = context.read<AuthService>();
            final chatService = context.read<ChatService>();
            final user = auth.appUser;
            if (user == null) return;

            await chatService.sendMessage(
              chatId: widget.chat.id,
              senderId: user.uid,
              senderName: user.displayName,
              text: question,
              type: MessageType.poll,
              pollQuestion: question,
              pollOptions: options,
            );
          },
        ),
      ),
    );
  }

  // 7-Grid WhatsApp Attachment Sheet
  void _showAttachmentBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: WhatsAppTheme.darkSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: Colors.grey.shade600,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _attachmentItem(
                    icon: Icons.insert_drive_file_rounded,
                    label: 'Document',
                    color: WhatsAppTheme.attachDocument,
                    onTap: () {
                      Navigator.pop(ctx);
                      _pickAndSendAnyFile(documentOnly: true);
                    },
                  ),
                  _attachmentItem(
                    icon: Icons.camera_alt_rounded,
                    label: 'Camera',
                    color: WhatsAppTheme.attachCamera,
                    onTap: () {
                      Navigator.pop(ctx);
                      _pickAndSendImage(fromCamera: true);
                    },
                  ),
                  _attachmentItem(
                    icon: Icons.photo_library_rounded,
                    label: 'Gallery',
                    color: WhatsAppTheme.attachGallery,
                    onTap: () {
                      Navigator.pop(ctx);
                      _pickAndSendImage(fromCamera: false);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _attachmentItem(
                    icon: Icons.videocam_rounded,
                    label: 'Video',
                    color: const Color(0xFFE542A3),
                    onTap: () {
                      Navigator.pop(ctx);
                      _pickAndSendVideo(fromCamera: false);
                    },
                  ),
                  _attachmentItem(
                    icon: Icons.headphones_rounded,
                    label: 'Audio',
                    color: WhatsAppTheme.attachAudio,
                    onTap: () {
                      Navigator.pop(ctx);
                      _pickAndSendAudioFile();
                    },
                  ),
                  _attachmentItem(
                    icon: Icons.location_on_rounded,
                    label: 'Location',
                    color: WhatsAppTheme.attachLocation,
                    onTap: () async {
                      Navigator.pop(ctx);
                      final auth = context.read<AuthService>();
                      final chatService = context.read<ChatService>();
                      final user = auth.appUser;
                      if (user == null) return;
                      await chatService.sendMessage(
                        chatId: widget.chat.id,
                        senderId: user.uid,
                        senderName: user.displayName,
                        text: '📍 Live Location shared',
                        type: MessageType.text,
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _attachmentItem(
                    icon: Icons.person_rounded,
                    label: 'Contact',
                    color: WhatsAppTheme.attachContact,
                    onTap: () async {
                      Navigator.pop(ctx);
                      final auth = context.read<AuthService>();
                      final chatService = context.read<ChatService>();
                      final user = auth.appUser;
                      if (user == null) return;
                      await chatService.sendMessage(
                        chatId: widget.chat.id,
                        senderId: user.uid,
                        senderName: user.displayName,
                        text: '👤 Contact Card: Support RenChat',
                        type: MessageType.text,
                      );
                    },
                  ),
                  _attachmentItem(
                    icon: Icons.poll_rounded,
                    label: 'Poll',
                    color: WhatsAppTheme.attachPoll,
                    onTap: () {
                      Navigator.pop(ctx);
                      _openPollCreator(context);
                    },
                  ),
                  const SizedBox(width: 75), // Spacer agar grid tetap simetris
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _attachmentItem({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: 75,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: color,
              child: Icon(icon, color: Colors.white, size: 26),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: WhatsAppTheme.darkTextSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final chatService = context.read<ChatService>();
    final currentUser = auth.appUser;
    if (currentUser == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final otherUid = widget.chat.getOtherUserId(currentUser.uid);
    final title = widget.chat.getDisplayTitle(currentUser.uid);

    return Scaffold(
      backgroundColor: WhatsAppTheme.darkChatBg,
      appBar: AppBar(
        titleSpacing: 0,
        leading: _isSearching
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  setState(() {
                    _isSearching = false;
                    _searchQuery = '';
                    _searchController.clear();
                  });
                },
              )
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
              ),
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(color: Colors.white, fontSize: 16),
                decoration: const InputDecoration(
                  hintText: 'Search...',
                  hintStyle: TextStyle(color: WhatsAppTheme.darkTextSecondary),
                  border: InputBorder.none,
                ),
                onChanged: (val) {
                  setState(() => _searchQuery = val.trim().toLowerCase());
                },
              )
            : Row(
                children: [
                  GestureDetector(
                    onTap: () => _openContactInfo(context, title, otherUid != null ? widget.chat.getDisplayAvatar(currentUser.uid) : null),
                    child: widget.chat.isGroup
                        ? const CircleAvatar(
                            radius: 19,
                            backgroundColor: Color(0xFF233138),
                            child: Icon(Icons.group_rounded, size: 22, color: Colors.white70),
                          )
                        : otherUid != null
                            ? StreamBuilder<AppUser?>(
                                stream: _otherUserStream ?? chatService.streamUserProfile(otherUid),
                                builder: (context, snap) {
                                  return UserAvatar(
                                    name: title,
                                    photoUrl: snap.data?.photoURL ?? widget.chat.getDisplayAvatar(currentUser.uid),
                                    radius: 19,
                                    showOnlineBadge: true,
                                    isOnline: snap.data?.online ?? false,
                                  );
                                },
                              )
                            : UserAvatar(
                                name: title,
                                photoUrl: widget.chat.getDisplayAvatar(currentUser.uid),
                                radius: 19,
                              ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _openContactInfo(context, title, otherUid != null ? widget.chat.getDisplayAvatar(currentUser.uid) : null),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          if (widget.chat.isGroup)
                            Text(
                              '${widget.chat.participants.length} members',
                              style: const TextStyle(fontSize: 12, color: WhatsAppTheme.darkTextSecondary),
                            )
                          else if (otherUid != null)
                            StreamBuilder<AppUser?>(
                              stream: _otherUserStream ?? chatService.streamUserProfile(otherUid),
                              builder: (context, snap) {
                                final u = snap.data;
                                if (u == null) return const SizedBox.shrink();
                                if (u.online) {
                                  return const Text(
                                    'online',
                                    style: TextStyle(fontSize: 12, color: WhatsAppTheme.primaryTeal),
                                  );
                                }
                                return Text(
                                  'last seen ${DateFormat.jm().format(u.lastSeen)}',
                                  style: const TextStyle(fontSize: 12, color: WhatsAppTheme.darkTextSecondary),
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
        actions: _isSearching
            ? [
                if (_searchQuery.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                  ),
              ]
            : [
                IconButton(
                  icon: const Icon(Icons.videocam_rounded),
                  tooltip: 'Video call',
                  onPressed: () {
                    if (otherUid != null && currentUser.isBlocked(otherUid)) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Unblock $title to place a call')),
                      );
                      return;
                    }
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CallScreen(
                          callerName: title,
                          callerAvatar: otherUid != null ? widget.chat.getDisplayAvatar(currentUser.uid) : null,
                          isVideo: true,
                          receiverId: otherUid,
                        ),
                      ),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.call_rounded),
                  tooltip: 'Voice call',
                  onPressed: () {
                    if (otherUid != null && currentUser.isBlocked(otherUid)) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Unblock $title to place a call')),
                      );
                      return;
                    }
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CallScreen(
                          callerName: title,
                          callerAvatar: otherUid != null ? widget.chat.getDisplayAvatar(currentUser.uid) : null,
                          isVideo: false,
                          receiverId: otherUid,
                        ),
                      ),
                    );
                  },
                ),
                StreamBuilder<bool>(
                  stream: _isBlockedStream ?? (otherUid != null
                      ? chatService.streamIsUserBlocked(currentUserId: currentUser.uid, targetUserId: otherUid)
                      : Stream.value(false)),
                  builder: (context, blockSnap) {
                    final isBlocked = blockSnap.data ?? (otherUid != null && currentUser.isBlocked(otherUid));
                    return PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert_rounded),
                      onSelected: (val) => _handleMenuAction(context, val, title, otherUid, isBlocked),
                      itemBuilder: (context) => [
                        const PopupMenuItem(value: 'contact_info', child: Text('Lihat kontak')),
                        const PopupMenuItem(value: 'media', child: Text('Media, tautan, & dokumen')),
                        const PopupMenuItem(value: 'search', child: Text('Cari pesan')),
                        const PopupMenuItem(value: 'mute', child: Text('Bisukan notifikasi')),
                        const PopupMenuItem(value: 'disappearing', child: Text('Pesan sementara')),
                        const PopupMenuItem(value: 'wallpaper', child: Text('Wallpaper obrolan')),
                        const PopupMenuItem(value: 'clear', child: Text('Bersihkan obrolan')),
                        if (!widget.chat.isGroup && otherUid != null)
                          PopupMenuItem(
                            value: isBlocked ? 'unblock' : 'block',
                            child: Text(
                              isBlocked ? 'Buka blokir' : 'Blokir kontak',
                              style: TextStyle(color: isBlocked ? WhatsAppTheme.primaryTeal : Colors.redAccent),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ],
      ),
      body: Builder(
        builder: (context) {
          final settings = context.watch<SettingsService>();
          final customWallpaperPath = settings.customWallpaperPath;
          final hasCustomPhoto = customWallpaperPath != null &&
              File(customWallpaperPath).existsSync() &&
              settings.chatWallpaper == 'Custom Photo';

          return Container(
            decoration: BoxDecoration(
              color: settings.wallpaperColor,
              image: hasCustomPhoto
                  ? DecorationImage(
                      image: FileImage(File(customWallpaperPath)),
                      fit: BoxFit.cover,
                      colorFilter: ColorFilter.mode(
                        Colors.black.withValues(alpha: 0.35),
                        BlendMode.darken,
                      ),
                    )
                  : null,
            ),
            child: Column(
          children: [
            // Typing indicator bubble (animated)
            StreamBuilder<List<String>>(
              stream: _typingStream ?? chatService.streamTypingUsers(widget.chat.id, currentUser.uid),
              builder: (context, snap) {
                final typers = snap.data ?? [];
                if (typers.isEmpty) return const SizedBox.shrink();
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  color: WhatsAppTheme.darkChatBg,
                  width: double.infinity,
                  child: Row(
                    children: [
                      const TypingIndicatorBubble(),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          '${typers.join(', ')} sedang mengetik...',
                          style: const TextStyle(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            color: WhatsAppTheme.primaryTeal,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            // Messages list with WhatsApp E2EE banner at top
            Expanded(
              child: StreamBuilder<Chat?>(
                stream: _chatStream ?? chatService.streamChat(widget.chat.id),
                builder: (context, chatSnap) {
                  final currentChat = chatSnap.data ?? widget.chat;
                  final clearedTime = currentChat.getClearedAt(currentUser.uid);

                  return StreamBuilder<List<Message>>(
                    stream: _messagesStream ?? chatService.streamMessages(widget.chat.id),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      var allMessages = snapshot.data ?? [];
                      // Saring pesan berdasarkan waktu clearedAt milik pengguna (model WhatsApp)
                      if (clearedTime != null) {
                        allMessages = allMessages
                            .where((m) => m.createdAt.isAfter(clearedTime))
                            .toList();
                      }

                      final messages = _searchQuery.isEmpty
                          ? allMessages
                          : allMessages
                              .where((m) =>
                                  m.text.toLowerCase().contains(_searchQuery) ||
                                  (m.fileName?.toLowerCase().contains(_searchQuery) ?? false))
                              .toList();

                      // Deteksi pesan baru: scroll ke bawah hanya jika pengguna
                      // sedang berada di posisi teratas (tidak sedang membaca riwayat lama).
                      if (messages.length > _lastMessageCount) {
                        final wasAtBottom = !_showScrollToBottom;
                        _lastMessageCount = messages.length;
                        if (wasAtBottom) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted) _scrollToLatest();
                          });
                        }
                      } else if (messages.length < _lastMessageCount) {
                        _lastMessageCount = messages.length;
                      }

                      return Stack(
                        children: [
                          ListView.builder(
                            reverse: true,
                            controller: _scrollController,
                            physics: const AlwaysScrollableScrollPhysics(
                              parent: BouncingScrollPhysics(),
                            ),
                            cacheExtent: 600,
                            padding: EdgeInsets.fromLTRB(
                              10,
                              8,
                              10,
                              (currentChat.pinnedMessageId != null ? 58.0 : 8.0),
                            ),
                            itemCount: messages.length + 1, // +1 for E2EE Banner
                            itemBuilder: (context, index) {
                              if (index == messages.length) {
                                return _buildE2EEBanner();
                              }
                              final msg = messages[index];
                              final isMe = msg.senderId == currentUser.uid;
                              return Dismissible(
                                key: ValueKey('swipe_${msg.id}'),
                                direction: DismissDirection.startToEnd,
                                confirmDismiss: (direction) async {
                                  // Swipe to reply action
                                  HapticFeedback.selectionClick();
                                  setState(() {
                                    _replyingToMessage = msg;
                                  });
                                  return false; // don't delete
                                },
                                background: Container(
                                  alignment: Alignment.centerLeft,
                                  padding: const EdgeInsets.only(left: 20),
                                  child: const Icon(Icons.reply_rounded, color: WhatsAppTheme.primaryTeal, size: 28),
                                ),
                                child: _WhatsAppMessageBubble(
                                  message: msg,
                                  isMe: isMe,
                                  isGroup: widget.chat.isGroup,
                                  currentUserId: currentUser.uid,
                                  chatId: widget.chat.id,
                                  pinnedMessageId: currentChat.pinnedMessageId,
                                  onReply: () {
                                    setState(() {
                                      _replyingToMessage = msg;
                                    });
                                  },
                                ),
                              );
                            },
                          ),
                          // Pinned Message WhatsApp Top Banner
                          if (currentChat.pinnedMessageId != null)
                            Positioned(
                              top: 8,
                              left: 12,
                              right: 12,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: WhatsAppTheme.darkSurface.withValues(alpha: 0.94),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: WhatsAppTheme.primaryTeal.withValues(alpha: 0.35),
                                    width: 1,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: WhatsAppTheme.primaryTeal.withValues(alpha: 0.18),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(
                                        Icons.push_pin_rounded,
                                        size: 18,
                                        color: WhatsAppTheme.primaryTeal,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Row(
                                            children: [
                                              const Text(
                                                'Pesan Disematkan',
                                                style: TextStyle(
                                                  fontSize: 11.5,
                                                  fontWeight: FontWeight.bold,
                                                  color: WhatsAppTheme.primaryTeal,
                                                ),
                                              ),
                                              if (currentChat.pinnedMessageSenderName != null) ...[
                                                const SizedBox(width: 4),
                                                Text(
                                                  '• ${currentChat.pinnedMessageSenderName}',
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    color: WhatsAppTheme.darkTextSecondary,
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            currentChat.pinnedMessageText ?? 'Pesan',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              color: Colors.white,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.close_rounded, size: 18, color: WhatsAppTheme.darkTextSecondary),
                                      tooltip: 'Lepas Sematan',
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                      onPressed: () async {
                                        await chatService.unpinMessageInChat(widget.chat.id);
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text('Pesan dilepas dari sematan')),
                                          );
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          // Tombol scroll ke pesan terbaru
                          Positioned(
                            right: 12,
                            bottom: 12,
                            child: AnimatedSlide(
                              offset: _showScrollToBottom ? Offset.zero : const Offset(0, 1.6),
                              duration: const Duration(milliseconds: 220),
                              curve: Curves.easeOutCubic,
                              child: AnimatedOpacity(
                                opacity: _showScrollToBottom ? 1 : 0,
                                duration: const Duration(milliseconds: 220),
                                child: IgnorePointer(
                                  ignoring: !_showScrollToBottom,
                                  child: FloatingActionButton.small(
                                    heroTag: 'scroll_to_bottom',
                                    backgroundColor: WhatsAppTheme.darkSurface,
                                    foregroundColor: WhatsAppTheme.primaryTeal,
                                    elevation: 3,
                                    onPressed: () {
                                      HapticFeedback.selectionClick();
                                      _scrollToLatest();
                                    },
                                    child: const Icon(Icons.keyboard_double_arrow_down_rounded),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
            // Upload status banner
            if (_isUploading)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: WhatsAppTheme.darkSurface,
                width: double.infinity,
                child: Row(
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: WhatsAppTheme.primaryTeal,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _uploadStatus,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: WhatsAppTheme.darkTextPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            // WhatsApp Quoted Message Preview Bar (Swipe to reply)
            if (_replyingToMessage != null) _buildQuotedMessagePreviewBar(),
            // WhatsApp Compose Bar or Blocked Notice
            if (!widget.chat.isGroup && otherUid != null)
              StreamBuilder<bool>(
                stream: _isBlockedStream ?? chatService.streamIsUserBlocked(currentUserId: currentUser.uid, targetUserId: otherUid),
                builder: (context, blockSnap) {
                  final isBlocked = blockSnap.data ?? currentUser.isBlocked(otherUid);
                  if (isBlocked) {
                    return SafeArea(
                      child: Container(
                        width: double.infinity,
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: WhatsAppTheme.darkSurface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
                        ),
                        child: InkWell(
                          onTap: () => _showUnblockConfirmDialog(context, chatService, currentUser.uid, otherUid, title),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.block_rounded, size: 18, color: Colors.redAccent),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'You blocked this contact. Tap to unblock.',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: WhatsAppTheme.darkTextPrimary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }
                  return _buildWhatsAppComposeBar(context);
                },
              )
            else
              _buildWhatsAppComposeBar(context),
          ],
        ),
          );
        },
      ),
    );
  }

  Future<void> _showBlockConfirmDialog(BuildContext context, ChatService chatService, String currentUid, String otherUid, String contactName) async {
    final confirmed = await showPremiumActionConfirmDialog(
      context,
      title: 'Blokir $contactName?',
      message: 'Kontak yang diblokir tidak akan dapat mengirim pesan atau melakukan panggilan ke akun Anda.',
      confirmLabel: 'Blokir',
      icon: Icons.block_rounded,
      accentColor: const Color(0xFFEF4444),
      isDestructive: true,
    );

    if (confirmed == true) {
      await chatService.blockUser(currentUserId: currentUid, targetUserId: otherUid);
      if (context.mounted) {
        showPremiumNotificationToast(
          context,
          title: 'Kontak Diblokir',
          message: '$contactName telah berhasil diblokir dari daftar obrolan Anda.',
          icon: Icons.block_rounded,
          accentColor: const Color(0xFFEF4444),
        );
      }
    }
  }

  Future<void> _showUnblockConfirmDialog(BuildContext context, ChatService chatService, String currentUid, String otherUid, String contactName) async {
    final confirmed = await showPremiumActionConfirmDialog(
      context,
      title: 'Buka Blokir $contactName?',
      message: 'Buka blokir kontak ini untuk mulai berkirim pesan dan melakukan panggilan suara/video kembali.',
      confirmLabel: 'Buka Blokir',
      icon: Icons.lock_open_rounded,
      accentColor: WhatsAppTheme.primaryTeal,
      isDestructive: false,
    );

    if (confirmed == true) {
      await chatService.unblockUser(currentUserId: currentUid, targetUserId: otherUid);
      if (context.mounted) {
        showPremiumNotificationToast(
          context,
          title: 'Blokir Dibuka',
          message: 'Anda sekarang dapat mengirim pesan dan memanggil $contactName.',
          icon: Icons.check_circle_rounded,
          accentColor: WhatsAppTheme.primaryTeal,
        );
      }
    }
  }

  Widget _buildQuotedMessagePreviewBar() {
    final msg = _replyingToMessage!;
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 0, 10, 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: WhatsAppTheme.darkSurface,
        borderRadius: BorderRadius.circular(16),
        border: const Border(
          left: BorderSide(color: WhatsAppTheme.primaryTeal, width: 4.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.reply_rounded, color: WhatsAppTheme.primaryTeal, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  msg.senderName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: WhatsAppTheme.primaryTeal,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _getReplyPreviewText(msg),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    color: WhatsAppTheme.darkTextSecondary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 20, color: WhatsAppTheme.darkTextSecondary),
            onPressed: () {
              setState(() {
                _replyingToMessage = null;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildE2EEBanner() {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF182229),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF222E35), width: 0.5),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_rounded, size: 14, color: WhatsAppTheme.e2eeYellow),
            SizedBox(width: 8),
            Flexible(
              child: Text(
                'Messages and calls are end-to-end encrypted. No one outside of this chat, not even RenChat, can read or listen to them.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  color: WhatsAppTheme.e2eeYellow,
                  height: 1.3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWhatsAppComposeBar(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: WhatsAppTheme.darkSurface,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.28),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: _isRecordingVoice
                    ? Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        child: Row(
                          children: [
                            // Tombol Hapus (Tong Sampah)
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 24),
                              tooltip: 'Batalkan Rekaman',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                              onPressed: _cancelRecording,
                            ),
                            const SizedBox(width: 8),
                            // Indikator Durasi & Status
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _isRecordingPaused ? Icons.pause_circle_filled_rounded : Icons.fiber_manual_record,
                                  color: _isRecordingPaused ? Colors.amber : Colors.red,
                                  size: 16,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '0:${_recordDurationSeconds.toString().padLeft(2, '0')}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),
                            const Spacer(),
                            // Tombol Jeda (Pause) atau Dengarkan Ulang (Preview Play/Pause)
                            if (!_isRecordingPaused) ...[
                              IconButton(
                                icon: const Icon(Icons.pause_circle_outline_rounded, color: Colors.amber, size: 28),
                                tooltip: 'Jeda & Dengarkan Ulang',
                                onPressed: _pauseRecording,
                              ),
                            ] else ...[
                              IconButton(
                                icon: Icon(
                                  _isPreviewPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded,
                                  color: WhatsAppTheme.primaryTeal,
                                  size: 32,
                                ),
                                tooltip: _isPreviewPlaying ? 'Jeda Pratinjau' : 'Dengarkan Ulang Rekaman',
                                onPressed: _togglePreviewPlayback,
                              ),
                            ],
                          ],
                        ),
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.emoji_emotions_outlined, color: WhatsAppTheme.darkTextSecondary),
                            onPressed: () => _showEmojiPickerBottomSheet(context),
                            tooltip: 'Emoji',
                          ),
                          Expanded(
                            child: TextField(
                              controller: _textController,
                              onChanged: _onTextChanged,
                              textCapitalization: TextCapitalization.sentences,
                              maxLines: 5,
                              minLines: 1,
                              style: const TextStyle(fontSize: 16, color: WhatsAppTheme.darkTextPrimary),
                              decoration: const InputDecoration(
                                hintText: 'Message',
                                hintStyle: TextStyle(color: WhatsAppTheme.darkTextSecondary, fontSize: 16),
                                contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 12),
                                border: InputBorder.none,
                              ),
                              onSubmitted: (_) => _sendMessage(),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.attach_file_rounded, color: WhatsAppTheme.darkTextSecondary),
                            onPressed: () => _showAttachmentBottomSheet(context),
                            tooltip: 'Attach',
                          ),
                          if (!_hasInputText)
                            IconButton(
                              icon: const Icon(Icons.camera_alt_rounded, color: WhatsAppTheme.darkTextSecondary),
                              onPressed: () => _pickAndSendImage(fromCamera: true),
                              tooltip: 'Camera',
                            ),
                        ],
                      ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: (_isRecordingVoice ? Colors.red : WhatsAppTheme.primaryTeal).withValues(alpha: 0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: CircleAvatar(
                radius: 25,
                backgroundColor: _isRecordingVoice ? Colors.red : WhatsAppTheme.primaryTeal,
                child: _isSending
                    ? const Padding(
                        padding: EdgeInsets.all(14),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                      )
                    : IconButton(
                        icon: Icon(
                          _hasInputText
                              ? Icons.send_rounded
                              : (_isRecordingVoice ? Icons.stop_rounded : Icons.mic_rounded),
                          color: Colors.white,
                          size: 23,
                        ),
                        onPressed: _hasInputText
                            ? _sendMessage
                            : (_isRecordingVoice ? _stopAndSendRecording : _startRecording),
                        tooltip: _hasInputText
                            ? 'Send'
                            : (_isRecordingVoice ? 'Send Voice Note' : 'Record Voice Note'),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WhatsAppMessageBubble extends StatelessWidget {
  final Message message;
  final bool isMe;
  final bool isGroup;
  final String currentUserId;
  final String chatId;
  final VoidCallback onReply;
  final String? pinnedMessageId;

  const _WhatsAppMessageBubble({
    required this.message,
    required this.isMe,
    required this.isGroup,
    required this.currentUserId,
    required this.chatId,
    required this.onReply,
    this.pinnedMessageId,
  });

  void _showReactionPicker(BuildContext context) {
    final emojis = ['👍', '❤️', '😂', '😮', '😢', '🙏'];
    showModalBottomSheet(
      context: context,
      backgroundColor: WhatsAppTheme.darkSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: emojis.map((emoji) {
                return InkWell(
                  onTap: () {
                    Navigator.pop(ctx);
                    HapticFeedback.selectionClick();
                    context.read<ChatService>().toggleReaction(
                          chatId: chatId,
                          messageId: message.id,
                          userId: currentUserId,
                          emoji: emoji,
                        );
                  },
                  borderRadius: BorderRadius.circular(24),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(emoji, style: const TextStyle(fontSize: 32)),
                  ),
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  /// Double-tap pesan memberi reaksi cepat hati, seperti di WhatsApp.
  void _handleDoubleTap(BuildContext context, Offset globalPosition) {
    HapticFeedback.mediumImpact();

    // Double-tap hanya menambah reaksi, tidak menghapus reaksi yang sudah ada.
    if (message.reactions[currentUserId] != '❤️') {
      context.read<ChatService>().toggleReaction(
            chatId: chatId,
            messageId: message.id,
            userId: currentUserId,
            emoji: '❤️',
          );
    }

    showHeartBurst(context, globalPosition);
  }

  /// Ketuk badge reaksi untuk menambahkan/melepas reaksi yang sama.
  void _toggleBadgeReaction(BuildContext context, String emoji) {
    HapticFeedback.selectionClick();
    context.read<ChatService>().toggleReaction(
          chatId: chatId,
          messageId: message.id,
          userId: currentUserId,
          emoji: emoji,
        );
  }

  void _showOptions(BuildContext context) {
    final isStarred = message.isStarredBy(currentUserId);
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      backgroundColor: WhatsAppTheme.darkSurface,
      builder: (ctx) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.reply_rounded),
                title: const Text('Reply'),
                onTap: () {
                  Navigator.pop(ctx);
                  onReply();
                },
              ),
              if (!message.deleted) ...[
                ListTile(
                  leading: const Icon(Icons.forward_rounded, color: WhatsAppTheme.primaryTeal),
                  title: const Text('Teruskan'),
                  subtitle: const Text('Kirim pesan ini ke chat lain', style: TextStyle(fontSize: 12, color: WhatsAppTheme.darkTextSecondary)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showForwardDialog(context);
                  },
                ),
              ],
              ListTile(
                leading: const Icon(Icons.add_reaction_outlined),
                title: const Text('Add Reaction'),
                onTap: () {
                  Navigator.pop(ctx);
                  _showReactionPicker(context);
                },
              ),
              ListTile(
                leading: Icon(
                  isStarred ? Icons.star_rounded : Icons.star_outline_rounded,
                  color: isStarred ? Colors.amber : null,
                ),
                title: Text(isStarred ? 'Unstar' : 'Star'),
                onTap: () {
                  Navigator.pop(ctx);
                  context.read<ChatService>().toggleStarMessage(
                        chatId: chatId,
                        messageId: message.id,
                        userId: currentUserId,
                      );
                },
              ),
              if (!message.deleted) ...[
                ListTile(
                  leading: Icon(
                    pinnedMessageId == message.id ? Icons.push_pin_outlined : Icons.push_pin_rounded,
                    color: pinnedMessageId == message.id ? Colors.amber : WhatsAppTheme.primaryTeal,
                  ),
                  title: Text(pinnedMessageId == message.id ? 'Lepas Sematan (Unpin)' : 'Sematkan Pesan (Pin)'),
                  subtitle: Text(
                    pinnedMessageId == message.id
                        ? 'Hapus pesan ini dari bagian atas chat'
                        : 'Tempelkan pesan ini di bagian atas chat',
                    style: const TextStyle(fontSize: 12, color: WhatsAppTheme.darkTextSecondary),
                  ),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final cs = context.read<ChatService>();
                    if (pinnedMessageId == message.id) {
                      await cs.unpinMessageInChat(chatId);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Pesan dilepas dari sematan')),
                        );
                      }
                    } else {
                      final textPreview = message.type == MessageType.image
                          ? '📷 Foto'
                          : message.type == MessageType.file
                              ? '📎 ${message.fileName ?? "Dokumen"}'
                              : message.type == MessageType.voice
                                  ? '🎤 Pesan Suara'
                                  : message.text;
                      await cs.pinMessageInChat(
                        chatId: chatId,
                        messageId: message.id,
                        text: textPreview,
                        senderName: message.senderName,
                      );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Row(
                              children: [
                                Icon(Icons.push_pin_rounded, color: Colors.white, size: 18),
                                SizedBox(width: 8),
                                Text('Pesan berhasil disematkan di atas'),
                              ],
                            ),
                            backgroundColor: WhatsAppTheme.primaryTeal,
                          ),
                        );
                      }
                    }
                  },
                ),
              ],
              if (!message.deleted && message.type == MessageType.text) ...[
                ListTile(
                  leading: const Icon(Icons.copy_rounded),
                  title: const Text('Copy'),
                  onTap: () {
                    Navigator.pop(ctx);
                    Clipboard.setData(ClipboardData(text: message.text));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Pesan disalin'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.translate_rounded, color: WhatsAppTheme.primaryTeal),
                  title: const Text('Terjemahkan Pesan'),
                  subtitle: const Text('Deteksi dan terjemahkan otomatis', style: TextStyle(fontSize: 12, color: WhatsAppTheme.darkTextSecondary)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showTranslateMessageDialog(context, message.text);
                  },
                ),
              ],
              if (isMe && !message.deleted && message.type == MessageType.text)
                ListTile(
                  leading: const Icon(Icons.edit_outlined),
                  title: const Text('Edit'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showEditDialog(context);
                  },
                ),
              if (isMe && !message.deleted)
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.red),
                  title: const Text('Delete for everyone', style: TextStyle(color: Colors.red)),
                  onTap: () {
                    Navigator.pop(ctx);
                    context.read<ChatService>().deleteMessage(
                          chatId: chatId,
                          messageId: message.id,
                        );
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  void _showTranslateMessageDialog(BuildContext context, String originalText) {
    showModalBottomSheet(
      context: context,
      backgroundColor: WhatsAppTheme.darkSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Row(
                children: [
                  Icon(Icons.translate_rounded, color: WhatsAppTheme.primaryTeal, size: 24),
                  SizedBox(width: 10),
                  Text(
                    'Terjemahan Pesan',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Text(
                'Teks Asli:',
                style: TextStyle(fontSize: 12, color: WhatsAppTheme.darkTextSecondary, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF111B21),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white10),
                ),
                child: Text(
                  originalText,
                  style: const TextStyle(fontSize: 14, color: Colors.white70),
                ),
              ),
              const SizedBox(height: 14),
              const Row(
                children: [
                  Icon(Icons.auto_awesome_rounded, color: WhatsAppTheme.primaryTeal, size: 16),
                  SizedBox(width: 6),
                  Text(
                    'Terjemahan (Bahasa Indonesia):',
                    style: TextStyle(fontSize: 12, color: WhatsAppTheme.primaryTeal, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: WhatsAppTheme.primaryTeal.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: WhatsAppTheme.primaryTeal.withValues(alpha: 0.3)),
                ),
                child: Text(
                  originalText,
                  style: const TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.w500),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    label: const Text('Salin Terjemahan'),
                    style: TextButton.styleFrom(foregroundColor: WhatsAppTheme.primaryTeal),
                    onPressed: () {
                      Navigator.pop(ctx);
                      Clipboard.setData(ClipboardData(text: originalText));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Terjemahan disalin ke papan klip')),
                      );
                    },
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: WhatsAppTheme.primaryTeal),
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Tutup'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showForwardDialog(BuildContext context) {
    final chatService = context.read<ChatService>();
    final auth = context.read<AuthService>();
    final currentUser = auth.appUser;
    if (currentUser == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: WhatsAppTheme.darkSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.92,
          expand: false,
          builder: (dCtx, scrollController) {
            return Column(
              children: [
                Container(
                  width: 38,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.forward_rounded, color: WhatsAppTheme.primaryTeal),
                      const SizedBox(width: 10),
                      const Text(
                        'Teruskan Pesan ke...',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: WhatsAppTheme.darkTextSecondary),
                        onPressed: () => Navigator.pop(sheetCtx),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: Color(0xFF2A3942)),
                Expanded(
                  child: StreamBuilder<List<Chat>>(
                    stream: chatService.streamUserChats(currentUser.uid),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator(color: WhatsAppTheme.primaryTeal));
                      }
                      final allChats = snapshot.data ?? [];
                      // Filter agar tidak meneruskan ke chat yang sama
                      final targetChats = allChats.where((c) => c.id != chatId).toList();

                      if (targetChats.isEmpty) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24.0),
                            child: Text(
                              'Belum ada obrolan lain untuk diteruskan.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: WhatsAppTheme.darkTextSecondary),
                            ),
                          ),
                        );
                      }

                      return ListView.separated(
                        controller: scrollController,
                        itemCount: targetChats.length,
                        separatorBuilder: (_, __) => const Divider(height: 1, indent: 72, color: Color(0xFF2A3942)),
                        itemBuilder: (context, index) {
                          final targetChat = targetChats[index];
                          final title = targetChat.isGroup
                              ? (targetChat.title ?? 'Grup')
                              : targetChat.otherParticipantName(currentUser.uid);
                          final avatar = targetChat.isGroup
                              ? targetChat.photoURL
                              : targetChat.otherParticipantAvatar(currentUser.uid);

                          return ListTile(
                            leading: UserAvatar(
                              name: title,
                              photoUrl: avatar,
                              radius: 22,
                            ),
                            title: Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
                            ),
                            subtitle: Text(
                              targetChat.isGroup ? 'Grup' : 'Kontak Pribadi',
                              style: const TextStyle(fontSize: 12, color: WhatsAppTheme.darkTextSecondary),
                            ),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                              decoration: BoxDecoration(
                                color: WhatsAppTheme.primaryTeal.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: WhatsAppTheme.primaryTeal.withValues(alpha: 0.4)),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.send_rounded, size: 14, color: WhatsAppTheme.primaryTeal),
                                  SizedBox(width: 4),
                                  Text(
                                    'Kirim',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: WhatsAppTheme.primaryTeal,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            onTap: () async {
                              Navigator.pop(sheetCtx);
                              try {
                                await chatService.sendMessage(
                                  chatId: targetChat.id,
                                  senderId: currentUser.uid,
                                  senderName: currentUser.displayName,
                                  text: message.text,
                                  type: message.type,
                                  mediaUrl: message.mediaUrl,
                                  fileName: message.fileName,
                                  fileSize: message.fileSize,
                                  durationSeconds: message.durationSeconds,
                                  pollQuestion: message.pollQuestion,
                                  pollOptions: message.pollOptions,
                                  isForwarded: true,
                                );
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Row(
                                        children: [
                                          const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                                          const SizedBox(width: 8),
                                          Expanded(child: Text('Pesan diteruskan ke $title')),
                                        ],
                                      ),
                                      backgroundColor: WhatsAppTheme.primaryTeal,
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Gagal meneruskan pesan: $e')),
                                  );
                                }
                              }
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showEditDialog(BuildContext context) {
    final controller = TextEditingController(text: message.text);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: WhatsAppTheme.darkSurface,
        title: const Text('Edit Message'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: WhatsAppTheme.primaryTeal),
            onPressed: () {
              final newText = controller.text.trim();
              if (newText.isNotEmpty && newText != message.text) {
                context.read<ChatService>().editMessage(
                      chatId: chatId,
                      messageId: message.id,
                      newText: newText,
                    );
              }
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bg = isMe ? WhatsAppTheme.darkBubbleOutgoing : WhatsAppTheme.darkBubbleIncoming;
    const fg = WhatsAppTheme.darkTextPrimary;
    final timeStr = DateFormat('h:mm a').format(message.createdAt);
    final isStarred = message.isStarredBy(currentUserId);

    // Posisi tap pertama pada double-tap, dipakai untuk menempatkan animasi hati.
    var doubleTapPosition = Offset.zero;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: () => _showOptions(context),
        onDoubleTapDown: (details) => doubleTapPosition = details.globalPosition,
        onDoubleTap: () => _handleDoubleTap(context, doubleTapPosition),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 2.5),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.78,
          ),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(12),
              topRight: const Radius.circular(12),
              bottomLeft: Radius.circular(isMe ? 12 : 2),
              bottomRight: Radius.circular(isMe ? 2 : 12),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          child: Column(
            crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              if (message.isForwarded) ...[
                const Padding(
                  padding: EdgeInsets.only(bottom: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.forward_rounded, size: 13, color: WhatsAppTheme.darkTextSecondary),
                      SizedBox(width: 4),
                      Text(
                        'Diteruskan',
                        style: TextStyle(
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                          fontWeight: FontWeight.w500,
                          color: WhatsAppTheme.darkTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (isGroup && !isMe) ...[
                Text(
                  message.senderName,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: WhatsAppTheme.accentGreen,
                  ),
                ),
                const SizedBox(height: 2),
              ],
              // Quoted message preview if this message replied to someone
              if (message.replyToText != null) ...[
                Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(8),
                    border: const Border(
                      left: BorderSide(color: WhatsAppTheme.primaryTeal, width: 3.5),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.reply_rounded, size: 12, color: WhatsAppTheme.primaryTeal),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              message.replyToSenderName ?? 'Reply',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: WhatsAppTheme.primaryTeal,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        message.replyToText!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, color: WhatsAppTheme.darkTextSecondary, height: 1.2),
                      ),
                    ],
                  ),
                ),
              ],
              if (message.deleted)
                Text(
                  '🚫 This message was deleted',
                  style: TextStyle(
                    fontStyle: FontStyle.italic,
                    color: fg.withValues(alpha: 0.6),
                  ),
                )
              else if (message.type == MessageType.poll) ...[
                _buildPollWidget(context),
              ] else if (message.type == MessageType.voice) ...[
                _buildVoiceNoteWidget(context),
              ] else if (message.isViewOnce) ...[
                _buildViewOnceWidget(context),
              ] else if (message.type == MessageType.image && message.mediaUrl != null) ...[
                GestureDetector(
                  onTap: () => _openMediaViewer(context, message.mediaUrl!, message.fileName ?? 'Photo'),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Stack(
                      children: [
                        UniversalImage(
                          imageUrl: message.mediaUrl!,
                          placeholder: Container(
                            height: 200,
                            width: 250,
                            color: Colors.black26,
                            child: const Center(
                              child: CircularProgressIndicator(color: WhatsAppTheme.primaryTeal),
                            ),
                          ),
                          errorWidget: Container(
                            height: 160,
                            width: 220,
                            color: Colors.black26,
                            child: const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.broken_image, size: 36, color: Colors.grey),
                                SizedBox(height: 6),
                                Text('Image preview unavailable', style: TextStyle(fontSize: 11, color: Colors.grey)),
                              ],
                            ),
                          ),
                          fit: BoxFit.cover,
                          width: 260,
                        ),
                        Positioned(
                          right: 8,
                          bottom: 8,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.6),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.fullscreen_rounded, color: Colors.white, size: 18),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (message.text.isNotEmpty && message.text != 'Photo' && message.text != message.fileName) ...[
                  const SizedBox(height: 6),
                  Text(message.text, style: const TextStyle(color: fg, fontSize: 15)),
                ],
              ] else if (message.type == MessageType.file) ...[
                InkWell(
                  onTap: () => _openFile(context),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 220, maxWidth: 300),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.28),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _getFileColor(message.fileName ?? '').withValues(alpha: 0.25),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: _getFileColor(message.fileName ?? '').withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            _getFileIcon(message.fileName ?? ''),
                            size: 28,
                            color: _getFileColor(message.fileName ?? ''),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                message.fileName ?? message.text,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13.5,
                                  color: fg,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Row(
                                children: [
                                  if (message.fileSize != null)
                                    Text(
                                      _formatFileSize(message.fileSize!),
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: WhatsAppTheme.darkTextSecondary,
                                      ),
                                    ),
                                  if (message.fileName != null && message.fileName!.contains('.')) ...[
                                    const SizedBox(width: 4),
                                    Text(
                                      '• ${message.fileName!.split('.').last.toUpperCase()}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: _getFileColor(message.fileName ?? ''),
                                      ),
                                    ),
                                  ],
                                  const SizedBox(width: 6),
                                  const Text(
                                    '• Ketuk untuk buka',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: WhatsAppTheme.primaryTeal,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: const Color(0xFF233138),
                          child: Icon(
                            Icons.download_rounded,
                            size: 16,
                            color: _getFileColor(message.fileName ?? ''),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ] else ...[
                Text(
                  message.text,
                  style: const TextStyle(fontSize: 15.5, color: fg, height: 1.25),
                ),
              ],
              const SizedBox(height: 3),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isStarred) ...[
                    const Icon(Icons.star_rounded, size: 13, color: Colors.amber),
                    const SizedBox(width: 4),
                  ],
                  if (message.editedAt != null && !message.deleted) ...[
                    const Text(
                      'edited ',
                      style: TextStyle(fontSize: 10, color: WhatsAppTheme.darkTextSecondary),
                    ),
                  ],
                  Text(
                    timeStr,
                    style: const TextStyle(fontSize: 10.5, color: WhatsAppTheme.darkTextSecondary),
                  ),
                  if (isMe) ...[
                    const SizedBox(width: 4),
                    _buildDeliveryStatusIcon(message),
                  ],
                ],
              ),
              if (message.reactions.isNotEmpty) ...[
                const SizedBox(height: 4),
                Wrap(
                  spacing: 4,
                  children: _buildReactionBadges(context),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // Interactive Poll Widget
  Widget _buildPollWidget(BuildContext context) {
    final options = message.pollOptions ?? [];
    final votes = message.pollVotes;
    int totalVotes = 0;
    votes.forEach((_, list) => totalVotes += list.length);

    return Container(
      width: 270,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.poll_rounded, color: WhatsAppTheme.primaryTeal, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message.pollQuestion ?? message.text,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...options.asMap().entries.map((entry) {
            final idx = entry.key;
            final opt = entry.value;
            final optVoters = votes[idx.toString()] ?? [];
            final count = optVoters.length;
            final hasVoted = optVoters.contains(currentUserId);
            final ratio = totalVotes > 0 ? (count / totalVotes) : 0.0;

            return InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                context.read<ChatService>().votePoll(
                      chatId: chatId,
                      messageId: message.id,
                      userId: currentUserId,
                      optionIndex: idx,
                    );
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: hasVoted
                      ? WhatsAppTheme.primaryTeal.withValues(alpha: 0.15)
                      : Colors.black.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: hasVoted ? WhatsAppTheme.primaryTeal : Colors.transparent,
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          hasVoted ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                          size: 18,
                          color: hasVoted ? WhatsAppTheme.primaryTeal : WhatsAppTheme.darkTextSecondary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            opt,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: hasVoted ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ),
                        Text(
                          '$count',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: ratio,
                        backgroundColor: Colors.white10,
                        color: hasVoted ? WhatsAppTheme.primaryTeal : Colors.white54,
                        minHeight: 4,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          Text(
            '$totalVotes votes • Select one or more',
            style: const TextStyle(fontSize: 11, color: WhatsAppTheme.darkTextSecondary),
          ),
        ],
      ),
    );
  }

  // Interactive Voice Note Widget
  Widget _buildVoiceNoteWidget(BuildContext context) {
    if (message.mediaUrl != null && message.mediaUrl!.isNotEmpty) {
      return VoiceNotePlayerWidget(
        audioUrl: message.mediaUrl!,
        durationSeconds: message.durationSeconds ?? 5,
        isMe: isMe,
      );
    }
    return Container(
      width: 240,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: WhatsAppTheme.primaryTeal,
            child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LinearProgressIndicator(
                  value: 0.35,
                  backgroundColor: Colors.white24,
                  color: isMe ? Colors.white : WhatsAppTheme.primaryTeal,
                  minHeight: 4,
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '0:${(message.durationSeconds ?? 8).toString().padLeft(2, '0')}',
                      style: const TextStyle(fontSize: 11, color: WhatsAppTheme.darkTextSecondary),
                    ),
                    const Icon(Icons.mic_rounded, size: 14, color: WhatsAppTheme.primaryTeal),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // View Once Media Widget (Photo / Video 1x)
  Widget _buildViewOnceWidget(BuildContext context) {
    final isOpened = message.isViewedBy(currentUserId);
    final isVideo = message.fileName != null &&
        ['mp4', 'mov', 'mkv', 'avi', '3gp'].any((ext) => message.fileName!.toLowerCase().endsWith(ext));
    final mediaLabel = isVideo ? 'Video' : 'Foto';

    return InkWell(
      onTap: () {
        if (!isOpened && message.mediaUrl != null) {
          context.read<ChatService>().markViewOnceOpened(
                chatId: chatId,
                messageId: message.id,
                userId: currentUserId,
              );
          _openMediaViewer(context, message.mediaUrl!, '$mediaLabel (Sekali Lihat)');
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$mediaLabel sekali lihat sudah pernah dibuka')),
          );
        }
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isOpened
                ? Colors.white12
                : WhatsAppTheme.primaryTeal.withValues(alpha: 0.4),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isOpened
                    ? Colors.white12
                    : WhatsAppTheme.primaryTeal.withValues(alpha: 0.18),
                border: Border.all(
                  color: isOpened ? Colors.grey : WhatsAppTheme.primaryTeal,
                  width: 1.6,
                ),
              ),
              child: Center(
                child: Text(
                  '1',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: isOpened ? Colors.grey : WhatsAppTheme.primaryTeal,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(
                      isVideo ? Icons.videocam_rounded : Icons.photo_camera_rounded,
                      size: 15,
                      color: isOpened ? WhatsAppTheme.darkTextSecondary : WhatsAppTheme.primaryTeal,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      isOpened ? '$mediaLabel dibuka' : '$mediaLabel (1x Lihat)',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13.5,
                        color: isOpened ? WhatsAppTheme.darkTextSecondary : Colors.white,
                      ),
                    ),
                  ],
                ),
                if (!isOpened) ...[
                  const SizedBox(height: 2),
                  const Text(
                    'Ketuk untuk melihat',
                    style: TextStyle(
                      fontSize: 11,
                      color: WhatsAppTheme.primaryTeal,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildReactionBadges(BuildContext context) {
    final counts = <String, int>{};
    for (final emoji in message.reactions.values) {
      counts[emoji] = (counts[emoji] ?? 0) + 1;
    }

    return counts.entries.map((entry) {
      final emoji = entry.key;
      final count = entry.value;
      final iReacted = message.reactions[currentUserId] == emoji;

      return GestureDetector(
        onTap: () => _toggleBadgeReaction(context, emoji),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: iReacted ? WhatsAppTheme.darkSurface : WhatsAppTheme.darkPill,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: iReacted ? WhatsAppTheme.primaryTeal : Colors.transparent,
              width: 1,
            ),
          ),
          child: Text(
            '$emoji $count',
            style: const TextStyle(fontSize: 11),
          ),
        ),
      );
    }).toList();
  }

  IconData _getFileIcon(String filename) {
    final ext = filename.contains('.') ? filename.split('.').last.toLowerCase() : '';
    switch (ext) {
      case 'pdf':
        return Icons.picture_as_pdf_rounded;
      case 'doc':
      case 'docx':
        return Icons.description_rounded;
      case 'xls':
      case 'xlsx':
      case 'csv':
        return Icons.table_chart_rounded;
      case 'ppt':
      case 'pptx':
        return Icons.slideshow_rounded;
      case 'txt':
        return Icons.text_snippet_rounded;
      case 'zip':
      case 'rar':
      case '7z':
      case 'tar':
      case 'gz':
        return Icons.folder_zip_rounded;
      case 'mp3':
      case 'm4a':
      case 'wav':
        return Icons.audio_file_rounded;
      case 'mp4':
      case 'mkv':
      case 'mov':
        return Icons.video_file_rounded;
      case 'apk':
        return Icons.android_rounded;
      default:
        return Icons.insert_drive_file_rounded;
    }
  }

  Color _getFileColor(String filename) {
    final ext = filename.contains('.') ? filename.split('.').last.toLowerCase() : '';
    switch (ext) {
      case 'pdf':
        return const Color(0xFFE53935); // WhatsApp Red for PDF
      case 'doc':
      case 'docx':
        return const Color(0xFF1E88E5); // Word Blue
      case 'xls':
      case 'xlsx':
      case 'csv':
        return const Color(0xFF43A047); // Excel Green
      case 'ppt':
      case 'pptx':
        return const Color(0xFFFFB300); // PowerPoint Orange
      case 'txt':
        return const Color(0xFF78909C); // Slate Text
      case 'zip':
      case 'rar':
      case '7z':
      case 'tar':
      case 'gz':
        return const Color(0xFFFB8C00); // Archive Orange
      case 'mp3':
      case 'm4a':
      case 'wav':
        return const Color(0xFF8E24AA); // Audio Purple
      case 'apk':
        return const Color(0xFF2E7D32); // Android Green
      default:
        return WhatsAppTheme.primaryTeal;
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  void _openFile(BuildContext context) async {
    final url = message.mediaUrl;
    if (url == null || url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cannot open this file URL')),
        );
      }
    }
  }

  Widget _buildDeliveryStatusIcon(Message msg) {
    final isRead = msg.readBy.any((uid) => uid != currentUserId) || msg.status == DeliveryStatus.read;

    if (isRead) {
      return const Icon(
        Icons.done_all_rounded,
        size: 15,
        color: WhatsAppTheme.blueCheck,
      );
    }

    switch (msg.status) {
      case DeliveryStatus.sending:
        return const Icon(
          Icons.access_time_rounded,
          size: 13,
          color: WhatsAppTheme.greyCheck,
        );
      case DeliveryStatus.sent:
        return const Icon(
          Icons.done_rounded,
          size: 15,
          color: WhatsAppTheme.greyCheck,
        );
      case DeliveryStatus.delivered:
        return const Icon(
          Icons.done_all_rounded,
          size: 15,
          color: WhatsAppTheme.greyCheck,
        );
      case DeliveryStatus.read:
        return const Icon(
          Icons.done_all_rounded,
          size: 15,
          color: WhatsAppTheme.blueCheck,
        );
    }
  }

  void _openMediaViewer(BuildContext context, String url, String title) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            title: Text(title, style: const TextStyle(fontSize: 16)),
            actions: [
              IconButton(
                icon: const Icon(Icons.open_in_new),
                onPressed: () async {
                  final uri = Uri.tryParse(url);
                  if (uri != null) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
              ),
            ],
          ),
          body: Center(
            child: InteractiveViewer(
              panEnabled: true,
              minScale: 0.5,
              maxScale: 4.0,
              child: UniversalImage(
                imageUrl: url,
                placeholder: const CircularProgressIndicator(color: WhatsAppTheme.primaryTeal),
                errorWidget: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.broken_image, size: 64, color: Colors.grey),
                    SizedBox(height: 12),
                    Text('Failed to load image', style: TextStyle(color: Colors.white)),
                  ],
                ),
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
