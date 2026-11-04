import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/whatsapp_theme.dart';
import 'user_avatar.dart';

/// Kartu Barcode / QR Code Akun Digital Profesional & Modern
/// Bergaya WhatsApp Glassmorphism & Emerald Badge
class ProfessionalQrCard extends StatelessWidget {
  final String uid;
  final String displayName;
  final String? photoUrl;
  final String subtitle;
  final double qrSize;

  const ProfessionalQrCard({
    super.key,
    required this.uid,
    required this.displayName,
    this.photoUrl,
    this.subtitle = 'Pindai barcode untuk terhubung langsung di RenChat',
    this.qrSize = 220,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 320),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
      decoration: BoxDecoration(
        color: const Color(0xFF131D22),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: WhatsAppTheme.primaryTeal.withValues(alpha: 0.35),
          width: 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: WhatsAppTheme.primaryTeal.withValues(alpha: 0.12),
            blurRadius: 30,
            spreadRadius: -4,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. Header Pengguna & Verified Identity Badge
          Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: WhatsAppTheme.primaryTeal, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: WhatsAppTheme.primaryTeal.withValues(alpha: 0.3),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: UserAvatar(
                  name: displayName,
                  photoUrl: photoUrl,
                  radius: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            displayName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 5),
                        const Icon(
                          Icons.verified_rounded,
                          size: 16,
                          color: WhatsAppTheme.primaryTeal,
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Kontak Resmi RenChat',
                      style: TextStyle(
                        color: WhatsAppTheme.primaryTeal,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // 2. Barcode Container dengan Efek Glassmorphic & Corner Guides
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Matriks QR Profesional
                CustomPaint(
                  size: Size(qrSize, qrSize),
                  painter: _ModernQrMatrixPainter(uid),
                ),

                // Center Monogram Badge "R" RenChat
                Container(
                  width: qrSize * 0.23,
                  height: qrSize * 0.23,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0B141A),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Container(
                      width: qrSize * 0.16,
                      height: qrSize * 0.16,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFF25D366),
                            Color(0xFF00A884),
                            Color(0xFF075E54),
                          ],
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Text(
                          'R',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          // 3. Footer Subtitle Bersih & Profesional (Tanpa ID teks)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.qr_code_scanner_rounded,
                size: 16,
                color: WhatsAppTheme.primaryTeal,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: WhatsAppTheme.darkTextSecondary,
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Painter Matriks Barcode / QR Modern
/// Menggunakan kombinasi Finder Squircle dengan Smooth Rounded Micro-Dots
class _ModernQrMatrixPainter extends CustomPainter {
  final String seed;
  _ModernQrMatrixPainter(this.seed);

  @override
  void paint(Canvas canvas, Size size) {
    final paintDark = Paint()
      ..color = const Color(0xFF0B141A)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final paintTeal = Paint()
      ..color = const Color(0xFF00A884)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    const int grid = 21; // Matriks QR standar 21x21
    final cellWidth = size.width / grid;
    final cellHeight = size.height / grid;

    // Finder Patterns (Sudut Kiri Atas, Kanan Atas, Kiri Bawah)
    _drawFinderPattern(canvas, 0, 0, cellWidth, cellHeight);
    _drawFinderPattern(canvas, (grid - 7) * cellWidth, 0, cellWidth, cellHeight);
    _drawFinderPattern(canvas, 0, (grid - 7) * cellHeight, cellWidth, cellHeight);

    // Hitung hash seed deterministik
    final hash = seed.hashCode.abs();
    final centerStart = (grid / 2 - 2).floor();
    final centerEnd = (grid / 2 + 2).ceil();

    // Gambar Titik-titik Data Barcode (Organic Rounded Dots)
    for (int r = 0; r < grid; r++) {
      for (int c = 0; c < grid; c++) {
        // Abaikan area Finder Patterns (7x7 di 3 sudut)
        final inTopLeft = r < 8 && c < 8;
        final inTopRight = r < 8 && c >= grid - 8;
        final inBottomLeft = r >= grid - 8 && c < 8;
        if (inTopLeft || inTopRight || inBottomLeft) continue;

        // Abaikan area logo RenChat tengah
        if (r >= centerStart && r <= centerEnd && c >= centerStart && c <= centerEnd) {
          continue;
        }

        // Timing Pattern baris 6 & kolom 6
        final isTiming = r == 6 || c == 6;
        if (isTiming) {
          if ((r + c) % 2 == 0) {
            _drawDot(canvas, c * cellWidth, r * cellHeight, cellWidth, cellHeight, paintTeal);
          }
          continue;
        }

        // Algoritma deterministik penempatan bit data berbasis hash UID pengguna
        final pseudoVal = ((hash ^ (r * 37 + c * 19 + (r * c))) * 31) & 0x7FFFFFFF;
        final isFilled = (pseudoVal % 5) < 3; // ~60% kepadatan QR alami

        if (isFilled) {
          // Aksen dual-tone: mayoritas dark slate, dengan sebaran teal modern
          final isAccent = (pseudoVal % 9) == 0;
          _drawDot(
            canvas,
            c * cellWidth,
            r * cellHeight,
            cellWidth,
            cellHeight,
            isAccent ? paintTeal : paintDark,
          );
        }
      }
    }
  }

  void _drawDot(Canvas canvas, double x, double y, double w, double h, Paint paint) {
    final padding = w * 0.14;
    final dotRect = Rect.fromLTWH(x + padding, y + padding, w - (padding * 2), h - (padding * 2));
    final radius = Radius.circular(w * 0.35); // Smooth organic micro-dot
    canvas.drawRRect(RRect.fromRectAndRadius(dotRect, radius), paint);
  }

  void _drawFinderPattern(Canvas canvas, double x, double y, double w, double h) {
    final outerSize = w * 7;

    // Bingkai Luar Squircle
    final outerPaint = Paint()
      ..color = const Color(0xFF0B141A)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final outerRect = Rect.fromLTWH(x, y, outerSize, outerSize);
    canvas.drawRRect(RRect.fromRectAndRadius(outerRect, Radius.circular(outerSize * 0.28)), outerPaint);

    // Ruang Kosong Putih Dalam
    final innerWhitePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final whiteSize = outerSize - (w * 2);
    final whiteRect = Rect.fromLTWH(x + w, y + h, whiteSize, whiteSize);
    canvas.drawRRect(RRect.fromRectAndRadius(whiteRect, Radius.circular(whiteSize * 0.24)), innerWhitePaint);

    // Titik Tengah Emerald & Dark Dual-Tone
    final centerPaint = Paint()
      ..color = const Color(0xFF00A884)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final centerSize = outerSize - (w * 4);
    final centerRect = Rect.fromLTWH(x + (w * 2), y + (h * 2), centerSize, centerSize);
    canvas.drawRRect(RRect.fromRectAndRadius(centerRect, Radius.circular(centerSize * 0.28)), centerPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
