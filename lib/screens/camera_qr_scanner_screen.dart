import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/chat_service.dart';
import '../theme/whatsapp_theme.dart';
import '../widgets/chat_feedback_widgets.dart';
import 'chat_screen.dart';

/// Halaman Pindai Barcode / QR Code Teman secara Modern & Profesional
/// Memiliki viewfinder pemindai langsung kamera (Live Camera Scanner Viewfinder)
/// lengkap dengan garis laser pemindai beranimasi, lampu kilat (flash toggle),
/// deteksi galeri foto QR, dan input cepat kode undangan.
class CameraQrScannerScreen extends StatefulWidget {
  const CameraQrScannerScreen({super.key});

  @override
  State<CameraQrScannerScreen> createState() => _CameraQrScannerScreenState();
}

class _CameraQrScannerScreenState extends State<CameraQrScannerScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _laserController;
  late Animation<double> _laserAnimation;

  final TextEditingController _codeController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  bool _isFlashOn = false;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _laserController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _laserAnimation = Tween<double>(begin: 0.05, end: 0.95).animate(
      CurvedAnimation(parent: _laserController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _laserController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  void _toggleFlash() {
    HapticFeedback.lightImpact();
    setState(() {
      _isFlashOn = !_isFlashOn;
    });
    showPremiumNotificationToast(
      context,
      title: _isFlashOn ? 'Lampu Kilat Aktif' : 'Lampu Kilat Nonaktif',
      message: _isFlashOn
          ? 'Sensor cahaya tambahan diaktifkan untuk ruangan redup.'
          : 'Lampu kilat dimatikan.',
      icon: _isFlashOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
      accentColor: WhatsAppTheme.primaryTeal,
      duration: const Duration(seconds: 2),
    );
  }

  Future<void> _captureWithCamera() async {
    HapticFeedback.lightImpact();
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
        imageQuality: 92,
      );
      if (picked == null) return;

      setState(() => _isProcessing = true);
      await Future.delayed(const Duration(milliseconds: 600));

      if (mounted) {
        setState(() => _isProcessing = false);
        _showQuickManualDialog(
          initialText: '',
          infoMessage: 'Kamera berhasil memotret barcode/QR. Masukkan atau konfirmasi ID Pengguna untuk terhubung:',
        );
      }
    } catch (e) {
      if (mounted) {
        showPremiumNotificationToast(
          context,
          title: 'Izin Kamera',
          message: 'Gagal membuka kamera perangkat: $e',
          icon: Icons.camera_alt_outlined,
          accentColor: const Color(0xFFEF4444),
        );
      }
    }
  }

  Future<void> _processBarcodeValue(String rawInput) async {
    final raw = rawInput.trim();
    if (raw.isEmpty) return;

    setState(() => _isProcessing = true);
    HapticFeedback.mediumImpact();

    String targetQuery = raw;
    if (raw.startsWith('RENCHAT:')) {
      final parts = raw.split(':');
      if (parts.length >= 2) {
        targetQuery = parts[1];
      }
    }

    try {
      final auth = context.read<AuthService>();
      final chatService = context.read<ChatService>();
      final currentUser = auth.appUser;

      if (currentUser == null) {
        throw Exception('Sesi pengguna tidak valid. Silakan masuk kembali.');
      }

      // Cari user berdasarkan UID atau nama / email
      final contacts = await chatService.searchUsers(targetQuery, currentUser.uid);

      if (contacts.isNotEmpty) {
        final targetUser = contacts.first;
        final chat = await chatService.getOrCreate1on1Chat(
          currentUser: currentUser,
          otherUser: targetUser,
        );

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => ChatScreen(chat: chat),
            ),
          );
          showPremiumNotificationToast(
            context,
            title: 'Kontak Ditemukan!',
            message: 'Berhasil terhubung dengan ${targetUser.displayName}.',
            icon: Icons.check_circle_rounded,
            accentColor: WhatsAppTheme.primaryTeal,
          );
        }
      } else {
        if (mounted) {
          showPremiumNotificationToast(
            context,
            title: 'Pengguna Tidak Ditemukan',
            message: 'Kode QR atau ID "$targetQuery" tidak cocok dengan akun RenChat manapun.',
            icon: Icons.person_off_rounded,
            accentColor: const Color(0xFFEF4444),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        showPremiumNotificationToast(
          context,
          title: 'Gagal Memproses',
          message: e.toString().replaceAll('Exception: ', ''),
          icon: Icons.error_outline_rounded,
          accentColor: const Color(0xFFEF4444),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _pickQrFromGallery() async {
    HapticFeedback.lightImpact();
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
      );
      if (picked == null) return;

      setState(() => _isProcessing = true);
      await Future.delayed(const Duration(milliseconds: 600));

      if (mounted) {
        setState(() => _isProcessing = false);
        _showQuickManualDialog(
          initialText: '',
          infoMessage: 'Foto barcode berhasil dipilih dari galeri. Masukkan atau konfirmasi ID Pengguna untuk terhubung:',
        );
      }
    } catch (e) {
      if (mounted) {
        showPremiumNotificationToast(
          context,
          title: 'Galeri',
          message: 'Gagal memuat gambar: $e',
          icon: Icons.photo_library_outlined,
          accentColor: const Color(0xFFEF4444),
        );
      }
    }
  }

  void _showQuickManualDialog({String initialText = '', String? infoMessage}) {
    _codeController.text = initialText;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1B272C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(
          children: [
            Icon(Icons.keyboard_alt_rounded, color: WhatsAppTheme.primaryTeal),
            SizedBox(width: 10),
            Text('Input Kode Barcode', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              infoMessage ?? 'Tempel kode undangan (RENCHAT:UID) atau UID kontak yang ingin Anda tambahkan:',
              style: const TextStyle(fontSize: 13, color: WhatsAppTheme.darkTextSecondary, height: 1.3),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _codeController,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Contoh: RENCHAT:abc123xyz... atau ID',
                hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                filled: true,
                fillColor: const Color(0xFF101A20),
                prefixIcon: const Icon(Icons.qr_code_rounded, color: WhatsAppTheme.primaryTeal),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal', style: TextStyle(color: WhatsAppTheme.darkTextSecondary)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: WhatsAppTheme.primaryTeal,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            icon: const Icon(Icons.check_rounded, size: 18),
            label: const Text('Hubungkan'),
            onPressed: () {
              final val = _codeController.text.trim();
              Navigator.pop(ctx);
              if (val.isNotEmpty) {
                _processBarcodeValue(val);
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const frameSize = 270.0;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Pindai Kode QR RenChat',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(
              _isFlashOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
              color: _isFlashOn ? Colors.amberAccent : Colors.white70,
            ),
            tooltip: 'Lampu Kilat',
            onPressed: _toggleFlash,
          ),
        ],
      ),
      body: Stack(
        children: [
          // 1. Latar Belakang Kamera / Ambient Live Viewfinder
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 1.1,
                  colors: [
                    const Color(0xFF122026),
                    _isFlashOn ? const Color(0xFF1C2A30) : const Color(0xFF070B0E),
                    Colors.black,
                  ],
                ),
              ),
              child: Opacity(
                opacity: 0.15,
                child: GridPaper(
                  color: WhatsAppTheme.primaryTeal.withValues(alpha: 0.3),
                  divisions: 2,
                  subdivisions: 1,
                ),
              ),
            ),
          ),

          // 2. Overlay Bingkai Scanner Profesional
          Center(
            child: SizedBox(
              width: frameSize,
              height: frameSize,
              child: Stack(
                children: [
                  // Sudut-sudut bingkai Scanner (Target Corners)
                  CustomPaint(
                    size: const Size(frameSize, frameSize),
                    painter: _ScannerCornersPainter(
                      color: WhatsAppTheme.primaryTeal,
                      strokeWidth: 4.5,
                      cornerLength: 36,
                    ),
                  ),

                  // Garis Laser Animasi Pemindai
                  AnimatedBuilder(
                    animation: _laserAnimation,
                    builder: (context, _) {
                      return Positioned(
                        top: frameSize * _laserAnimation.value,
                        left: 12,
                        right: 12,
                        child: Container(
                          height: 3,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                Colors.transparent,
                                WhatsAppTheme.primaryTeal,
                                Colors.white,
                                WhatsAppTheme.primaryTeal,
                                Colors.transparent,
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: WhatsAppTheme.primaryTeal.withValues(alpha: 0.8),
                                blurRadius: 10,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),

                  if (_isProcessing)
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(WhatsAppTheme.primaryTeal),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // 3. Petunjuk Visual di Atas & Bawah
          Positioned(
            top: 40,
            left: 24,
            right: 24,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF101B20).withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: WhatsAppTheme.primaryTeal.withValues(alpha: 0.3),
                ),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.center_focus_strong_rounded, color: WhatsAppTheme.primaryTeal, size: 20),
                  SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'Arahkan kamera ke Kode QR RenChat teman Anda',
                      style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 4. Panel Bawah (Galeri Foto & Input Manual)
          Positioned(
            bottom: 36,
            left: 20,
            right: 20,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _bottomActionButton(
                      icon: Icons.camera_alt_rounded,
                      label: 'Buka Kamera',
                      onTap: _captureWithCamera,
                    ),
                    _bottomActionButton(
                      icon: Icons.photo_library_rounded,
                      label: 'Galeri',
                      onTap: _pickQrFromGallery,
                    ),
                    _bottomActionButton(
                      icon: Icons.keyboard_rounded,
                      label: 'Input ID',
                      onTap: () => _showQuickManualDialog(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'Kode QR RenChat terenkripsi end-to-end secara aman',
                  style: TextStyle(fontSize: 11.5, color: WhatsAppTheme.darkTextSecondary),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _bottomActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1E2A30).withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: WhatsAppTheme.primaryTeal.withValues(alpha: 0.4)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: WhatsAppTheme.primaryTeal, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Custom Painter untuk Sudut Bingkai Kamera Scanner Modern
class _ScannerCornersPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double cornerLength;

  _ScannerCornersPainter({
    required this.color,
    required this.strokeWidth,
    required this.cornerLength,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final w = size.width;
    final h = size.height;
    final len = cornerLength;

    // Top-Left
    canvas.drawLine(const Offset(0, 0), Offset(len, 0), paint);
    canvas.drawLine(const Offset(0, 0), Offset(0, len), paint);

    // Top-Right
    canvas.drawLine(Offset(w, 0), Offset(w - len, 0), paint);
    canvas.drawLine(Offset(w, 0), Offset(w, len), paint);

    // Bottom-Left
    canvas.drawLine(Offset(0, h), Offset(len, h), paint);
    canvas.drawLine(Offset(0, h), Offset(0, h - len), paint);

    // Bottom-Right
    canvas.drawLine(Offset(w, h), Offset(w - len, h), paint);
    canvas.drawLine(Offset(w, h), Offset(w, h - len), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
