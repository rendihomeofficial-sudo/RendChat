import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/chat_service.dart';
import '../services/storage_service.dart';
import '../theme/whatsapp_theme.dart';

class TextStatusComposerScreen extends StatefulWidget {
  const TextStatusComposerScreen({super.key});

  @override
  State<TextStatusComposerScreen> createState() => _TextStatusComposerScreenState();
}

class _TextStatusComposerScreenState extends State<TextStatusComposerScreen> {
  final _controller = TextEditingController();
  final List<Color> _colors = const [
    Color(0xFF005C4B),
    Color(0xFF1E3A8A),
    Color(0xFF701A75),
    Color(0xFF831843),
    Color(0xFF9A3412),
    Color(0xFF14532D),
    Color(0xFF312E81),
  ];
  int _colorIndex = 0;

  // Status Music / Song feature (seperti fitur musik status WhatsApp)
  String? _selectedMusicTitle;
  String? _selectedMusicUrl;
  bool _isUploadingMusic = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _cycleColor() {
    setState(() {
      _colorIndex = (_colorIndex + 1) % _colors.length;
    });
  }

  Future<void> _pickMusic() async {
    try {
      final res = await FilePicker.pickFiles(type: FileType.audio);
      if (res.isEmpty) return;

      final file = res.first;
      final fileName = file.name;

      setState(() {
        _isUploadingMusic = true;
        _selectedMusicTitle = fileName;
      });

      final auth = context.read<AuthService>();
      final storageService = context.read<StorageService>();
      final uid = auth.currentUid;
      if (uid == null) return;

      final bytes = await file.xFile.readAsBytes();
      final url = await storageService.uploadStatusMedia(
        userId: uid,
        filePath: file.path,
        fileBytes: bytes,
        fileName: fileName,
      );

      setState(() {
        _isUploadingMusic = false;
        _selectedMusicUrl = url;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lagu terpilih: $fileName')),
        );
      }
    } catch (e) {
      setState(() => _isUploadingMusic = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memilih musik: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentColor = _colors[_colorIndex];

    return Scaffold(
      backgroundColor: currentColor,
      body: SafeArea(
        child: Stack(
          children: [
            // Top Controls
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Spacer(),
                  // WhatsApp Music button
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.black26,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    icon: _isUploadingMusic
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.music_note_rounded, size: 18, color: WhatsAppTheme.primaryTeal),
                    label: Text(
                      _selectedMusicTitle != null
                          ? (_selectedMusicTitle!.length > 15
                              ? '${_selectedMusicTitle!.substring(0, 12)}...'
                              : _selectedMusicTitle!)
                          : 'Tambah Musik',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    onPressed: _pickMusic,
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    icon: const Icon(Icons.color_lens_outlined, color: Colors.white, size: 26),
                    tooltip: 'Ganti Warna Latar',
                    onPressed: _cycleColor,
                  ),
                ],
              ),
            ),

            // Text Input
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32.0),
                child: TextField(
                  controller: _controller,
                  maxLines: null,
                  autofocus: true,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Ketik status...',
                    hintStyle: TextStyle(color: Colors.white60, fontSize: 28),
                    border: InputBorder.none,
                  ),
                ),
              ),
            ),

            // Bottom Selected Music Chip
            if (_selectedMusicTitle != null)
              Positioned(
                bottom: 90,
                left: 20,
                right: 20,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: WhatsAppTheme.primaryTeal.withValues(alpha: 0.6)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.music_note_rounded, color: WhatsAppTheme.primaryTeal, size: 18),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            _selectedMusicTitle!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedMusicTitle = null;
                              _selectedMusicUrl = null;
                            });
                          },
                          child: const Icon(Icons.close_rounded, color: Colors.white70, size: 16),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // Send FAB
            Positioned(
              bottom: 24,
              right: 20,
              child: FloatingActionButton(
                backgroundColor: WhatsAppTheme.primaryTeal,
                foregroundColor: Colors.white,
                child: const Icon(Icons.send_rounded),
                onPressed: () async {
                  final text = _controller.text.trim();
                  if (text.isNotEmpty || _selectedMusicUrl != null) {
                    final auth = context.read<AuthService>();
                    final chatService = context.read<ChatService>();
                    final user = auth.appUser;
                    if (user != null) {
                      await chatService.postStatus(
                        userId: user.uid,
                        userName: user.displayName,
                        userAvatar: user.photoURL,
                        text: text,
                        musicUrl: _selectedMusicUrl,
                        musicTitle: _selectedMusicTitle,
                        backgroundColor: currentColor.toARGB32(),
                      );
                    }
                    if (context.mounted) {
                      Navigator.pop(context, text);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Status berhasil dipublikasikan!')),
                      );
                    }
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
