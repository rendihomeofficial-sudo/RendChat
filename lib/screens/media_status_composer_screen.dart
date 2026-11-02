import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/chat_service.dart';
import '../services/storage_service.dart';
import '../theme/whatsapp_theme.dart';
import '../widgets/chat_feedback_widgets.dart';

/// Layar Editor / Composer Media Status (Foto & Video)
/// Mendukung penambahan Caption interaktif, pemilihan Emotion/Emoji cepat,
/// pratinjau media real-time, dan tombol kirim bergaya WhatsApp.
class MediaStatusComposerScreen extends StatefulWidget {
  final XFile file;
  final bool isVideo;

  const MediaStatusComposerScreen({
    super.key,
    required this.file,
    required this.isVideo,
  });

  @override
  State<MediaStatusComposerScreen> createState() => _MediaStatusComposerScreenState();
}

class _MediaStatusComposerScreenState extends State<MediaStatusComposerScreen> {
  final TextEditingController _captionController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  bool _isUploading = false;
  String? _selectedEmotion;

  // Daftar emoji / emotion populer WhatsApp untuk status
  static const List<String> _popularEmotions = [
    '❤️', '😍', '🔥', '😂', '✨', '😎', '🎉', '🥰',
    '🙌', '👏', '☕', '🌸', '🍕', '🏖️', '💯', '🌙',
  ];

  @override
  void dispose() {
    _captionController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _addEmotion(String emoji) {
    HapticFeedback.lightImpact();
    final text = _captionController.text;
    final selection = _captionController.selection;

    if (selection.isValid && selection.start >= 0) {
      final newText = text.replaceRange(selection.start, selection.end, emoji);
      _captionController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: selection.start + emoji.length),
      );
    } else {
      _captionController.text = '$text$emoji';
      _captionController.selection = TextSelection.collapsed(offset: _captionController.text.length);
    }

    setState(() {
      _selectedEmotion = emoji;
    });
  }

  Future<void> _publishStatus() async {
    final auth = context.read<AuthService>();
    final chatService = context.read<ChatService>();
    final storageService = context.read<StorageService>();
    final user = auth.appUser;

    if (user == null) return;

    final rawCaption = _captionController.text.trim();
    // Jika ada emotion terpilih tapi caption kosong, pakai emotion sebagai caption
    final finalCaption = rawCaption.isNotEmpty
        ? rawCaption
        : (_selectedEmotion != null ? _selectedEmotion! : (widget.isVideo ? '📹 Video Status' : ''));

    setState(() => _isUploading = true);
    HapticFeedback.mediumImpact();

    try {
      final bytes = await widget.file.readAsBytes();
      final url = await storageService.uploadStatusMedia(
        userId: user.uid,
        filePath: widget.file.path,
        fileBytes: bytes,
        fileName: widget.file.name,
      );

      if (url != null) {
        await chatService.postStatus(
          userId: user.uid,
          userName: user.displayName,
          userAvatar: user.photoURL,
          text: finalCaption,
          mediaUrl: url,
          backgroundColor: 0xFF000000,
        );

        if (mounted) {
          Navigator.pop(context, true);
          showPremiumNotificationToast(
            context,
            title: 'Status Terkirim!',
            message: widget.isVideo
                ? 'Status video HD Anda berhasil dipublikasikan.'
                : 'Status foto HD Anda berhasil dipublikasikan.',
            icon: Icons.check_circle_rounded,
            accentColor: WhatsAppTheme.primaryTeal,
          );
        }
      } else {
        if (mounted) {
          showPremiumNotificationToast(
            context,
            title: 'Gagal Mengunggah',
            message: widget.isVideo
                ? 'Ukuran video melebihi batas yang didukung server (maks 1 MB). Silakan gunakan video yang lebih pendek.'
                : 'Ukuran foto melebihi batas server. Silakan coba pilih kembali fotonya.',
            icon: Icons.error_outline_rounded,
            accentColor: const Color(0xFFEF4444),
          );
        }
      }
    } catch (e) {
      debugPrint('Error publishing status: $e');
      if (mounted) {
        showPremiumNotificationToast(
          context,
          title: 'Terjadi Kesalahan',
          message: 'Gagal membuat status: $e',
          icon: Icons.error_outline_rounded,
          accentColor: const Color(0xFFEF4444),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // 1. Media Preview Area (Foto / Video Placeholder)
            Positioned.fill(
              child: widget.isVideo
                  ? Container(
                      color: const Color(0xFF0F171A),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: WhatsAppTheme.primaryTeal.withValues(alpha: 0.2),
                                shape: BoxShape.circle,
                                border: Border.all(color: WhatsAppTheme.primaryTeal, width: 2),
                              ),
                              child: const Icon(Icons.videocam_rounded, size: 64, color: WhatsAppTheme.primaryTeal),
                            ),
                            const SizedBox(height: 18),
                            const Text(
                              'Pratinjau Video Status',
                              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              widget.file.name,
                              style: const TextStyle(color: WhatsAppTheme.darkTextSecondary, fontSize: 13),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    )
                  : Image.file(
                      File(widget.file.path),
                      fit: BoxFit.contain,
                      width: double.infinity,
                      height: double.infinity,
                      errorBuilder: (_, __, ___) => const Center(
                        child: Icon(Icons.broken_image_rounded, size: 70, color: Colors.white54),
                      ),
                    ),
            ),

            // 2. Top Bar (Tombol Kembali & Indikator Tipe)
            Positioned(
              top: 10,
              left: 12,
              right: 12,
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          widget.isVideo ? Icons.videocam_rounded : Icons.photo_camera_rounded,
                          color: WhatsAppTheme.primaryTeal,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          widget.isVideo ? 'Video HD' : 'Foto HD',
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // 3. Bottom Composer & Emotion Bar
            Positioned(
              left: 0,
              right: 0,
              bottom: bottomInset,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.95),
                      Colors.black.withValues(alpha: 0.7),
                      Colors.transparent,
                    ],
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Emotion / Emoji Picker Row (Cepat & Aksesibel)
                    SizedBox(
                      height: 42,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _popularEmotions.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 6),
                        itemBuilder: (context, idx) {
                          final emoji = _popularEmotions[idx];
                          final isSelected = _selectedEmotion == emoji;

                          return InkWell(
                            onTap: () => _addEmotion(emoji),
                            borderRadius: BorderRadius.circular(20),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? WhatsAppTheme.primaryTeal.withValues(alpha: 0.35)
                                    : const Color(0xFF1E2A30).withValues(alpha: 0.8),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isSelected ? WhatsAppTheme.primaryTeal : Colors.white12,
                                  width: isSelected ? 1.5 : 0.8,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  emoji,
                                  style: const TextStyle(fontSize: 18),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Caption Input & Send Button
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF1F2C34),
                              borderRadius: BorderRadius.circular(26),
                              border: Border.all(color: Colors.white24, width: 0.8),
                            ),
                            child: Row(
                              children: [
                                const SizedBox(width: 14),
                                const Icon(Icons.add_reaction_outlined, color: WhatsAppTheme.primaryTeal, size: 22),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: TextField(
                                    controller: _captionController,
                                    focusNode: _focusNode,
                                    style: const TextStyle(color: Colors.white, fontSize: 15),
                                    maxLines: 4,
                                    minLines: 1,
                                    decoration: const InputDecoration(
                                      hintText: 'Tambah keterangan / caption...',
                                      hintStyle: TextStyle(color: Colors.white54, fontSize: 14),
                                      border: InputBorder.none,
                                      isDense: true,
                                      contentPadding: EdgeInsets.symmetric(vertical: 12),
                                    ),
                                  ),
                                ),
                                if (_captionController.text.isNotEmpty)
                                  IconButton(
                                    icon: const Icon(Icons.clear_rounded, size: 18, color: Colors.white54),
                                    onPressed: () {
                                      _captionController.clear();
                                      setState(() {});
                                    },
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        GestureDetector(
                          onTap: _isUploading ? null : _publishStatus,
                          child: Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: WhatsAppTheme.primaryTeal,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: WhatsAppTheme.primaryTeal.withValues(alpha: 0.4),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Center(
                              child: _isUploading
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2.4,
                                      ),
                                    )
                                  : const Icon(Icons.send_rounded, color: Colors.white, size: 24),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
